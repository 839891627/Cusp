import Foundation

public struct SubscriptionUsageInfo: Codable, Equatable, Sendable {
    public let uploadBytes: Int64?
    public let downloadBytes: Int64?
    public let totalBytes: Int64?
    public let expireAt: Date?

    public init(
        uploadBytes: Int64? = nil,
        downloadBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        expireAt: Date? = nil
    ) {
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalBytes = totalBytes
        self.expireAt = expireAt
    }
}

public struct SubscriptionSource: Codable, Equatable, Sendable {
    public enum RefreshStatus: String, Codable, Equatable, Sendable {
        case idle
        case success
        case failure
    }

    public let id: String
    public let name: String
    public let urlString: String
    public let isEnabled: Bool
    public let lastRefreshAt: Date?
    public let lastRefreshStatus: RefreshStatus
    public let lastErrorMessage: String?
    public let usageInfo: SubscriptionUsageInfo?

    public init(
        id: String,
        name: String,
        urlString: String,
        isEnabled: Bool,
        lastRefreshAt: Date?,
        lastRefreshStatus: RefreshStatus,
        lastErrorMessage: String?,
        usageInfo: SubscriptionUsageInfo? = nil
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.isEnabled = isEnabled
        self.lastRefreshAt = lastRefreshAt
        self.lastRefreshStatus = lastRefreshStatus
        self.lastErrorMessage = lastErrorMessage
        self.usageInfo = usageInfo
    }
}
