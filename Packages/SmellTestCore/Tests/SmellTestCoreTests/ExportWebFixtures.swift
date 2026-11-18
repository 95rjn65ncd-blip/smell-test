import Foundation
import Testing
@testable import SmellTestCore

/// Writes what the Chrome version (web/) needs from the Swift rules, so the two can't drift:
/// - web/src/generated/prompt.json: the exact prompt text and fixed wording lists, imported by web/src/core.js
/// - web/test/fixtures/parity.json: Swift's own answers on the benchmark messages and parser cases,
///   which web/test/parity.test.js compares against.
/// Runs only when asked: `EXPORT_WEB_FIXTURES=1 swift test --filter ExportWebFixtures`.
struct ExportWebFixtures {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test(.enabled(if: ProcessInfo.processInfo.environment["EXPORT_WEB_FIXTURES"] == "1"))
    func export() throws {
        let marker = "\u{1}MESSAGE\u{1}"
        let namePrompt = PrivacyShield.namePrompt(for: marker).components(separatedBy: marker)
        let prompt: [String: Any] = [
            "version": VerdictPrompt.version,
            "instructions": VerdictPrompt.instructions(),
            "scamTypes": ScamType.allCases.map(\.rawValue),
            "exampleSummaries": VerdictPrompt.exampleSummaries.map { ["summary": $0.summary, "fitsIfMessageHas": $0.fitsIfMessageHas] },
            "relationshipWords": PrivacyShield.relationshipWords.sorted(),
            "namePromptPrefix": namePrompt[0],
            "namePromptSuffix": namePrompt[1],
            "recovery": RecoverySituation.allCases.map { ["id": $0.rawValue, "label": $0.label, "steps": $0.steps] },
        ]
        try write(prompt, to: "web/src/generated/prompt.json")

        // Messages: every benchmark message plus edge cases for the redactor and links.
        let data = try String(contentsOf: Self.repo.appendingPathComponent("benchmark/data/messages.jsonl"), encoding: .utf8)
        var messages = data.split(separator: "\n").compactMap { line -> String? in
            (try? JSONSerialization.jsonObject(with: Data(line.utf8))) .flatMap { ($0 as? [String: Any])?["text"] as? String }
        }
        messages += [
            "Hi Mum, it's Jess. New number x", "Dear Mr. Lopez, your card ending in 4821 was charged.",
            "Call (555) 201-7788 or +44 20 7946 0958, email ana.r@example.com, SSN 123-45-6789.",
            "Visit www.Example-Bank.com/login?user=ana&t=99 or https://a.b.co/track/1Z999AA10123456784#x.",
            "Card 4111 1111 1111 1111, acct ...7781, 12 Oak Street, Apt 4B, code A7X9Q2, PIN 4821, $1,299.00",
            "Your code is 662913. Don't share it.", "", "   ",
        ]
        let names: [String] = ["Jess", "Aunt Rosa", "Mr. Lopez", "Ana Reyes"]
        let messageCases: [[String: Any]] = messages.map { m in
            let r = Redactor.redact(m)
            let p = PrivacyShield.preview(original: m, names: names)
            return [
                "message": m,
                "redacted": r.text,
                "counts": Dictionary(uniqueKeysWithValues: r.counts.map { ($0.key.rawValue, $0.value) }),
                "signals": RedFlagScanner.scan(m).map(\.rawValue).sorted(),
                "fits": VerdictPrompt.fitsOnDevice(message: m),
                "preview": p.text,
                "previewCounts": Dictionary(uniqueKeysWithValues: p.counts.map { ($0.key.rawValue, $0.value) }),
            ]
        }

        let parserMessage = "ParcelPoint: your package is on hold. Pay the $1.99 redelivery fee at parcelpoint-redelivery.top within 12 hours."
        let bank = "BrightBank Alert: unusual sign-in detected on your account. Verify your identity now at brightbank-secure-login.net or your account will be locked today."
        let outputs: [(String, String)] = [
            (#"{"verdict":"scam","scam_type":"package_delivery","summary":"Asks for a fake fee.","reasons":[{"quote":"Pay the $1.99 redelivery fee","why":"Asks for a fee (red flag 1)."}],"next_steps":["Don't pay.","Call 555-201-7788 now.","Block the sender."]}"#, parserMessage),
            ("```json\n{\"verdict\":\"Likely_Scam\",\"scam_type\":\"package_delivery\",\"summary\":\"A fee.\",\"reasons\":[\"bare string\",{\"quote\":\"on hold\",\"why\":\"Threatens\"}],\"next_steps\":[\"a\",\"b\",\"c\"]}\n```", parserMessage),
            (#"{"verdict":"scam","scam_type":"package_delivery","summary":"A fee.","reasons":[{"quote":"words not in the message","why":"x"}],"next_steps":["a","b","c"]}"#, parserMessage),
            (#"{"verdict":"safe","summary":"x"}"#, parserMessage),
            (#"{"verdict":"no_red_flags","scam_type":"other","summary":"Looks fine.","reasons":[],"next_steps":["a","b"]}"#, parserMessage),
            (#"{"verdict":"not_sure","scam_type":"family_emergency","summary":"Could be real.","reasons":[{"quote":"on hold","why":"odd"}],"next_steps":["Call her back.","x","y"]}"#, parserMessage),
            (#"{"verdict":"scam","scam_type":"bank_or_government_impersonation","summary":"This message tries to get a security code from you.","reasons":[{"quote":"Verify your identity now at brightbank-secure-login.net","why":"Asks you to share a code."},{"quote":"Your account will be locked today","why":"Threatens a problem to rush you."}],"next_steps":["Don't send any codes to anyone.","Contact BrightBank using its official app.","Block the sender."]}"#, bank),
            (#"{"verdict":"scam","scam_type":"other","summary":"Visit help-desk-cloudkey.net for help.","reasons":[{"quote":"on hold","why":"x"}],"next_steps":["a","b","c"]}"#, parserMessage),
            ("no json here", parserMessage),
            (#"{"verdict": "scam", "#, parserMessage),
        ]
        let parserCases: [[String: Any]] = outputs.map { output, message in
            var c: [String: Any] = ["output": output, "message": message]
            do {
                let r = try VerdictParser.parse(output, message: message)
                c["result"] = ["verdict": r.verdict.rawValue, "scamType": r.scamType.rawValue, "summary": r.summary,
                               "reasons": r.reasons.map { ["quote": $0.quote, "why": $0.why] }, "nextSteps": r.nextSteps]
                let first = EscalationPolicy.firstPass(r, message: message)
                c["firstPassVerdict"] = first.result.verdict.rawValue
                c["escalation"] = first.escalation?.rawValue ?? NSNull()
            } catch {
                c["error"] = "\(error)".components(separatedBy: "(").first ?? "\(error)"
            }
            return c
        }
        try write(["messages": messageCases, "parser": parserCases, "names": names], to: "web/test/fixtures/parity.json")
    }

    private func write(_ object: Any, to path: String) throws {
        let url = Self.repo.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url)
    }
}
