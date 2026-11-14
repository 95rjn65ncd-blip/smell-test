import Foundation
import FirebaseAILogic
import SmellTestCore

/// Runs the on-device-only first pass. The original message only ever goes to a session built
/// on the on-device model alone, which has no cloud path (see docs/DESIGN.md).
struct CheckEngine {
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

    static var onDeviceAvailable: Bool {
        FirebaseAI.SystemLanguageModel.default.isAvailable
    }

    static func unavailableReason() -> String? {
        switch FirebaseAI.SystemLanguageModel.default.availability {
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
        let session = ai.generativeModelSession(model: FirebaseAI.SystemLanguageModel.default)
        let start = Date()
        let raw: String
        let modelVersion: String
        do {
            let response = try await session.respond(to: VerdictPrompt.prompt(for: message))
            raw = response.content
            modelVersion = response.rawResponse.modelVersion
        } catch {
            throw .modelError(error.localizedDescription)
        }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let result: CheckResult
        do {
            result = try VerdictParser.parse(raw, message: message)
        } catch {
            throw .unreadableAnswer
        }
        return Outcome(result: result, modelVersion: modelVersion, milliseconds: ms,
                       escalation: EscalationPolicy.afterOnDevice(result, message: message))
    }
}
