import Foundation

/// The only four verdicts the app can show. There is deliberately no "safe" verdict:
/// the best the app ever says is that it found no red flags.
public enum Verdict: String, Codable, CaseIterable, Sendable {
    case scam
    case likelyScam = "likely_scam"
    case notSure = "not_sure"
    case noRedFlags = "no_red_flags"

    public var label: String {
        switch self {
        case .scam: "Scam"
        case .likelyScam: "Likely scam"
        case .notSure: "Not sure"
        case .noRedFlags: "No red flags found"
        }
    }

    /// True for verdicts that say something looks wrong.
    public var isWarning: Bool { self == .scam || self == .likelyScam }
}

public enum ScamType: String, Codable, CaseIterable, Sendable {
    case bankOrGovernmentImpersonation = "bank_or_government_impersonation"
    case packageDelivery = "package_delivery"
    case toll
    case romance
    case job
    case techSupport = "tech_support"
    case prize
    case crypto
    case familyEmergency = "family_emergency"
    case other
    case none

    public var label: String {
        switch self {
        case .bankOrGovernmentImpersonation: "Bank or government impersonation"
        case .packageDelivery: "Package delivery"
        case .toll: "Unpaid toll"
        case .romance: "Romance"
        case .job: "Job offer"
        case .techSupport: "Tech support"
        case .prize: "Prize or lottery"
        case .crypto: "Crypto investment"
        case .familyEmergency: "Family emergency"
        case .other: "Other"
        case .none: "None"
        }
    }
}

/// One reason behind a verdict. `quote` must be words that really appear in the message.
public struct Reason: Codable, Equatable, Sendable {
    public let quote: String
    public let why: String

    public init(quote: String, why: String) {
        self.quote = quote
        self.why = why
    }
}

/// A validated check result. Only `VerdictParser` creates these from model output.
public struct CheckResult: Equatable, Sendable {
    public let verdict: Verdict
    public let scamType: ScamType
    public let summary: String
    public let reasons: [Reason]
    public let nextSteps: [String]

    public init(verdict: Verdict, scamType: ScamType, summary: String, reasons: [Reason], nextSteps: [String]) {
        self.verdict = verdict
        self.scamType = scamType
        self.summary = summary
        self.reasons = reasons
        self.nextSteps = nextSteps
    }
}
