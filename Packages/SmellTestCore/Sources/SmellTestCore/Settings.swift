import Foundation

/// Values the app can change without a new build (supplied by Firebase Remote Config).
/// Every value is checked here; anything out of range falls back to the built-in default,
/// so a bad console edit can't break checks or loosen the privacy rules.
public struct Settings: Equatable, Sendable {
    /// Cloud model for the second opinion.
    public var cloudModel: String
    /// Kill switch: false hides the second opinion entirely. Nothing is ever sent while off.
    public var secondOpinionEnabled: Bool
    /// How many different kinds of warning sign count as "strong" when deciding the
    /// patterns disagree with a "no red flags" answer. Set from benchmark data.
    public var minWarningSigns: Int
    /// Short descriptions of scams going around now, added to the prompt (at most 5).
    public var currentPatterns: [String]

    public static let defaults = Settings(cloudModel: "gemini-3.5-flash-lite", secondOpinionEnabled: true,
                                          minWarningSigns: 2, currentPatterns: [])

    public enum Key {
        public static let cloudModel = "cloud_model"
        public static let secondOpinionEnabled = "second_opinion_enabled"
        public static let minWarningSigns = "min_warning_signs"
        public static let currentPatterns = "current_scam_patterns"
    }

    public init(cloudModel: String, secondOpinionEnabled: Bool, minWarningSigns: Int, currentPatterns: [String]) {
        self.cloudModel = cloudModel
        self.secondOpinionEnabled = secondOpinionEnabled
        self.minWarningSigns = minWarningSigns
        self.currentPatterns = currentPatterns
    }

    static let maxPatterns = 5
    static let maxPatternLength = 120

    /// Builds settings from raw strings, validating each one.
    public static func from(cloudModel: String?, secondOpinionEnabled: String?,
                            minWarningSigns: String?, currentPatterns: String?) -> Settings {
        var s = defaults
        if let m = cloudModel?.trimmingCharacters(in: .whitespaces),
           m.range(of: #"^gemini-[a-z0-9.\-]{1,40}$"#, options: .regularExpression) != nil {
            s.cloudModel = m
        }
        switch secondOpinionEnabled?.lowercased() {
        case "false": s.secondOpinionEnabled = false
        case "true": s.secondOpinionEnabled = true
        default: break
        }
        if let n = minWarningSigns.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }),
           (1...RedFlagScanner.Signal.allCases.count).contains(n) {
            s.minWarningSigns = n
        }
        if let raw = currentPatterns {
            s.currentPatterns = raw.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count <= maxPatternLength }
                .prefix(maxPatterns)
                .map { String($0) }
        }
        return s
    }
}
