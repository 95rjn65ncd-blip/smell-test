import Foundation

/// Finds links, phone numbers and email addresses in model output.
enum ContactDetails {
    static let patterns = [
        #"https?://\S+"#,
        #"\bwww\.\S+"#,
        #"\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|net|org|gov|edu|io|co|us|uk|ca|info|top|xyz|help|click|live|shop|icu|buzz|cam|rest|app|site|online)\b"#,
        #"\S+@\S+\.\S+"#,
        #"\+?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b"#,
        #"\b\d{3}-\d{4}\b"#,
    ]

    static func find(in text: String) -> [String] {
        patterns.flatMap { p -> [String] in
            guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { return [] }
            let ns = text as NSString
            return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        }
    }

    static func contains(_ text: String) -> Bool { !find(in: text).isEmpty }

    /// True when `text` has contact details that don't appear in the original message.
    static func hasInvented(in text: String, message: String) -> Bool {
        let lower = message.lowercased()
        return find(in: text).contains { !lower.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
    }
}

/// Fixed, human-written next steps used in place of any model step that contains a link,
/// phone number or email address.
public enum SafeSteps {
    public static func steps(for verdict: Verdict) -> [String] {
        switch verdict {
        case .scam, .likelyScam:
            [
                "Don't tap links, reply, or call numbers in the message.",
                "If it claims to be someone you know, contact them using a number or app you already trust.",
                "Block the sender and delete the message.",
            ]
        case .notSure:
            [
                "Don't tap links or share anything until you're sure.",
                "Contact the sender using a number or app you already trust, not one in the message.",
                "Ask someone you trust to take a look.",
            ]
        case .noRedFlags:
            [
                "If a later message asks for money or details, check it again.",
                "If anything feels off, contact the sender using a number you already know.",
                "Never share codes or passwords with anyone who contacts you.",
            ]
        }
    }

    /// Fixed summaries, used when the model's summary can't be trusted (it copied a prompt example).
    public static func summary(for verdict: Verdict) -> String {
        switch verdict {
        case .scam: "This message shows several warning signs of a scam."
        case .likelyScam: "This message shows a warning sign of a scam."
        case .notSure: "Something about this message is a little unusual."
        case .noRedFlags: "We didn't find any of the usual warning signs."
        }
    }

    static func replacingContactDetails(in modelSteps: [String], verdict: Verdict) -> [String] {
        replacing(in: modelSteps, verdict: verdict, where: ContactDetails.contains)
    }

    /// Swaps each model step that matches `shouldReplace` for a fixed step not already shown.
    static func replacing(in modelSteps: [String], verdict: Verdict, where shouldReplace: (String) -> Bool) -> [String] {
        var spares = steps(for: verdict).filter { !modelSteps.contains($0) }
        return modelSteps.map { step in
            guard shouldReplace(step) else { return step }
            return spares.isEmpty ? steps(for: verdict)[0] : spares.removeFirst()
        }
    }
}
