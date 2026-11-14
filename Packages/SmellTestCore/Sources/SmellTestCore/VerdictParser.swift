import Foundation

/// Turns raw model output into a `CheckResult`, or refuses. It never fills in a missing
/// verdict: if the output can't be trusted, the caller shows "Couldn't check, try again".
public enum VerdictParser {
    public enum Failure: Error, Equatable, Sendable {
        case noJSON
        case malformedJSON
        case unknownVerdict(String)
        case unknownScamType(String)
        case missingSummary
        case wrongNumberOfSteps(Int)
        case warningWithoutEvidence
    }

    private struct Raw: Decodable {
        let verdict: String
        let scam_type: String?
        let summary: String?
        let reasons: [RawReason]?
        let next_steps: [String]?
    }

    private struct RawReason: Decodable {
        let quote: String?
        let why: String?
    }

    static let maxReasons = 3
    static let maxFieldLength = 400

    /// - Parameters:
    ///   - output: the model's raw text. May include a ```json fence or extra prose around the object.
    ///   - message: the exact text that was checked. Reasons must quote it.
    public static func parse(_ output: String, message: String) throws(Failure) -> CheckResult {
        guard let json = extractJSONObject(from: output) else { throw .noJSON }
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: Data(json.utf8))
        } catch {
            throw .malformedJSON
        }

        guard let verdict = Verdict(rawValue: raw.verdict.trimmingCharacters(in: .whitespaces).lowercased()) else {
            throw .unknownVerdict(raw.verdict)
        }

        let scamTypeRaw = (raw.scam_type ?? "none").trimmingCharacters(in: .whitespaces).lowercased()
        guard let scamType = ScamType(rawValue: scamTypeRaw) else { throw .unknownScamType(scamTypeRaw) }

        let summary = clean(raw.summary ?? "")
        guard !summary.isEmpty else { throw .missingSummary }

        // Keep only reasons whose quote really appears in the message. A reason that "quotes"
        // words the message doesn't contain is dropped, never shown.
        let reasons: [Reason] = (raw.reasons ?? []).compactMap { r in
            let quote = clean(r.quote ?? "")
            let why = clean(r.why ?? "")
            guard !quote.isEmpty, !why.isEmpty, containsQuote(quote, in: message) else { return nil }
            return Reason(quote: quote, why: why)
        }
        .prefix(maxReasons)
        .map { $0 }

        // A warning must be backed by at least one real quote from the message.
        if verdict.isWarning && reasons.isEmpty { throw .warningWithoutEvidence }

        let steps = (raw.next_steps ?? []).map(clean).filter { !$0.isEmpty }
        guard steps.count == 3 else { throw .wrongNumberOfSteps(steps.count) }

        return CheckResult(
            verdict: verdict,
            scamType: verdict == .noRedFlags ? .none : scamType,
            summary: summary,
            reasons: reasons,
            nextSteps: steps
        )
    }

    /// Finds the first balanced `{ ... }` object, ignoring braces inside strings.
    static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < text.endIndex {
            let c = text[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return String(text[start...i]) }
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    static func clean(_ s: String) -> String {
        let collapsed = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maxFieldLength))
    }

    /// Case-, whitespace- and quote-style-insensitive containment check.
    static func containsQuote(_ quote: String, in message: String) -> Bool {
        normalize(message).contains(normalize(quote))
    }

    private static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        let trimmed = folded.trimmingCharacters(in: CharacterSet(charactersIn: "\"' .,!?…"))
        return trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
