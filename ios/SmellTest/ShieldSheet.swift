import SwiftUI
import SmellTestCore

/// "This is what will be sent." Nothing leaves the phone without the Send tap.
struct ShieldSheet: View {
    let preview: ShieldPreview
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var draft = ""
    @State private var note: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Personal details are removed before anything is sent. This is exactly what will go to the cloud for a second opinion:")
                        .font(.headline)

                    if !preview.namesChecked {
                        Label {
                            Text("Your iPhone couldn't look for names this time. Please read the text below and remove any names or other personal details yourself before sending.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .padding()
                        .background(.orange.opacity(0.15), in: .rect(cornerRadius: 12))
                    }

                    TextEditor(text: $draft)
                        .frame(minHeight: 180)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                        .accessibilityLabel("Text that will be sent. You can edit it.")

                    if !preview.counts.isEmpty {
                        Text("Removed: " + summary(preview.counts))
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text("No personal details were found.").font(.callout).foregroundStyle(.secondary)
                    }

                    if let note {
                        Label(note, systemImage: "info.circle").font(.callout)
                    }

                    Text("You can edit the text before sending.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Before it's sent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }.bold()
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { draft = preview.text }
            .interactiveDismissDisabled()
        }
    }

    private func send() {
        do {
            let approved = try PrivacyShield.approve(shownText: draft, namesChecked: preview.namesChecked)
            onSend(approved.text)
        } catch .stillHasDetails(let again) {
            draft = again.text
            note = "More personal details were removed. Check the text again, then tap Send."
        } catch {
            note = "There's nothing to send."
        }
    }

    private func summary(_ counts: [Redactor.Kind: Int]) -> String {
        Redactor.Kind.allCases.compactMap { kind in
            guard let n = counts[kind], n > 0 else { return nil }
            return "\(n) \(name(kind))\(n == 1 ? "" : "s")"
        }.joined(separator: ", ")
    }

    private func name(_ kind: Redactor.Kind) -> String {
        switch kind {
        case .email: "email address"
        case .link: "link detail"
        case .ssn: "Social Security number"
        case .card: "card number"
        case .phone: "phone number"
        case .address: "street address"
        case .account: "account number"
        case .code: "code"
        case .name: "name"
        }
    }
}
