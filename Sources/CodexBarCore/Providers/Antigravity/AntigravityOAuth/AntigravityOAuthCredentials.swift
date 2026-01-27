import Foundation
#if os(macOS)
import Security
#endif

public struct AntigravityOAuthCredentials: Sendable, Codable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let email: String?
    public let scopes: [String]

    public init(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        email: String?,
        scopes: [String] = AntigravityOAuthConfig.scopes)
    {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.email = email
        self.scopes = scopes
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    public var expiresIn: TimeInterval? {
        guard let expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    public var isRefreshable: Bool {
        guard let refreshToken else { return false }
        return !refreshToken.isEmpty
    }

    public var needsRefresh: Bool {
        guard let expiresAt else { return self.isRefreshable }
        let bufferTime: TimeInterval = 5 * 60
        return expiresAt.timeIntervalSinceNow < bufferTime
    }
}

public enum AntigravityOAuthConfig {
    public static let clientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    public static let clientSecret = "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"
    public static let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs",
    ]
    public static let tokenURL = "https://oauth2.googleapis.com/token"
    public static let authURL = "https://accounts.google.com/o/oauth2/auth"
    public static let userInfoURL = "https://www.googleapis.com/oauth2/v2/userinfo"
    public static let callbackHost = "127.0.0.1"
    public static let callbackPortStart = 11451
    public static let callbackPortRange = 100
}

public enum AntigravityOAuthCredentialsError: LocalizedError, Sendable {
    case notFound
    case decodeFailed(String)
    case missingAccessToken
    case refreshFailed(String)
    case invalidGrant
    case networkError(String)
    case keychainError(Int)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Antigravity credentials not found. Authorize or import from Antigravity app."
        case let .decodeFailed(message):
            "Failed to decode Antigravity credentials: \(message)"
        case .missingAccessToken:
            "Antigravity access token is missing."
        case let .refreshFailed(message):
            "Failed to refresh Antigravity token: \(message)"
        case .invalidGrant:
            "Antigravity refresh token is invalid. Please re-authorize."
        case let .networkError(message):
            "Antigravity network error: \(message)"
        case let .keychainError(status):
            "Antigravity keychain error: \(status)"
        }
    }
}

public enum AntigravityOAuthCredentialsStore {
    private static let cacheKey = KeychainCacheStore.Key.oauth(provider: .antigravity)
    private static let log = CodexBarLog.logger(LogCategories.antigravity)
    public static let environmentTokenKey = "CODEXBAR_ANTIGRAVITY_TOKEN"

    struct CacheEntry: Codable, Sendable {
        let credentials: AntigravityOAuthCredentials
        let storedAt: Date
    }

    private nonisolated(unsafe) static var cachedCredentials: AntigravityOAuthCredentials?
    private nonisolated(unsafe) static var cacheTimestamp: Date?
    private static let memoryCacheValidityDuration: TimeInterval = 1800

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> AntigravityOAuthCredentials?
    {
        if let credentials = self.loadFromEnvironment(environment) {
            return credentials
        }

        if let cached = self.cachedCredentials,
           let timestamp = self.cacheTimestamp,
           Date().timeIntervalSince(timestamp) < self.memoryCacheValidityDuration,
           !cached.isExpired
        {
            return cached
        }

        switch KeychainCacheStore.load(key: self.cacheKey, as: CacheEntry.self) {
        case let .found(entry):
            if entry.credentials.isExpired, !entry.credentials.isRefreshable {
                self.log.debug("Antigravity cached credentials expired and not refreshable")
                return entry.credentials
            }
            self.cachedCredentials = entry.credentials
            self.cacheTimestamp = Date()
            return entry.credentials
        case .invalid:
            KeychainCacheStore.clear(key: self.cacheKey)
            return nil
        case .missing:
            return nil
        }
    }

    public static func save(_ credentials: AntigravityOAuthCredentials) {
        let entry = CacheEntry(credentials: credentials, storedAt: Date())
        KeychainCacheStore.store(key: self.cacheKey, entry: entry)
        self.cachedCredentials = credentials
        self.cacheTimestamp = Date()
        self.log.info("Antigravity credentials saved", metadata: [
            "email": credentials.email ?? "unknown",
            "hasRefreshToken": "\(credentials.isRefreshable)",
        ])
    }

    public static func clear() {
        KeychainCacheStore.clear(key: self.cacheKey)
        self.cachedCredentials = nil
        self.cacheTimestamp = nil
        self.log.info("Antigravity credentials cleared")
    }

    public static func invalidateCache() {
        self.cachedCredentials = nil
        self.cacheTimestamp = nil
    }

    private static func loadFromEnvironment(_ environment: [String: String]) -> AntigravityOAuthCredentials? {
        guard let token = environment[self.environmentTokenKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            return nil
        }

        return AntigravityOAuthCredentials(
            accessToken: token,
            refreshToken: nil,
            expiresAt: Date.distantFuture,
            email: nil,
            scopes: AntigravityOAuthConfig.scopes)
    }
}

extension AntigravityOAuthCredentialsStore {
    public static func parseManualToken(_ input: String) -> AntigravityOAuthCredentials? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let jsonCredentials = self.parseJSONInput(trimmed) {
            return jsonCredentials
        }

        if trimmed.hasPrefix("ya29.") || trimmed.hasPrefix("1//") {
            let isRefreshToken = trimmed.hasPrefix("1//")
            if isRefreshToken {
                return AntigravityOAuthCredentials(
                    accessToken: "",
                    refreshToken: trimmed,
                    expiresAt: nil,
                    email: nil,
                    scopes: AntigravityOAuthConfig.scopes)
            } else {
                return AntigravityOAuthCredentials(
                    accessToken: trimmed,
                    refreshToken: nil,
                    expiresAt: nil,
                    email: nil,
                    scopes: AntigravityOAuthConfig.scopes)
            }
        }

        return nil
    }

    private static func parseJSONInput(_ input: String) -> AntigravityOAuthCredentials? {
        guard let data = input.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let apiKey = (json["apiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = (json["accessToken"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = (json["refreshToken"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (json["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let token = apiKey ?? accessToken
        guard let token, !token.isEmpty else { return nil }

        var expiresAt: Date?
        if let expiresAtString = json["expiresAt"] as? String {
            expiresAt = ISO8601DateFormatter().date(from: expiresAtString)
        } else if let expiresAtMillis = json["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: expiresAtMillis / 1000.0)
        }

        return AntigravityOAuthCredentials(
            accessToken: token,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            email: email,
            scopes: AntigravityOAuthConfig.scopes)
    }
}
