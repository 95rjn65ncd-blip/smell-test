import Foundation
import os
import FirebaseAILogic
import SmellTestCore

/// Runs the on-device-only first pass. The original message only ever goes to a session built
/// on the on-device model alone, which has no cloud path (see docs/DESIGN.md).
struct CheckEngine {
    /// Logs only the KIND of failure. Never message text, prompts or answers.
    private static let log = Logger(subsystem: "com.cognitoagora.smelltest", category: "check")
    struct Outcome {
        let result: CheckResult
        /// The SDK's own report of which model ran.
        let modelVersion: String
        let milliseconds: Int
        /// Set when a second opinion would be worth offering.
        let escalation: EscalationReason?
    }

    enum Failure: Error {
        /// The phone can't run this check by itself; nothing was sent anywhere.
        case needsSecondOpinion(EscalationReason)
        /// The model answered, but not in a form we can trust. Nothing is shown.
        case unreadableAnswer
        /// The on-device model threw (for example, a guardrail or a system error).
        case modelError(String)
    }

    /// Apple's on-device model with the guardrails Apple provides for analyzing text the user
    /// supplies (classifying, summarizing). The default guardrails often refuse scam text itself.
    static let onDeviceModel = FirebaseAI.SystemLanguageModel(guardrails: .permissiveContentTransformations)

    static var onDeviceAvailable: Bool {
        onDeviceModel.isAvailable
    }

    static func unavailableReason() -> String? {
        switch Self.onDeviceModel.availability {
        case .available: nil
        case .unavailable(.deviceNotEligible): "This iPhone can't run Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): "Apple Intelligence is turned off. You can turn it on in Settings › Apple Intelligence & Siri."
        case .unavailable(.modelNotReady): "Apple Intelligence is still getting ready on this iPhone. Try again in a few minutes."
        case .unavailable: "Your iPhone can't check messages on its own right now."
        }
    }

    func checkOnDevice(_ message: String) async throws(Failure) -> Outcome {
        if let reason = EscalationPolicy.preCheck(message: message, onDeviceAvailable: Self.onDeviceAvailable) {
            throw .needsSecondOpinion(reason)
        }
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        // On-device ONLY: no HybridModel here, so this text can't fall back to the cloud.
        // A new session per check, so no history carries over between messages.
        let session = ai.generativeModelSession(model: Self.onDeviceModel)
        let start = Date()
        let raw: String
        let modelVersion: String
        do {
            let response = try await session.respond(to: VerdictPrompt.prompt(for: message))
            raw = response.content
            modelVersion = response.rawResponse.modelVersion
        } catch {
            Self.log.error("on-device model error: \(String(describing: type(of: error)), privacy: .public).\(Mirror(reflecting: error).children.first?.label ?? "?", privacy: .public)")
            // The phone couldn't answer (for example, a guardrail). Offer the redacted second opinion.
            throw .needsSecondOpinion(.onDeviceCouldNotAnswer)
        }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let result: CheckResult
        do {
            result = try VerdictParser.parse(raw, message: message)
        } catch {
            Self.log.error("unreadable on-device answer: \(Self.kind(of: error), privacy: .public)")
            // Never show an untrusted answer. Offer the redacted second opinion instead.
            throw .needsSecondOpinion(.onDeviceCouldNotAnswer)
        }
        return Outcome(result: result, modelVersion: modelVersion, milliseconds: ms,
                       escalation: EscalationPolicy.afterOnDevice(result, message: message))
    }

    /// The parser failure case name only, e.g. "wrongNumberOfSteps". Never any text.
    private static func kind(of error: VerdictParser.Failure) -> String {
        switch error {
        case .noJSON: "noJSON"
        case .malformedJSON: "malformedJSON"
        case .unknownVerdict: "unknownVerdict"
        case .unknownScamType: "unknownScamType"
        case .missingSummary: "missingSummary"
        case .wrongNumberOfSteps(let n): "wrongNumberOfSteps(\(n))"
        case .warningWithoutEvidence: "warningWithoutEvidence"
        }
    }

    // MARK: - Privacy Shield, layer 2

    /// Asks the on-device model (on-device ONLY) to list names in the original text.
    /// Returns nil when it can't run, so the Shield falls back to fixed patterns and warns louder.
    func findNamesOnDevice(_ original: String) async -> [String]? {
        guard Self.onDeviceAvailable, VerdictPrompt.fitsOnDevice(message: original) else { return nil }
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        let session = ai.generativeModelSession(model: Self.onDeviceModel)
        guard let response = try? await session.respond(to: PrivacyShield.namePrompt(for: original)) else { return nil }
        return PrivacyShield.parseNames(response.content)
    }

    // MARK: - Second opinion (the only path that can reach the cloud)

    /// Placeholder until Remote Config supplies the cloud model name.
    static let cloudModelName = "gemini-3.5-flash-lite"

    /// Runs the hybrid session on text the user approved in the Privacy Shield. It accepts only
    /// `ApprovedText`, which can't be built from the original message.
    ///
    /// Cloud first (a second opinion should come from a different, larger model), falling back
    /// to the on-device model when offline: `HybridModel(primary: cloud, secondary: device)`.
    func secondOpinion(_ approved: ApprovedText) async throws(Failure) -> Outcome {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        let cloud = ai.geminiModel(name: Self.cloudModelName)
        let device = Self.onDeviceModel
        let hybrid = HybridModel(primary: cloud, secondary: device)
        let session = ai.generativeModelSession(model: hybrid)
        let start = Date()
        let raw: String
        let modelVersion: String
        do {
            let response = try await session.respond(to: VerdictPrompt.prompt(for: approved.text))
            raw = response.content
            modelVersion = response.rawResponse.modelVersion
        } catch {
            throw .modelError(error.localizedDescription)
        }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        // Quotes are checked against the text that was actually sent.
        guard let result = try? VerdictParser.parse(raw, message: approved.text) else { throw .unreadableAnswer }
        return Outcome(result: result, modelVersion: modelVersion, milliseconds: ms, escalation: nil)
    }
}
