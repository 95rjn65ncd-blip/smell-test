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

    enum SecondOpinion {
        case none
        case preparing
        case reviewing(ShieldPreview)
        case sending(sent: String)
        case done(CheckEngine.Outcome, sent: String)
        case failed(String)
    }

    var message = ""
    var state: State = .idle
    var second: SecondOpinion = .none
    /// The exact text that was checked on the phone. The Shield works from this.
    private var checkedText = ""

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

    var isReviewing: Bool {
        get { if case .reviewing = second { return true } else { return false } }
        set { if !newValue, isReviewing { second = .none } }
    }

    func check() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        checkedText = text
        second = .none
        state = .checking
        do {
            state = .done(try await CheckEngine(settings: RemoteSettings.current).checkOnDevice(text))
        } catch .needsSecondOpinion(let reason) {
            state = .needsSecondOpinion(reason)
        } catch {
            // Unreadable answer or model error: never show a made-up verdict.
            state = .failed("Couldn't check this one. Try again.")
        }
    }

    /// Step 1 of a second opinion: build the redacted preview on the phone. Nothing is sent.
    func prepareSecondOpinion() async {
        second = .preparing
        let names = await CheckEngine(settings: RemoteSettings.current).findNamesOnDevice(checkedText)
        second = .reviewing(PrivacyShield.preview(original: checkedText, names: names))
    }

    /// Step 2: the user tapped Send on exactly this text.
    func send(_ approvedText: String) async {
        // Re-approve here too, so this function can't be handed unapproved text.
        guard let approved = try? PrivacyShield.approve(shownText: approvedText, namesChecked: true) else {
            second = .failed("Couldn't send that text. Try again.")
            return
        }
        second = .sending(sent: approved.text)
        do {
            second = .done(try await CheckEngine(settings: RemoteSettings.current).secondOpinion(approved), sent: approved.text)
        } catch {
            second = .failed("Couldn't get a second opinion. Nothing else was sent. Try again.")
        }
    }

    func cancelSecondOpinion() { second = .none }

    func reset() {
        message = ""
        checkedText = ""
        state = .idle
        second = .none
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
                    header
                    input
                    if model.isIdle { samples }
                    stateView
                    secondOpinionView
                    if !model.isIdle && !model.isChecking {
                        Button {
                            model.reset()
                        } label: {
                            Label("Check another message", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Brand.mist)
                        .controlSize(.large)
                    }
                    if model.isIdle { footer }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .brandScreen()
            #if DEBUG
            // Debug builds keep the bar for the diagnostics button.
            .toolbarBackground(Brand.navy, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            #else
            .toolbar(.hidden, for: .navigationBar)
            // Navy strip behind the status bar, so scrolled text doesn't run under the clock.
            .overlay(alignment: .top) {
                Color.clear.frame(height: 0).background(Brand.navy.ignoresSafeArea(edges: .top))
            }
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDiagnostics = true } label: { Image(systemName: "stethoscope") }
                        .accessibilityLabel("Diagnostics")
                }
                #endif
            }
            .sheet(isPresented: $showDiagnostics) { HelloHybridView() }
            .sheet(isPresented: $model.isReviewing) {
                if case .reviewing(let preview) = model.second {
                    ShieldSheet(preview: preview,
                                onSend: { text in Task { await model.send(text) } },
                                onCancel: { model.cancelSecondOpinion() })
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            WispMark(showsDots: true)
                .frame(width: 44, height: 44)
            Text("Smell Test")
                .font(.largeTitle.bold())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Made-up messages (people, companies and links are invented). Tapping one only fills the box.
    private static let sampleMessages: [(label: String, text: String)] = [
        ("Package fee text", "ParcelPoint: your package is on hold at our depot. Pay the $1.99 redelivery fee within 12 hours at parcelpoint-redelivery.top or it will be returned."),
        ("\u{201C}Hi Mum, new number\u{201D}", "Hi Mum, it's Jess. This is my new number, my old phone broke. Can you message me on WhatsApp here instead? Need to ask you something quickly x"),
        ("Bank sign-in alert", "BrightBank Alert: unusual sign-in detected on your account. Verify your identity now at brightbank-secure-login.net or your account will be locked today."),
    ]

    private var samples: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try a sample")
                .font(.subheadline)
                .foregroundStyle(Brand.mist)
            ForEach(Self.sampleMessages, id: \.label) { sample in
                Button {
                    editorFocused = false
                    model.message = sample.text
                } label: {
                    Text(sample.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Brand.navyRaised, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Puts a made-up example in the box")
            }
        }
    }

    private var footer: some View {
        Label("Checked on your iPhone first", systemImage: "iphone")
            .font(.footnote)
            .foregroundStyle(Brand.mist)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a text, email or link you're unsure about.")
                .font(.headline)
            TextEditor(text: $model.message)
                .focused($editorFocused)
                .frame(minHeight: 140, maxHeight: 260)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Brand.navyRaised, in: .rect(cornerRadius: 12))
                .accessibilityLabel("Message to check")
            HStack {
                // The system Paste button reads the clipboard only when tapped, without a prompt.
                PasteButton(payloadType: String.self) { strings in
                    if let s = strings.first { model.message = s }
                }
                .buttonBorderShape(.capsule)
                .tint(Brand.navyChip)
                Spacer()
                Button {
                    editorFocused = false
                    Task { await model.check() }
                } label: {
                    Label("Check it", systemImage: "checkmark.shield")
                        .frame(minWidth: 120)
                }
                .buttonStyle(BrandProminentButtonStyle())
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
            ResultCard(outcome: outcome, sentText: nil)
            if outcome.escalation != nil, case .none = model.second { secondOpinionButton }
            #if DEBUG
            if outcome.escalation == nil, RemoteSettings.current.secondOpinionEnabled, case .none = model.second {
                Button("Force second opinion (debug builds only)") {
                    Task { await model.prepareSecondOpinion() }
                }
                .font(.footnote)
            }
            #endif
        case .needsSecondOpinion(let reason):
            NoticeCard(icon: "iphone.slash", title: "Not checked on your iPhone", text: reason.explanation + noticeDetail(reason))
            if case .none = model.second { secondOpinionButton }
        case .failed(let text):
            NoticeCard(icon: "exclamationmark.triangle", title: "Couldn't check", text: text)
        }
    }

    @ViewBuilder
    private var secondOpinionButton: some View {
        if RemoteSettings.current.secondOpinionEnabled {
            secondOpinionButtonEnabled
        } else {
            Text("Second opinions are paused right now. Nothing was sent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var secondOpinionButtonEnabled: some View {
        Button {
            Task { await model.prepareSecondOpinion() }
        } label: {
            Label("Get a second opinion", systemImage: "person.2.badge.gearshape")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BrandProminentButtonStyle())
        .accessibilityHint("Shows you exactly what would be sent, with personal details removed, before anything is sent")
    }

    @ViewBuilder
    private var secondOpinionView: some View {
        switch model.second {
        case .none, .reviewing:
            EmptyView()
        case .preparing:
            HStack(spacing: 12) { ProgressView(); Text("Removing personal details on your iPhone…") }
        case .sending:
            HStack(spacing: 12) { ProgressView(); Text("Getting a second opinion…") }
        case .done(let outcome, let sent):
            VStack(alignment: .leading, spacing: 12) {
                Text("Second opinion").font(.title2.bold())
                if case .done(let first) = model.state, first.result.verdict != outcome.result.verdict {
                    comparison(first: first.result.verdict, second: outcome.result.verdict, secondOnDevice: WhereItRan.isOnDevice(outcome.modelVersion))
                }
                ResultCard(outcome: outcome, sentText: sent)
            }
        case .failed(let text):
            NoticeCard(icon: "exclamationmark.triangle", title: "No second opinion", text: text)
        }
    }

    private func comparison(first: Verdict, second: Verdict, secondOnDevice: Bool) -> some View {
        HStack(spacing: 12) {
            verdictPill("Your iPhone", first)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            verdictPill(secondOnDevice ? "Your iPhone (offline)" : "Cloud", second)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your iPhone said \(first.label). The second opinion says \(second.label).")
    }

    private func verdictPill(_ source: String, _ verdict: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source).font(.caption).foregroundStyle(.secondary)
            Text(verdict.label).font(.headline)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
    }

    private func noticeDetail(_ reason: EscalationReason) -> String {
        switch reason {
        case .onDeviceUnavailable:
            " " + (CheckEngine.unavailableReason() ?? "") + " Nothing was sent anywhere."
        case .tooLongForOnDevice:
            RemoteSettings.current.secondOpinionEnabled
                ? " You can get a second opinion with personal details removed, or paste just the part that worries you. Nothing was sent anywhere."
                : " Try pasting just the part that worries you. Nothing was sent anywhere."
        default:
            ""
        }
    }
}
