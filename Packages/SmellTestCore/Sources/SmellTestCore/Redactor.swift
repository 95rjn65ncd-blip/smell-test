import Foundation

/// The Privacy Shield's first layer: fixed patterns that replace personal details with labels
/// such as `[PHONE]` before anything can be sent. It's deterministic, so its guarantees are
/// testable. (The on-device model's name-catching is a second, best-effort layer on top.)
///
/// It keeps what matters for spotting a scam: money amounts, link domains, and the wording.
public enum Redactor {
    public enum Kind: String, CaseIterable, Sendable {
        case email = "EMAIL"
        case link = "LINK"
        case ssn = "SSN"
        case card = "CARD"
        case phone = "PHONE"
        case address = "ADDRESS"
        case account = "ACCOUNT"
        case code = "CODE"
        case name = "NAME"

        public var label: String { "[\(rawValue)]" }
    }

    public struct Result: Equatable, Sendable {
        /// The text with personal details replaced by labels. Safe to show and to send.
        public let text: String
        /// How many of each kind were replaced. Originals are never kept.
        public let counts: [Kind: Int]

        public var totalRedactions: Int { counts.values.reduce(0, +) }
    }

    public static func redact(_ input: String) -> Result {
        var text = input
        var counts: [Kind: Int] = [:]

        func apply(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive],
                   _ kind: Kind, template: String? = nil) {
            let regex = try! NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..., in: text)
            let n = regex.numberOfMatches(in: text, range: range)
            guard n > 0 else { return }
            counts[kind, default: 0] += n
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template ?? kind.label)
        }

        // Order matters: the most specific patterns run first.
        apply(#"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, .email)
        text = redactLinks(text, counts: &counts)
        apply(#"\b\d{3}-\d{2}-\d{4}\b"#, .ssn)
        apply(#"\b(?:\d[ \-]?){12,18}\d\b"#, .card)
        apply(#"(?<![\w$])(?:\+?1[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}\b"#, .phone)
        apply(#"(?<![\w$])\+\d{1,3}(?:[\s.\-]?\d{2,4}){2,5}\b"#, .phone)
        apply(#"\b\d{1,6}\s+(?:[A-Za-z0-9.]+\s+){0,3}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way|Place|Pl|Terrace|Ter|Circle|Cir|Parkway|Pkwy|Highway|Hwy)\b\.?(?:,?\s*(?:Apt|Apartment|Unit|Suite|Ste|#)\.?\s*[A-Za-z0-9\-]+)?"#, .address)
        // "ending in 4821", "acct ...4821", "account #4821"
        apply(#"\b(ending(?:\s+in)?|acct\.?|account(?:\s+(?:no\.?|number))?|card)(\s*(?:#|no\.?|number|\.{2,}|[•*x]+)?\s*)\d{4,}\b"#,
              .account, template: "$1$2[ACCOUNT]")
        apply(#"(?<![\w$€£.,])\d{9,17}(?![\w.,]\d)"#, .account)
        // Alphanumeric codes and IDs with at least two digits, like A7X9Q2 or 1Z999AA10123456784.
        apply(#"\b(?=[A-Z0-9]*\d[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{6,24}\b"#, .code)
        // Standalone 4–8 digit numbers (codes, PINs, ZIPs), but not money amounts.
        apply(#"(?<![\w$€£.,])\d{4,8}(?![\w%]|[.,]\d)"#, .code)
        // A name right after a greeting: "Hi Margaret," / "Dear Mr. Lopez".
        apply(#"\b(Dear|Hi|Hello|Hey)(\s+(?:Mr\.?|Mrs\.?|Ms\.?|Dr\.?)?\s*)[A-Z][a-z'\-]+(?:\s+[A-Z][a-z'\-]+)?"#,
              options: [], .name, template: "$1$2[NAME]")

        return Result(text: text, counts: counts)
    }

    /// Keeps a link's domain (the strongest scam signal) but drops anything after it that
    /// could identify the person: query strings, fragments and token-like path segments.
    static func redactLinks(_ input: String, counts: inout [Kind: Int]) -> String {
        let regex = try! NSRegularExpression(
            pattern: #"\b(?:https?://|www\.)[^\s<>"']+"#, options: [.caseInsensitive])
        var output = input
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        for match in matches.reversed() {
            guard let r = Range(match.range, in: output) else { continue }
            let original = String(output[r])
            let trailing = original.reversed().prefix { ".,;:!?)".contains($0) }
            let link = String(original.dropLast(trailing.count))
            let kept = safeLink(link)
            if kept != link { counts[.link, default: 0] += 1 }
            output.replaceSubrange(r, with: kept + String(trailing.reversed()))
        }
        return output
    }

    static func safeLink(_ link: String) -> String {
        let withScheme = link.lowercased().hasPrefix("www.") ? "https://" + link : link
        guard let comps = URLComponents(string: withScheme), let host = comps.host else { return Kind.link.label }
        let scheme = link.lowercased().hasPrefix("www.") ? "" : "\(comps.scheme ?? "https")://"
        let segments = comps.path.split(separator: "/").map(String.init)
        let safeSegments = segments.map { seg -> String in
            let digits = seg.filter(\.isNumber).count
            let looksLikeToken = seg.count >= 16 || digits >= 4 || seg.contains("@")
            return looksLikeToken ? Kind.link.label : seg
        }
        var result = scheme + host
        if !safeSegments.isEmpty { result += "/" + safeSegments.joined(separator: "/") }
        if comps.query != nil || comps.fragment != nil { result += "?" + Kind.link.label }
        return result
    }
}
