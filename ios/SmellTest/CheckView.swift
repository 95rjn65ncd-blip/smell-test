import SwiftUI
import SmellTestCore

@MainActor
@Observable
final class CheckModel {
    enum State {
        case idle
        case checking
        case done(CheckEngine.Outcome)
        case needsSecondOpinion(EscalationReason)
        case failed(String)
    }

    var message = ""
    var state: State = .idle

    var canCheck: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isChecking
    }

    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    var isChecking: Bool {
        if case .checking = state { return true }
        return false
    }

    func check() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state = .checking
        do {
            state = .done(try await CheckEngine().checkOnDevice(text))
        } catch .needsSecondOpinion(let reason) {
            state = .needsSecondOpinion(reason)
        } catch {
            // Unreadable answer or model error: never show a made-up verdict.
            state = .failed("Couldn't check this one. Try again.")
        }
    }

    func reset() {
        message = ""
        state = .idle
    }
}

struct CheckView: View {
    @State private var model = CheckModel()
    @FocusState private var editorFocused: Bool
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    input
                    stateView
                    if !model.isIdle && !model.isChecking {
                        Button {
                            model.reset()
                        } label: {
                            Label("Check another message", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding()
            }
            .navigationTitle("Smell Test")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDiagnostics = true } label: { Image(systemName: "stethoscope") }
                        .accessibilityLabel("Diagnostics")
                }
                #endif
            }
            .sheet(isPresented: $showDiagnostics) { HelloHybridView() }
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a text, email or link you're unsure about.")
                .font(.headline)
            TextEditor(text: $model.message)
                .focused($editorFocused)
                .frame(minHeight: 140)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                .accessibilityLabel("Message to check")
            HStack {
                // The system Paste button reads the clipboard only when tapped, without a prompt.
                PasteButton(payloadType: String.self) { strings in
                    if let s = strings.first { model.message = s }
                }
                .buttonBorderShape(.capsule)
                Spacer()
                Button {
                    editorFocused = false
                    Task { await model.check() }
                } label: {
                    Label("Check it", systemImage: "checkmark.shield")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCheck)
            }
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 12) {
                ProgressView()
                Text("Checking on your iPhone…")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .done(let outcome):
            ResultCard(outcome: outcome)
        case .needsSecondOpinion(let reason):
            NoticeCard(icon: "iphone.slash", title: "Not checked", text: reason.explanation + noticeDetail(reason))
        case .failed(let text):
            NoticeCard(icon: "exclamationmark.triangle", title: "Couldn't check", text: text)
        }
    }

    private func noticeDetail(_ reason: EscalationReason) -> String {
        switch reason {
        case .onDeviceUnavailable:
            " " + (CheckEngine.unavailableReason() ?? "") + " Nothing was sent anywhere."
        case .tooLongForOnDevice:
            " Try pasting just the part that worries you. Nothing was sent anywhere."
        default:
            ""
        }
    }
}

struct NoticeCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.title3.bold())
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
