import UIKit
import SwiftUI
import UniformTypeIdentifiers
import FirebaseCore

/// Entry point for the share sheet. It only ever checks on the iPhone: the extension has no
/// cloud path. A second opinion means opening the app (see docs/DESIGN.md, "Share sheet").
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let firebaseReady = Self.configureFirebase()
        let model = ShareModel(firebaseReady: firebaseReady) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.start(text: await Self.sharedText(from: items)) }
    }

    /// Same config file as the app. No App Check or Remote Config here: nothing leaves the phone.
    private static func configureFirebase() -> Bool {
        if FirebaseApp.app() != nil { return true }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return false }
        FirebaseApp.configure()
        return true
    }

    /// The first plain text in the shared items, or the item's own text.
    private static func sharedText(from items: [NSExtensionItem]) async -> String? {
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
            if let text = item.attributedContentText?.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }
}
