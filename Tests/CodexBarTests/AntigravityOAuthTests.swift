import Foundation
import Testing
@testable import CodexBarCore

@Suite("AntigravityOAuthCredentials")
struct AntigravityOAuthCredentialsTests {
    @Test("Credentials are not expired when expiresAt is in the future")
    func test_credentialsNotExpired() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: Date().addingTimeInterval(3600),
            email: "test@example.com")
        #expect(!creds.isExpired)
    }

    @Test("Credentials are expired when expiresAt is in the past")
    func test_credentialsExpired() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: Date().addingTimeInterval(-3600),
            email: "test@example.com")
        #expect(creds.isExpired)
    }

    @Test("Credentials with nil expiresAt are not expired")
    func test_credentialsNilExpiresAtNotExpired() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: nil,
            email: "test@example.com")
        #expect(!creds.isExpired)
    }

    @Test("Credentials are refreshable when refresh token is present")
    func test_credentialsIsRefreshable() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: nil,
            email: nil)
        #expect(creds.isRefreshable)
    }

    @Test("Credentials are not refreshable when refresh token is nil")
    func test_credentialsNotRefreshableNil() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: nil,
            expiresAt: nil,
            email: nil)
        #expect(!creds.isRefreshable)
    }

    @Test("Credentials are not refreshable when refresh token is empty")
    func test_credentialsNotRefreshableEmpty() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "",
            expiresAt: nil,
            email: nil)
        #expect(!creds.isRefreshable)
    }

    @Test("Credentials need refresh when close to expiry")
    func test_credentialsNeedRefresh() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: Date().addingTimeInterval(120),
            email: nil)
        #expect(creds.needsRefresh)
    }

    @Test("Credentials don't need refresh when not close to expiry")
    func test_credentialsDontNeedRefresh() {
        let creds = AntigravityOAuthCredentials(
            accessToken: "ya29.test",
            refreshToken: "1//refresh",
            expiresAt: Date().addingTimeInterval(3600),
            email: nil)
        #expect(!creds.needsRefresh)
    }
}

@Suite("AntigravityManualTokenParsing")
struct AntigravityManualTokenParsingTests {
    @Test("Parses access token starting with ya29.")
    func test_parseAccessToken() {
        let token = "ya29.a0ARrdaM..."
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(token)
        #expect(creds != nil)
        #expect(creds?.accessToken == token)
        #expect(creds?.refreshToken == nil)
    }

    @Test("Parses refresh token starting with 1//")
    func test_parseRefreshToken() {
        let token = "1//0gXyz..."
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(token)
        #expect(creds != nil)
        #expect(creds?.accessToken.isEmpty == true)
        #expect(creds?.refreshToken == token)
    }

    @Test("Parses JSON with apiKey")
    func test_parseJSONWithApiKey() {
        let json = """
        {"apiKey": "ya29.test", "email": "test@example.com"}
        """
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(json)
        #expect(creds != nil)
        #expect(creds?.accessToken == "ya29.test")
        #expect(creds?.email == "test@example.com")
    }

    @Test("Parses JSON with accessToken")
    func test_parseJSONWithAccessToken() {
        let json = """
        {"accessToken": "ya29.test", "refreshToken": "1//refresh"}
        """
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(json)
        #expect(creds != nil)
        #expect(creds?.accessToken == "ya29.test")
        #expect(creds?.refreshToken == "1//refresh")
    }

    @Test("Parses JSON with expiresAt as string")
    func test_parseJSONWithExpiresAtString() {
        let json = """
        {"apiKey": "ya29.test", "expiresAt": "2025-01-01T00:00:00Z"}
        """
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(json)
        #expect(creds != nil)
        #expect(creds?.expiresAt != nil)
    }

    @Test("Parses JSON with expiresAt as milliseconds")
    func test_parseJSONWithExpiresAtMillis() {
        let json = """
        {"apiKey": "ya29.test", "expiresAt": 1735689600000}
        """
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(json)
        #expect(creds != nil)
        #expect(creds?.expiresAt != nil)
    }

    @Test("Returns nil for empty input")
    func test_parseEmptyInput() {
        let creds = AntigravityOAuthCredentialsStore.parseManualToken("")
        #expect(creds == nil)
    }

    @Test("Returns nil for whitespace-only input")
    func test_parseWhitespaceOnlyInput() {
        let creds = AntigravityOAuthCredentialsStore.parseManualToken("   \n\t  ")
        #expect(creds == nil)
    }

    @Test("Returns nil for invalid token format")
    func test_parseInvalidTokenFormat() {
        let creds = AntigravityOAuthCredentialsStore.parseManualToken("not-a-valid-token")
        #expect(creds == nil)
    }

    @Test("Returns nil for JSON without apiKey or accessToken")
    func test_parseJSONWithoutToken() {
        let json = """
        {"email": "test@example.com"}
        """
        let creds = AntigravityOAuthCredentialsStore.parseManualToken(json)
        #expect(creds == nil)
    }
}

@Suite("AntigravityUsageSource")
struct AntigravityUsageSourceTests {
    @Test("UsageSource has expected cases")
    func test_usageSourceCases() {
        let allCases = AntigravityUsageSource.allCases
        #expect(allCases.contains(.auto))
        #expect(allCases.contains(.authorized))
        #expect(allCases.contains(.local))
        #expect(allCases.count == 3)
    }

    @Test("UsageSource rawValue matches expected strings")
    func test_usageSourceRawValues() {
        #expect(AntigravityUsageSource.auto.rawValue == "auto")
        #expect(AntigravityUsageSource.authorized.rawValue == "authorized")
        #expect(AntigravityUsageSource.local.rawValue == "local")
    }

    @Test("UsageSource can be initialized from rawValue")
    func test_usageSourceFromRawValue() {
        #expect(AntigravityUsageSource(rawValue: "auto") == .auto)
        #expect(AntigravityUsageSource(rawValue: "authorized") == .authorized)
        #expect(AntigravityUsageSource(rawValue: "local") == .local)
        #expect(AntigravityUsageSource(rawValue: "invalid") == nil)
    }
}
