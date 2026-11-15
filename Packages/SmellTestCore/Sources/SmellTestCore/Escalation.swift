import Foundation

/// Fixed red-flag patterns. These don't decide the verdict; they're an independent check
/// used to spot when the model's answer disagrees with obvious warning signs.
public enum RedFlagScanner {
    public enum Signal: String, CaseIterable, Sendable {
        case urgency, paymentPressure, credentialRequest, suspiciousLink, impersonation
    }

    static let patterns: [Signal: [String]] = [
        .urgency: [#"within \d+ (hours?|minutes?)"#, #"\b(act now|immediately|final notice|last chance|urgent|expires? today)\b"#,
                   #"\b(suspended|locked|deactivated|on hold)\b"#],
        .paymentPressure: [#"\bgift ?cards?\b"#, #"\b(wire|bitcoin|crypto|usdt)\b"#, #"\b(pay|send)\b.{0,30}\$\d"#,
                           #"\b(fee|fine|penalty|unpaid)\b"#],
        .credentialRequest: [#"\b(verify|confirm) (your|the) (account|identity|address|details|information)\b"#,
                             #"\b(password|ssn|social security|routing|pin)\b"#, #"\b(reply|send|share).{0,20}\bcode\b"#],
        .suspiciousLink: [#"https?://[^\s/]+\.(top|xyz|help|info|click|live|shop|icu|buzz|cam|rest)\b"#,
                          #"https?://[^\s/]*-(verify|secure|login|pay|support|redelivery|tolls?)[^\s/]*"#],
        .impersonation: [#"\b(fraud (dept|department)|security team|irs|tax office|customs|police|sheriff)\b"#,
                         #"\b(grandma|grandpa|mom|dad)\b.{0,40}\b(jail|hospital|accident|arrested)\b"#],
    ]

    public static func scan(_ text: String) -> Set<Signal> {
        var found = Set<Signal>()
        for (signal, list) in patterns {
            for p in list where text.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil {
                found.insert(signal)
                break
            }
        }
        return found
    }

    /// At least `minimum` different kinds of warning sign (2 unless Remote Config says otherwise).
    public static func isStrong(_ signals: Set<Signal>, minimum: Int = Settings.defaults.minWarningSigns) -> Bool {
        signals.count >= minimum
    }
}

/// Decides when a second opinion is worth offering. Never based on the model's own confidence.
public enum EscalationReason: String, Equatable, Sendable {
    case modelNotSure
    case patternsDisagree
    case tooLongForOnDevice
    case onDeviceUnavailable
    case onDeviceCouldNotAnswer
    /// The model warned, but the message has none of the fixed warning signs.
    case warningWithoutCommonSigns

    public var explanation: String {
        switch self {
        case .modelNotSure: "Your iPhone wasn't sure about this one."
        case .patternsDisagree: "Your iPhone found no red flags, but the message has common warning signs."
        case .tooLongForOnDevice: "This message is too long to check on your iPhone."
        case .onDeviceUnavailable: "Your iPhone can't check messages on its own right now."
        case .onDeviceCouldNotAnswer: "Your iPhone couldn't give a clear answer on this one."
        case .warningWithoutCommonSigns: "This message doesn't have the usual warning signs, so a second opinion may help."
        }
    }
}

public enum EscalationPolicy {
    /// Bump when the rules change; benchmark results are tagged with it.
    /// 1: escalate on "not sure" or strong signs vs "no red flags". 2: adds warning-without-signs → "Not sure".
    public static let rulesVersion = "2"

    /// Before any model runs: can the on-device first pass even happen?
    public static func preCheck(message: String, onDeviceAvailable: Bool,
                                currentPatterns: [String] = []) -> EscalationReason? {
        if !onDeviceAvailable { return .onDeviceUnavailable }
        if !VerdictPrompt.fitsOnDevice(message: message, currentPatterns: currentPatterns) { return .tooLongForOnDevice }
        return nil
    }

    /// After the on-device first pass.
    public static func afterOnDevice(_ result: CheckResult, message: String,
                                     minWarningSigns: Int = Settings.defaults.minWarningSigns) -> EscalationReason? {
        if result.verdict == .notSure { return .modelNotSure }
        if result.verdict == .noRedFlags
            && RedFlagScanner.isStrong(RedFlagScanner.scan(message), minimum: minWarningSigns) {
            return .patternsDisagree
        }
        return nil
    }

    /// The full rule for the on-device first pass: what to show, and whether to offer a second opinion.
    ///
    /// The fixed patterns can disagree with the model in either direction:
    /// - "No red flags" on a message with strong warning signs: shown as is, second opinion offered.
    /// - "Scam" or "Likely scam" on a message with NO fixed warning signs: shown as "Not sure", with
    ///   the model's quotes kept, fixed wording and steps, and a second opinion offered. The benchmark
    ///   showed the small on-device model flags many ordinary messages; this cuts those false alarms.
    public static func firstPass(_ result: CheckResult, message: String,
                                 minWarningSigns: Int = Settings.defaults.minWarningSigns)
        -> (result: CheckResult, escalation: EscalationReason?) {
        if result.verdict.isWarning && RedFlagScanner.scan(message).isEmpty {
            let shown = CheckResult(verdict: .notSure, scamType: result.scamType,
                                    summary: "Your iPhone thought this might be a scam, but isn't sure.",
                                    reasons: result.reasons, nextSteps: SafeSteps.steps(for: .notSure))
            return (shown, .warningWithoutCommonSigns)
        }
        return (result, afterOnDevice(result, message: message, minWarningSigns: minWarningSigns))
    }
}
