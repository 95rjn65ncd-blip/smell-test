import SwiftUI
import AVFoundation
import SmellTestCore

/// One clean card: verdict, one sentence, reasons, steps 1-2-3. Details sit behind "More".
struct ResultCard: View {
    let outcome: CheckEngine.Outcome
    @State private var alreadyActed = false
    @State private var situation: RecoverySituation = .clickedLink
    @State private var showMore = false
    @State private var showWhereItRan = false
    @State private var speaker = Speaker()

    private var result: CheckResult { outcome.result }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Text(result.summary).font(.title3)

            if let escalation = outcome.escalation {
                Label(escalation.explanation, systemImage: "questionmark.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !result.reasons.isEmpty { reasons }

            Toggle(isOn: $alreadyActed.animation()) {
                Text("Already clicked, paid or shared?").font(.headline)
            }
            if alreadyActed { recovery } else { steps(result.nextSteps, title: "What to do") }

            HStack {
                whereItRanBadge
                Spacer()
                Button {
                    speaker.toggle(speechText)
                } label: {
                    Label(speaker.isSpeaking ? "Stop" : "Read aloud",
                          systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2")
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup("More", isExpanded: $showMore) {
                VStack(alignment: .leading, spacing: 6) {
                    if result.scamType != .none { Text("Type: \(result.scamType.label)") }
                    Text("Time to verdict: \(outcome.milliseconds) ms")
                    Text("Model: \(outcome.modelVersion)")
                    Text("Sent off your iPhone: nothing")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
        }
        .padding()
        .background(.fill.quaternary, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint.opacity(0.6), lineWidth: 2))
        .sheet(isPresented: $showWhereItRan) { WhereItRanSheet(modelVersion: outcome.modelVersion) }
        .onDisappear { speaker.stop() }
    }

    private var header: some View {
        Label {
            Text(result.verdict.label).font(.largeTitle.bold())
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verdict: \(result.verdict.label)")
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why").font(.headline)
            ForEach(Array(result.reasons.enumerated()), id: \.offset) { _, reason in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}\(reason.quote)\u{201D}").italic()
                    Text(reason.why).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var recovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("What happened?", selection: $situation) {
                ForEach(RecoverySituation.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            steps(situation.steps, title: "Do this now")
        }
    }

    private func steps(_ items: [String], title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(i + 1)").font(.headline).frame(width: 24, height: 24)
                        .background(tint.opacity(0.2), in: .circle)
                    Text(step)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var whereItRanBadge: some View {
        Button { showWhereItRan = true } label: {
            Label(ranOnDevice ? "Checked on your iPhone" : "Checked in the cloud",
                  systemImage: ranOnDevice ? "iphone" : "cloud")
                .font(.callout.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(ranOnDevice ? .green : .blue)
        .accessibilityHint("Explains where this check ran")
    }

    private var ranOnDevice: Bool { WhereItRan.isOnDevice(outcome.modelVersion) }

    private var tint: Color {
        switch result.verdict {
        case .scam: .red
        case .likelyScam: .orange
        case .notSure: .yellow
        case .noRedFlags: .teal
        }
    }

    private var icon: String {
        switch result.verdict {
        case .scam: "xmark.octagon.fill"
        case .likelyScam: "exclamationmark.triangle.fill"
        case .notSure: "questionmark.circle.fill"
        case .noRedFlags: "checkmark.circle"
        }
    }

    private var speechText: String {
        var parts = ["\(result.verdict.label).", result.summary]
        for r in result.reasons { parts.append(r.why) }
        let list = alreadyActed ? situation.steps : result.nextSteps
        for (i, s) in list.enumerated() { parts.append("Step \(i + 1). \(s)") }
        return parts.joined(separator: " ")
    }
}

enum WhereItRan {
    static func isOnDevice(_ modelVersion: String) -> Bool {
        modelVersion.contains("apple-foundation-models")
    }
}

struct WhereItRanSheet: View {
    let modelVersion: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if WhereItRan.isOnDevice(modelVersion) {
                    Text("This check ran on your iPhone, using Apple's on-device model.")
                    Text("Your message wasn't sent anywhere. It works in airplane mode too.")
                } else {
                    Text("This check ran in the cloud, on Google's Gemini model.")
                    Text("Only the text you approved was sent, with personal details removed first.")
                }
                Text("Model reported by the app: \(modelVersion)")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Where this ran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium])
    }
}

@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ text: String) {
        if isSpeaking { stop(); return }
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
        isSpeaking = true
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
