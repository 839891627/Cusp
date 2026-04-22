import Foundation

public struct CatalogNode: Codable, Equatable, Sendable {
    public enum ProbeStatus: String, Codable, Equatable, Sendable {
        case idle
        case success
        case timeout
        case failure
    }

    public let configuration: ShadowsocksConfiguration
    public let sourceID: String
    public let latestLatencyMs: Int?
    public let lastProbeAt: Date?
    public let probeStatus: ProbeStatus

    public init(
        configuration: ShadowsocksConfiguration,
        sourceID: String,
        latestLatencyMs: Int?,
        lastProbeAt: Date?,
        probeStatus: ProbeStatus
    ) {
        self.configuration = configuration
        self.sourceID = sourceID
        self.latestLatencyMs = latestLatencyMs
        self.lastProbeAt = lastProbeAt
        self.probeStatus = probeStatus
    }

    public var stableID: String {
        configuration.stableID
    }
}
