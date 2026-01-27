import CodexBarCore
import Foundation

extension SettingsStore {
    var antigravityUsageSource: AntigravityUsageSource {
        get {
            guard let rawValue = self.configSnapshot.providerConfig(for: .antigravity)?.usageSource else {
                return .auto
            }
            return AntigravityUsageSource(rawValue: rawValue) ?? .auto
        }
        set {
            self.updateProviderConfig(provider: .antigravity) { entry in
                entry.usageSource = newValue.rawValue
            }
            self.logProviderModeChange(provider: .antigravity, field: "usageSource", value: newValue.rawValue)
        }
    }

    var antigravityManualToken: String {
        get { self.configSnapshot.providerConfig(for: .antigravity)?.manualToken ?? "" }
        set {
            self.updateProviderConfig(provider: .antigravity) { entry in
                entry.manualToken = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .antigravity, field: "manualToken", value: newValue)
        }
    }

    var antigravityAccountEmail: String? {
        AntigravityOAuthCredentialsStore.load()?.email
    }

    var antigravityHasCredentials: Bool {
        if let credentials = AntigravityOAuthCredentialsStore.load() {
            return !credentials.accessToken.isEmpty || credentials.isRefreshable
        }
        return false
    }

    func clearAntigravityCredentials() {
        AntigravityOAuthCredentialsStore.clear()
    }
}

extension SettingsStore {
    func antigravitySettingsSnapshot() -> ProviderSettingsSnapshot.AntigravityProviderSettings {
        ProviderSettingsSnapshot.AntigravityProviderSettings(
            usageSource: self.antigravityUsageSource,
            manualToken: self.antigravityManualToken)
    }
}
