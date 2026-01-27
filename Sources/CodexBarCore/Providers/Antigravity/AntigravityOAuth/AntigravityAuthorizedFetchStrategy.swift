import Foundation

public struct AntigravityAuthorizedFetchStrategy: ProviderFetchStrategy {
    public let id: String = "antigravity.authorized"
    public let kind: ProviderFetchKind = .oauth

    private static let log = CodexBarLog.logger(LogCategories.antigravity)

    public init() {}

    public func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        if let credentials = AntigravityOAuthCredentialsStore.load() {
            if !credentials.accessToken.isEmpty { return true }
            if credentials.isRefreshable { return true }
        }

        if let manualToken = context.settings?.antigravityManualToken,
           !manualToken.isEmpty
        {
            return true
        }

        return false
    }

    public func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let credentials = try await self.resolveCredentials(context: context)

        let accessToken: String
        if credentials.needsRefresh, credentials.isRefreshable {
            Self.log.info("Antigravity credentials need refresh")
            let refreshed = try await self.refreshCredentials(credentials)
            accessToken = refreshed.accessToken
        } else if credentials.accessToken.isEmpty, credentials.isRefreshable {
            Self.log.info("Antigravity credentials have no access token, refreshing")
            let refreshed = try await self.refreshCredentials(credentials)
            accessToken = refreshed.accessToken
        } else {
            accessToken = credentials.accessToken
        }

        let quota = try await AntigravityCloudCodeClient.fetchQuota(accessToken: accessToken)
        let snapshot = AntigravityStatusSnapshot(
            modelQuotas: quota.models,
            accountEmail: credentials.email ?? quota.email,
            accountPlan: nil)

        let usage = try snapshot.toUsageSnapshot()
        return self.makeResult(usage: usage, sourceLabel: "authorized")
    }

    public func shouldFallback(on error: Error, context _: ProviderFetchContext) -> Bool {
        if let oauthError = error as? AntigravityOAuthCredentialsError {
            switch oauthError {
            case .invalidGrant:
                return true
            case .notFound:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func resolveCredentials(context: ProviderFetchContext) async throws -> AntigravityOAuthCredentials {
        if let cached = AntigravityOAuthCredentialsStore.load() {
            return cached
        }

        if let manualToken = context.settings?.antigravityManualToken,
           !manualToken.isEmpty
        {
            if let parsed = AntigravityOAuthCredentialsStore.parseManualToken(manualToken) {
                if parsed.isRefreshable, parsed.accessToken.isEmpty {
                    let refreshed = try await AntigravityTokenRefresher.buildCredentialsFromRefreshToken(
                        refreshToken: parsed.refreshToken!)
                    AntigravityOAuthCredentialsStore.save(refreshed)
                    return refreshed
                }
                return parsed
            }
        }

        if AntigravityLocalImporter.isAvailable() {
            let localInfo = try await AntigravityLocalImporter.importCredentials()
            if let refreshToken = localInfo.refreshToken, !refreshToken.isEmpty {
                let credentials = try await AntigravityTokenRefresher.buildCredentialsFromRefreshToken(
                    refreshToken: refreshToken,
                    fallbackEmail: localInfo.email)
                AntigravityOAuthCredentialsStore.save(credentials)
                return credentials
            }
            if let accessToken = localInfo.accessToken, !accessToken.isEmpty {
                let credentials = AntigravityOAuthCredentials(
                    accessToken: accessToken,
                    refreshToken: nil,
                    expiresAt: nil,
                    email: localInfo.email,
                    scopes: AntigravityOAuthConfig.scopes)
                AntigravityOAuthCredentialsStore.save(credentials)
                return credentials
            }
        }

        throw AntigravityOAuthCredentialsError.notFound
    }

    private func refreshCredentials(_ credentials: AntigravityOAuthCredentials) async throws -> AntigravityOAuthCredentials {
        guard let refreshToken = credentials.refreshToken else {
            throw AntigravityOAuthCredentialsError.invalidGrant
        }

        let refreshed = try await AntigravityTokenRefresher.buildCredentialsFromRefreshToken(
            refreshToken: refreshToken,
            fallbackEmail: credentials.email)
        AntigravityOAuthCredentialsStore.save(refreshed)
        return refreshed
    }
}
