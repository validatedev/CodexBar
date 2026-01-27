import Foundation

public enum AntigravityUsageSource: String, CaseIterable, Sendable, Codable {
    case auto
    case authorized
    case local

    public var displayName: String {
        switch self {
        case .auto:
            "Auto"
        case .authorized:
            "Authorized (OAuth)"
        case .local:
            "Local Server"
        }
    }

    public var description: String {
        switch self {
        case .auto:
            "Use authorized credentials if available, fallback to local server"
        case .authorized:
            "Use OAuth credentials to fetch quota from Cloud Code API"
        case .local:
            "Use local Antigravity language server"
        }
    }
}
