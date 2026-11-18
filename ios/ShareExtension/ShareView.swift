import SwiftUI
import UIKit
import SmellTestCore

@MainActor
@Observable
final class ShareModel {
    enum State {
        case reading
        case checking
        case done(CheckEngine.Outcome)
        case needsSecondOpinion(EscalationReason)
        case failed(title: String, text: String)
    }

    var state: State = .checking
    private(set) var message = ""
    /// True when `message` came from reading a shared screenshot, so the sheet shows the words read.
    private(set) var fromScreenshot = false
    var copied = false
    let firebaseReady: Bool
    let close: () -> Void

    init(firebaseReady: Bool, close: @escaping () -> Void) {
        self.firebaseReady = firebaseReady
        self.close = close
    }

    func start(text: String?) async {
        guard firebaseReady else {
            state = .failed(title: "Firebase isn't set up", text: "Open Smell Test for setup steps.")
            return
        }
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            state = .failed(title: "Nothing to check", text: "Select the text of a message or email, or a screenshot of it, then share it to Smell Test.")
            return
        }
        message = text
        state = .checking
        do {
            // Built-in settings: the share sheet doesn't fetch Remote Config.
            state = .done(try await CheckEngine(settings: .defaults).checkOnDevice(text))
        } catch .needsSecondOpinion(let reason) {
            state = .needsSecondOpinion(reason)
        } catch {
            // Never show a made-up verdict.
            state = .failed(title: "Couldn't check", text: "Couldn't check this one. Try again.")
        }
    }

    func start(screenshot: Data) async {
        guard firebaseReady else {
            state = .failed(title: "Firebase isn't set up", text: "Open Smell Test for setup steps.")
            return
        }
        state = .reading
        do {
            let text = try await ScreenshotReader.read(screenshot)
            fromScreenshot = true
            await start(text: text)
        } catch .noText {
            state = .failed(title: "Nothing to check", text: "Couldn't find any words in that picture.")
        } catch {
            state = .failed(title: "Couldn't check", text: "Couldn't read that picture. Try another one.")
        }
    }

    func copyMessage() {
        UIPasteboard.general.string = message
        copied = true
    }
}

struct ShareView: View {
    let model: ShareModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding()
            }
            .navigationTitle("Smell Test")
            .navigationBarTitleDisplayMode(.inline)
            .brandScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.close() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.fromScreenshot { screenshotWords }
        switch model.state {
        case .reading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Reading your screenshot on your iPhone…")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .checking:
            HStack(spacing: 12) {
                ProgressView()
                Text("Checking on your iPhone…")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .done(let outcome):
            ResultCard(outcome: outcome, sentText: nil)
            if outcome.escalation != nil { secondOpinionHint }
        case .needsSecondOpinion(let reason):
            NoticeCard(icon: "iphone.slash", title: "Not checked on your iPhone",
                       text: reason.explanation + detail(reason) + " Nothing was sent anywhere.")
            if reason != .onDeviceUnavailable { secondOpinionHint }
        case .failed(let title, let text):
            NoticeCard(icon: "exclamationmark.triangle", title: title, text: text)
        }
    }

    /// The words the phone read from the shared screenshot, so the user can see what was checked.
    private var screenshotWords: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Words read from your screenshot on your iPhone", systemImage: "text.viewfinder")
                .font(.footnote)
                .foregroundStyle(Brand.mist)
            Text(model.message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Brand.navyRaised, in: .rect(cornerRadius: 12))
                .textSelection(.enabled)
        }
    }

    /// The share sheet never sends anything. A second opinion happens in the app, through the Privacy Shield.
    private var secondOpinionHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("For a second opinion with personal details removed, copy the message, open Smell Test and paste it.")
            Button {
                model.copyMessage()
            } label: {
                Label(model.copied ? "Copied" : "Copy message", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func detail(_ reason: EscalationReason) -> String {
        switch reason {
        case .onDeviceUnavailable: " " + (CheckEngine.unavailableReason() ?? "")
        default: ""
        }
    }
}
