// smell-bench: runs every labeled message through the same on-device first pass the iPhone app
// uses (prompt, parser and escalation rules from SmellTestCore) and reports misses, false alarms,
// "not sure", latency and would-be cloud calls separately, for each warning-sign threshold.
//
// Usage: swift run -c release smell-bench [--data data/messages.jsonl] [--out results]
//                                         [--repeat 1] [--limit N] [--ids a,b] [--show-raw]
//
// Nothing here touches the network. "Cloud calls" are the second opinions the app would OFFER;
// in the app each one still needs the Privacy Shield and the user's OK before anything is sent.

import Foundation
import FoundationModels
import SmellTestCore

struct Item: Decodable {
    let id: String
    let label: String      // "scam" or "legit"
    let kind: String
    let difficulty: String
    /// "dev" (used while tuning the prompt) or "holdout" (never looked at while tuning).
    let split: String
    let text: String
}

struct Row: Codable {
    let id: String
    let label: String
    let kind: String
    let difficulty: String
    let split: String
    let run: Int
    /// "scam", "likely_scam", "not_sure", "no_red_flags", "could_not_answer" or "too_long".
    let outcome: String
    /// Why the phone couldn't answer (error type or parser failure). Never message text.
    let failure: String?
    let scamType: String?
    let milliseconds: Int?
    /// How many different kinds of fixed-pattern warning sign the message has.
    let warningSigns: Int
}

// MARK: - Arguments

var dataPath = "data/messages.jsonl"
var outDir = "results"
var repeats = 1
var limit = Int.max
var onlyIDs: Set<String>? = nil
var showRaw = false
var args = CommandLine.arguments.dropFirst().makeIterator()
while let a = args.next() {
    switch a {
    case "--data": dataPath = args.next() ?? dataPath
    case "--out": outDir = args.next() ?? outDir
    case "--repeat": repeats = max(1, Int(args.next() ?? "") ?? 1)
    case "--limit": limit = max(1, Int(args.next() ?? "") ?? Int.max)
    case "--ids": onlyIDs = Set((args.next() ?? "").split(separator: ",").map(String.init))
    case "--show-raw": showRaw = true
    default:
        FileHandle.standardError.write(Data("unknown argument: \(a)\n".utf8))
        exit(2)
    }
}

// MARK: - Load

let items: [Item] = try String(contentsOfFile: dataPath, encoding: .utf8)
    .split(whereSeparator: \.isNewline)
    .map { try JSONDecoder().decode(Item.self, from: Data($0.utf8)) }
    .filter { onlyIDs?.contains($0.id) ?? true }
    .prefix(limit)
    .map { $0 }

// Same model and guardrails as the app (CheckEngine.onDeviceModel).
let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
guard case .available = model.availability else {
    print("The on-device model isn't available on this Mac: \(model.availability)")
    print("Turn on Apple Intelligence in System Settings and try again. No results were written.")
    exit(1)
}

func parserFailureName(_ f: VerdictParser.Failure) -> String {
    switch f {
    case .noJSON: "noJSON"
    case .malformedJSON: "malformedJSON"
    case .unknownVerdict: "unknownVerdict"
    case .unknownScamType: "unknownScamType"
    case .missingSummary: "missingSummary"
    case .wrongNumberOfSteps(let n): "wrongNumberOfSteps(\(n))"
    case .warningWithoutEvidence: "warningWithoutEvidence"
    case .inventedContactDetails: "inventedContactDetails"
    }
}

@MainActor func check(_ item: Item, run: Int) async -> Row {
    let signs = RedFlagScanner.scan(item.text).count
    func row(_ outcome: String, failure: String? = nil, type: String? = nil, ms: Int? = nil) -> Row {
        Row(id: item.id, label: item.label, kind: item.kind, difficulty: item.difficulty, split: item.split, run: run,
            outcome: outcome, failure: failure, scamType: type, milliseconds: ms, warningSigns: signs)
    }
    if EscalationPolicy.preCheck(message: item.text, onDeviceAvailable: true) == .tooLongForOnDevice {
        return row("too_long")
    }
    // A new session per message, as in the app, so nothing carries over.
    let session = LanguageModelSession(model: model)
    let start = Date()
    let raw: String
    do {
        raw = try await session.respond(to: VerdictPrompt.prompt(for: item.text)).content
    } catch {
        return row("could_not_answer", failure: "modelError:\(type(of: error)).\(Mirror(reflecting: error).children.first?.label ?? "?")")
    }
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    if showRaw { print("--- \(item.id) raw answer:\n\(raw)") }
    do {
        let result = try VerdictParser.parse(raw, message: item.text)
        return row(result.verdict.rawValue, type: result.scamType.rawValue, ms: ms)
    } catch {
        return row("could_not_answer", failure: parserFailureName(error), ms: ms)
    }
}

// MARK: - Run

var rows: [Row] = []
let total = items.count * repeats
for run in 1...repeats {
    for item in items {
        let r = await check(item, run: run)
        rows.append(r)
        let ms = r.milliseconds.map { "\($0) ms" } ?? "-"
        print("[\(rows.count)/\(total)] \(item.id) \(item.label) -> \(r.outcome) \(r.failure ?? "") \(ms)")
    }
}

// MARK: - Score

struct Score {
    var caught = 0, notSure = 0, missedButOffered = 0, missed = 0, couldNotAnswer = 0, tooLong = 0
    var clean = 0, falseAlarm = 0, offeredByPatterns = 0
    var cloudCalls: Int { notSure + missedButOffered + offeredByPatterns + couldNotAnswer + tooLong }
}

func score(_ rows: [Row], label: String, threshold: Int) -> Score {
    var s = Score()
    for r in rows where r.label == label {
        switch r.outcome {
        case "scam", "likely_scam":
            if label == "scam" { s.caught += 1 } else { s.falseAlarm += 1 }
        case "not_sure": s.notSure += 1
        case "no_red_flags":
            // Mirrors EscalationPolicy.afterOnDevice: patterns disagree when the message has at
            // least `threshold` kinds of warning sign.
            if r.warningSigns >= threshold {
                if label == "scam" { s.missedButOffered += 1 } else { s.offeredByPatterns += 1 }
            } else {
                if label == "scam" { s.missed += 1 } else { s.clean += 1 }
            }
        case "too_long": s.tooLong += 1
        default: s.couldNotAnswer += 1
        }
    }
    return s
}

func pct(_ n: Int, _ d: Int) -> String {
    d == 0 ? "-" : String(format: "%d (%.0f%%)", n, Double(n) / Double(d) * 100)
}

@MainActor func percentile(_ rows: [Row], _ p: Double) -> Int {
    let ms = rows.compactMap { $0.outcome == "could_not_answer" ? nil : $0.milliseconds }.sorted()
    return ms.isEmpty ? 0 : ms[min(ms.count - 1, Int(Double(ms.count) * p))]
}

let current = Settings.defaults.minWarningSigns
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withFullDate]
let date = formatter.string(from: Date())
let os = ProcessInfo.processInfo.operatingSystemVersionString
let stem = "\(date)-prompt-\(VerdictPrompt.version)"

var md = """
# Smell Test benchmark: \(date)

- Messages: \(items.count) made-up messages (\(items.filter { $0.label == "scam" }.count) scam, \(items.filter { $0.label == "legit" }.count) not scam), \(repeats) run(s) each
- Model: Apple on-device model on this Mac (\(os)), guardrails `.permissiveContentTransformations`
- Prompt: `\(VerdictPrompt.version)`, same prompt, parser and escalation rules as the iPhone app
- "Cloud calls" are second opinions the app would **offer**. Each still needs the Privacy Shield and the user's OK.
- This run measures the on-device first pass only. It does not measure the cloud second opinion.
- The prompt was tuned using only the **dev** messages (odd-numbered). The **holdout** messages (even-numbered)
  were never used while tuning, so the holdout column is the fairest estimate. (The first, untuned baseline
  report covered every message, so the holdout isn't perfectly untouched, but no holdout message's answer was
  read while writing the prompt.)

## Summary (threshold \(current))

"""

let splits: [(String, [Row])] = [("All", rows), ("Dev", rows.filter { $0.split == "dev" }), ("Holdout", rows.filter { $0.split == "holdout" })]

@MainActor func summaryRow(_ title: String, _ value: ([Row]) -> String) -> String {
    "| \(title) | " + splits.map { value($0.1) }.joined(separator: " | ") + " |\n"
}

md += "\n| | " + splits.map { "\($0.0) (\($0.1.count))" }.joined(separator: " | ") + " |\n|---|---|---|---|\n"
md += summaryRow("**Scams missed**") { r in let n = r.filter { $0.label == "scam" }.count; return pct(score(r, label: "scam", threshold: current).missed, n) }
md += summaryRow("Scams caught") { r in let n = r.filter { $0.label == "scam" }.count; return pct(score(r, label: "scam", threshold: current).caught, n) }
md += summaryRow("**False alarms**") { r in let n = r.filter { $0.label == "legit" }.count; return pct(score(r, label: "legit", threshold: current).falseAlarm, n) }
md += summaryRow("\"Not sure\" (all messages)") { r in pct(r.filter { $0.outcome == "not_sure" }.count, r.count) }
md += summaryRow("Cloud calls offered") { r in pct(score(r, label: "scam", threshold: current).cloudCalls + score(r, label: "legit", threshold: current).cloudCalls, r.count) }
md += summaryRow("On-device time, median") { r in "\(percentile(r, 0.5)) ms" }
md += summaryRow("On-device time, 90th percentile") { r in "\(percentile(r, 0.9)) ms" }

@MainActor func table(_ rows: [Row], threshold t: Int) -> String {
    let scamN = rows.filter { $0.label == "scam" }.count
    let legitN = rows.filter { $0.label == "legit" }.count
    let s = score(rows, label: "scam", threshold: t)
    let l = score(rows, label: "legit", threshold: t)
    return """
    | Scam messages (\(scamN)) | Count |
    |---|---|
    | Caught (scam or likely scam) | \(pct(s.caught, scamN)) |
    | "Not sure", second opinion offered | \(pct(s.notSure, scamN)) |
    | "No red flags" but warning signs, second opinion offered | \(pct(s.missedButOffered, scamN)) |
    | **Missed** ("No red flags", nothing offered) | **\(pct(s.missed, scamN))** |
    | Phone couldn't answer, second opinion offered | \(pct(s.couldNotAnswer + s.tooLong, scamN)) |

    | Not-scam messages (\(legitN)) | Count |
    |---|---|
    | "No red flags found" | \(pct(l.clean, legitN)) |
    | **False alarm** (scam or likely scam) | **\(pct(l.falseAlarm, legitN))** |
    | "Not sure", second opinion offered | \(pct(l.notSure, legitN)) |
    | "No red flags" but warning signs, second opinion offered | \(pct(l.offeredByPatterns, legitN)) |
    | Phone couldn't answer, second opinion offered | \(pct(l.couldNotAnswer + l.tooLong, legitN)) |

    """
}

md += "\n## Holdout detail\n\n" + table(splits[2].1, threshold: current)
md += "\n## All messages detail\n\n" + table(rows, threshold: current)

let scamN = rows.filter { $0.label == "scam" }.count
let legitN = rows.filter { $0.label == "legit" }.count
md += "\n## Threshold sweep (all messages)\n\nHow the warning-sign threshold (`min_warning_signs`) trades misses for cloud calls. The model's answers are the same in every row; only the escalation rule changes.\n\n"
md += "| Threshold | Scams missed | Scams offered a second opinion | Not-scam offered a second opinion | Cloud calls offered |\n|---|---|---|---|---|\n"
for t in 1...RedFlagScanner.Signal.allCases.count {
    let s = score(rows, label: "scam", threshold: t)
    let l = score(rows, label: "legit", threshold: t)
    md += "| \(t)\(t == current ? " (current)" : "") | \(pct(s.missed, scamN)) | \(pct(s.cloudCalls, scamN)) | \(pct(l.cloudCalls, legitN)) | \(pct(s.cloudCalls + l.cloudCalls, scamN + legitN)) |\n"
}

// What-if: the fixed patterns disagreeing in the other direction. Not what the app does today.
let scamWarn = rows.filter { $0.label == "scam" && ($0.outcome == "scam" || $0.outcome == "likely_scam") }
let legitWarn = rows.filter { $0.label == "legit" && ($0.outcome == "scam" || $0.outcome == "likely_scam") }
md += """

## What-if: "Scam" with no fixed warning signs shown as "Not sure"

Not what the app does today. If a "Scam" or "Likely scam" answer on a message with **zero** fixed-pattern
warning signs were shown as "Not sure" (with a second opinion offered) instead:

| | Today | What-if |
|---|---|---|
| False alarms | \(pct(legitWarn.count, legitN)) | \(pct(legitWarn.filter { $0.warningSigns > 0 }.count, legitN)) |
| Scams shown as a warning | \(pct(scamWarn.count, scamN)) | \(pct(scamWarn.filter { $0.warningSigns > 0 }.count, scamN)) |
| Scams moved to "Not sure" (still offered a second opinion) | 0 | \(pct(scamWarn.filter { $0.warningSigns == 0 }.count, scamN)) |

"""

@MainActor func list(_ title: String, _ pick: (Row) -> Bool) -> String {
    let hits = rows.filter(pick)
    guard !hits.isEmpty else { return "\n### \(title)\n\nNone.\n" }
    var counts: [String: Int] = [:]
    var order: [Row] = []
    for h in hits {
        if counts[h.id] == nil { order.append(h) }
        counts[h.id, default: 0] += 1
    }
    return "\n### \(title)\n\n" + order.map { r in
        "- `\(r.id)` (\(r.kind), \(r.difficulty), \(r.split))" + (repeats > 1 ? ": \(counts[r.id]!) of \(repeats) runs" : "")
    }.joined(separator: "\n") + "\n"
}

md += "\n## Details\n"
md += list("Scams missed at the current threshold") { $0.label == "scam" && $0.outcome == "no_red_flags" && $0.warningSigns < current }
md += list("False alarms") { $0.label == "legit" && ($0.outcome == "scam" || $0.outcome == "likely_scam") }
md += list("Couldn't answer") { $0.outcome == "could_not_answer" || $0.outcome == "too_long" }
let failures = Dictionary(grouping: rows.compactMap(\.failure), by: { $0 }).mapValues(\.count)
if !failures.isEmpty {
    md += "\nReasons the phone couldn't answer: " + failures.sorted { $0.key < $1.key }.map { "`\($0.key)` × \($0.value)" }.joined(separator: ", ") + "\n"
}
md += "\nMessages: [data/messages.jsonl](../data/messages.jsonl). Per-message results: [\(stem).jsonl](\(stem).jsonl).\n"

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let jsonl = try rows.map { String(decoding: try encoder.encode($0), as: UTF8.self) }.joined(separator: "\n") + "\n"
try jsonl.write(toFile: "\(outDir)/\(stem).jsonl", atomically: true, encoding: .utf8)
try md.write(toFile: "\(outDir)/\(stem).md", atomically: true, encoding: .utf8)
print("\nWrote \(outDir)/\(stem).md and \(stem).jsonl")
