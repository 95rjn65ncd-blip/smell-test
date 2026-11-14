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

    /// Two or more different kinds of warning sign.
    public static func isStrong(_ signals: Set<Signal>) -> Bool { signals.count >= 2 }
}

/// Decides when a second opinion is worth offering. Never based on the model's own confidence.
public enum EscalationReason: String, Equatable, Sendable {
    case modelNotSure
    case patternsDisagree
    case tooLongForOnDevice
    case onDeviceUnavailable

    public var explanation: String {
        switch self {
        case .modelNotSure: "Your iPhone wasn't sure about this one."
        case .patternsDisagree: "Your iPhone found no red flags, but the message has common warning signs."
        case .tooLongForOnDevice: "This message is too long to check on your iPhone."
        case .onDeviceUnavailable: "Your iPhone can't check messages on its own right now."
        }
    }
}

public enum EscalationPolicy {
    /// Before any model runs: can the on-device first pass even happen?
    public static func preCheck(message: String, onDeviceAvailable: Bool) -> EscalationReason? {
        if !onDeviceAvailable { return .onDeviceUnavailable }
        if !VerdictPrompt.fitsOnDevice(message: message) { return .tooLongForOnDevice }
        return nil
    }

    /// After the on-device first pass.
    public static func afterOnDevice(_ result: CheckResult, message: String) -> EscalationReason? {
        if result.verdict == .notSure { return .modelNotSure }
        if result.verdict == .noRedFlags && RedFlagScanner.isStrong(RedFlagScanner.scan(message)) {
            return .patternsDisagree
        }
        return nil
    }
}
