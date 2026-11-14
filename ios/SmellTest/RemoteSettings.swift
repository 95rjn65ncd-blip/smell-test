import Foundation
import FirebaseRemoteConfig
import SmellTestCore

/// Loads `Settings` from Firebase Remote Config. Until a fetch succeeds (or when offline),
/// the built-in defaults apply. Values are validated in `Settings.from`.
@MainActor
enum RemoteSettings {
    private(set) static var current: Settings = .defaults

    static func start() {
        let rc = RemoteConfig.remoteConfig()
        let config = RemoteConfigSettings()
        #if DEBUG
        config.minimumFetchInterval = 0
        #else
        config.minimumFetchInterval = 3600
        #endif
        rc.configSettings = config
        apply(rc)  // Last activated values from a previous launch, if any.
        Task {
            _ = try? await rc.fetchAndActivate()
            apply(rc)
        }
    }

    private static func apply(_ rc: RemoteConfig) {
        func value(_ key: String) -> String? {
            let v = rc.configValue(forKey: key)
            return v.source == .remote ? v.stringValue : nil
        }
        current = Settings.from(cloudModel: value(Settings.Key.cloudModel),
                                secondOpinionEnabled: value(Settings.Key.secondOpinionEnabled),
                                minWarningSigns: value(Settings.Key.minWarningSigns),
                                currentPatterns: value(Settings.Key.currentPatterns))
    }
}
