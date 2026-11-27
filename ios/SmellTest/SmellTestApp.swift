import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct SmellTestApp: App {
    /// False when GoogleService-Info.plist hasn't been added (it is never committed).
    private let isFirebaseConfigured: Bool

    init() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            isFirebaseConfigured = false
            return
        }
        // App Check must be set up BEFORE FirebaseApp.configure().
        #if DEBUG
        // Debug provider: prints a token to the Xcode console. Register it in the
        // Firebase console. Never commit or paste that token anywhere.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestFactory())
        #endif
        FirebaseApp.configure()
        RemoteSettings.start()
        isFirebaseConfigured = true
    }

    var body: some Scene {
        WindowGroup {
            LaunchContainer {
                if isFirebaseConfigured {
                    CheckView()
                } else {
                    MissingConfigView()
                }
            }
        }
    }
}

/// App Attest for TestFlight / release builds.
final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

/// Shown instead of crashing when the Firebase config file is missing.
struct MissingConfigView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Firebase isn't set up", systemImage: "gearshape.2")
        } description: {
            Text("Add GoogleService-Info.plist to ios/SmellTest, then run xcodegen and build again. See docs/SETUP.md.")
        }
    }
}
