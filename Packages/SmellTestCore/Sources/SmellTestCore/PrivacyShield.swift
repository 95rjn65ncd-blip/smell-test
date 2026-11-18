import Foundation

/// What the user sees before anything leaves the phone.
public struct ShieldPreview: Equatable, Sendable {
    /// The redacted text, exactly as it would be sent.
    public let text: String
    public let counts: [Redactor.Kind: Int]
    /// False when the on-device model couldn't look for names. The UI then warns louder
    /// and asks the user to read and edit the text themselves.
    public let namesChecked: Bool
}

/// Text the user has seen and approved. The only way to make one is `PrivacyShield.approve`,
/// and the cloud-capable code path only accepts this type, so original text can't reach it.
public struct ApprovedText: Equatable, Sendable {
    public let text: String
    fileprivate init(_ text: String) { self.text = text }
}

public enum PrivacyShield {
    /// Layer 1 (fixed patterns, always) + layer 2 (names found by the on-device model, if any).
    /// - Parameter names: names the on-device model found in the ORIGINAL text, or nil if it couldn't run.
    public static func preview(original: String, names: [String]?) -> ShieldPreview {
        let patterned = Redactor.redact(original)
        var text = patterned.text
        var counts = patterned.counts
        if let names {
            let replaced = replaceNames(in: text, names: names)
            text = replaced.text
            if replaced.count > 0 { counts[.name, default: 0] += replaced.count }
        }
        return ShieldPreview(text: text, counts: counts, namesChecked: names != nil)
    }

    public enum ApprovalProblem: Error, Equatable, Sendable {
        case empty
        /// The (possibly edited) text still has details the fixed patterns catch. The caller
        /// shows the re-redacted version for another look instead of sending.
        case stillHasDetails(ShieldPreview)
    }

    /// Called when the user taps Send on exactly `shownText`. The fixed patterns run one more
    /// time, so anything typed in while editing is caught too.
    public static func approve(shownText: String, namesChecked: Bool) throws(ApprovalProblem) -> ApprovedText {
        let trimmed = shownText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        let again = Redactor.redact(trimmed)
        if again.totalRedactions > 0 {
            throw .stillHasDetails(ShieldPreview(text: again.text, counts: again.counts, namesChecked: namesChecked))
        }
        return ApprovedText(trimmed)
    }

    /// Family and role words. They don't identify anyone, and they're often the scam signal itself
    /// ("Hi Mum, new number"), so they're never replaced even if the name pass lists them.
    static let relationshipWords: Set<String> = [
        "mum", "mom", "mummy", "mommy", "mother", "ma", "mama", "dad", "daddy", "father", "pa", "papa",
        "nan", "nana", "nanna", "gran", "granny", "grandma", "grandmother", "grandpa", "grandad", "granddad",
        "grandfather", "aunt", "auntie", "aunty", "uncle", "son", "daughter", "sis", "sister", "bro", "brother",
        "babe", "baby", "honey", "darling", "love", "sweetheart", "sir", "madam", "dear", "cousin",
    ]

    static func isRelationshipWord(_ word: some StringProtocol) -> Bool {
        relationshipWords.contains(word.lowercased().trimmingCharacters(in: .punctuationCharacters))
    }

    /// Replaces whole-word occurrences of each name (and each part of a multi-word name).
    /// Family and role words are kept: "Aunt Rosa" becomes "Aunt [NAME]".
    static func replaceNames(in text: String, names: [String]) -> (text: String, count: Int) {
        var parts = Set<String>()
        for name in names {
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard cleaned.count >= 2 else { continue }
            let pieces = cleaned.split(separator: " ")
            if !pieces.contains(where: isRelationshipWord) { parts.insert(cleaned) }
            for piece in pieces where piece.count >= 2 && !isRelationshipWord(piece) {
                parts.insert(String(piece))
            }
        }
        // Longest first, so "Daniel Reyes" is replaced before "Daniel".
        var result = text
        var count = 0
        for part in parts.sorted(by: { $0.count > $1.count }) {
            let escaped = NSRegularExpression.escapedPattern(for: part)
            guard let regex = try? NSRegularExpression(pattern: "(?<![\\w\\[])\(escaped)(?![\\w\\]])",
                                                       options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let n = regex.numberOfMatches(in: result, range: range)
            if n > 0 {
                count += n
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: Redactor.Kind.name.label)
            }
        }
        return (result, count)
    }

    /// Prompt for the on-device name pass. Output: a JSON array of strings.
    public static func namePrompt(for text: String) -> String {
        """
        List every personal name of a real person in the message below (first names, last names, \
        nicknames). Do not list company names, product names, places, or family words like Mum, Dad \
        or Grandma. Answer with only a JSON \
        array of strings, like ["Ana", "Mr. Lee"]. If there are none, answer [].

        <<<MESSAGE
        \(text)
        MESSAGE>>>
        """
    }

    /// Parses the name pass output. Returns nil if it can't be read, so the caller treats names as unchecked.
    public static func parseNames(_ output: String) -> [String]? {
        guard let start = output.firstIndex(of: "["), let end = output.lastIndex(of: "]"), start < end,
              let data = String(output[start...end]).data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return names
    }
}
