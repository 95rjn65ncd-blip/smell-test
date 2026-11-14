import SwiftUI
import FirebaseAILogic

/// Day-1 smoke test: proves the on-device model and the hybrid router both work.
/// Replaced by the real check screen once the verdict engine exists.
struct HelloHybridView: View {
    @State private var availabilityText = "Checking…"
    @State private var onDeviceResult = ""
    @State private var hybridResult = ""
    @State private var cloudResult = ""
    @State private var isRunning = false

    // Placeholder until Remote Config holds the cloud model name.
    private var cloudModelName: String { RemoteSettings.current.cloudModel }

    var body: some View {
        NavigationStack {
            List {
                Section("On-device model") {
                    Text(availabilityText)
                }
                Section("Remote Config") {
                    let s = RemoteSettings.current
                    Text("From server: \(RemoteSettings.serverValueCount) of 4 values")
                    Text("Cloud model: \(s.cloudModel)")
                    Text("Second opinion: \(s.secondOpinionEnabled ? "on" : "paused")")
                    Text("Warning signs to escalate: \(s.minWarningSigns)")
                    Text("Current scam patterns: \(s.currentPatterns.count)")
                }
                Section {
                    Button("Run on-device only") { Task { await runOnDeviceOnly() } }
                    if !onDeviceResult.isEmpty { Text(onDeviceResult).font(.callout) }
                } footer: {
                    Text("Never leaves the phone. Fails if the on-device model is unavailable.")
                }
                Section {
                    Button("Run hybrid (fixed test prompt)") { Task { await runHybrid() } }
                    if !hybridResult.isEmpty { Text(hybridResult).font(.callout) }
                } footer: {
                    Text("On-device first, cloud if unavailable. Uses a fixed prompt with no personal data.")
                }
                #if DEBUG
                Section {
                    Button("Run cloud only (dev test)") { Task { await runCloudOnly() } }
                    if !cloudResult.isEmpty { Text(cloudResult).font(.callout) }
                } footer: {
                    Text("Debug builds only. Sends a fixed prompt with no personal data to the cloud model.")
                }
                #endif
            }
            .disabled(isRunning)
            .navigationTitle("Smell Test")
            .task { availabilityText = Self.describeAvailability() }
        }
    }

    static func describeAvailability() -> String {
        switch FirebaseAI.SystemLanguageModel.default.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "This device can't run Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off in Settings"
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading"
        case let .unavailable(reason):
            return "Unavailable: \(reason)"
        }
    }

    private func runOnDeviceOnly() async {
        isRunning = true
        defer { isRunning = false }
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        // A session with ONLY the system model: no cloud fallback is possible.
        let session = ai.generativeModelSession(model: FirebaseAI.SystemLanguageModel.default)
        do {
            let start = Date()
            let response = try await session.respond(to: "Reply with one short friendly sentence saying hello.")
            onDeviceResult = "\(response.content)\n— ran on: \(response.rawResponse.modelVersion) in \(Self.ms(since: start))"
        } catch {
            onDeviceResult = "Couldn't run on-device: \(error.localizedDescription)"
        }
    }

    private func runHybrid() async {
        isRunning = true
        defer { isRunning = false }
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        let cloud = ai.geminiModel(name: cloudModelName)
        let device = FirebaseAI.SystemLanguageModel.default
        let hybrid = HybridModel(primary: device, secondary: cloud)
        let session = ai.generativeModelSession(model: hybrid)
        do {
            let start = Date()
            let response = try await session.respond(to: "Reply with one short friendly sentence saying hello.")
            hybridResult = "\(response.content)\n— ran on: \(response.rawResponse.modelVersion) in \(Self.ms(since: start))"
        } catch {
            hybridResult = "Couldn't run: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    private func runCloudOnly() async {
        isRunning = true
        defer { isRunning = false }
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        // A session with ONLY the cloud model, to prove the cloud path and App Check work.
        let session = ai.generativeModelSession(model: ai.geminiModel(name: cloudModelName))
        do {
            let start = Date()
            let response = try await session.respond(to: "Reply with one short friendly sentence saying hello.")
            cloudResult = "\(response.content)\n— ran on: \(response.rawResponse.modelVersion) in \(Self.ms(since: start))"
        } catch {
            cloudResult = "Couldn't run in the cloud: \(error.localizedDescription)"
        }
    }
    #endif

    private static func ms(since start: Date) -> String {
        "\(Int(Date().timeIntervalSince(start) * 1000)) ms"
    }
}
