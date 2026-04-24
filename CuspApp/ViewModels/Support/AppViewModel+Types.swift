import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
}

enum SubscriptionRefreshInterval: String, CaseIterable, Identifiable, Sendable {
    case manual
    case hourly
    case daily
    case weekly

    var id: String { rawValue }

    var secondsInterval: TimeInterval? {
        switch self {
        case .manual:
            return nil
        case .hourly:
            return 60 * 60
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        }
    }
}

enum RuntimeFSMLogAggregationWindow: String, CaseIterable, Identifiable, Sendable {
    case off
    case threeSeconds
    case fiveSeconds
    case tenSeconds

    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .threeSeconds:
            return 3
        case .fiveSeconds:
            return 5
        case .tenSeconds:
            return 10
        }
    }
}

enum RuleTemplateKind: String, CaseIterable, Identifiable, Sendable {
    case smartCN
    case aiAndGlobal
    case proxyFirst

    var id: String { rawValue }
}

enum StrategyGroupPolicy: String, CaseIterable, Identifiable, Sendable {
    case manual
    case fastest
    case fallback

    var id: String { rawValue }
}

enum CustomStrategyGroupType: String, CaseIterable, Identifiable, Codable, Sendable {
    case manual
    case smart
    case urlTest
    case fallback
    case loadBalance

    var id: String { rawValue }
}

struct CustomStrategyGroup: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let type: CustomStrategyGroupType
    let sourceID: String
    let preferredNodeID: String?
    let testURL: String?
    let intervalSeconds: Int?
}

enum StrategyGroupSwitchSource: String, Codable, Sendable {
    case manualApply
    case autoFailover
}

struct StrategyGroupSwitchRecord: Codable, Equatable, Sendable {
    let switchedAt: Date
    let source: StrategyGroupSwitchSource
}

enum AppTextKey: Sendable {
    case appSubtitle
    case currentNode
    case connect
    case disconnect
    case settings
    case settingsSubtitle
    case runtimeStatus
    case connection
    case readiness
    case savedNodes
    case actions
    case actionsSubtitle
    case clearSavedConfig
    case language
    case languageSubtitle
    case english
    case simplifiedChinese
    case overview
    case overviewSubtitle
    case nodes
    case nodesSubtitle
    case subscriptions
    case subscriptionsSubtitle
    case logs
    case logsSubtitle
}

enum AppLogLevel: String, CaseIterable, Sendable, Hashable {
    case info
    case success
    case error
}

struct AppLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppLogLevel
    let category: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: AppLogLevel,
        category: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

struct TrafficSample: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        uploadBytesPerSecond: Double,
        downloadBytesPerSecond: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.downloadBytesPerSecond = downloadBytesPerSecond
    }
}

struct NetworkByteSnapshot {
    let timestamp: Date
    let uploadBytes: UInt64
    let downloadBytes: UInt64
}

enum ProcessRoutingType: Equatable, Hashable, Sendable {
    case direct
    case proxy(String)
    case reject
    case unknown
}

struct ProcessTrafficEntry: Identifiable, Equatable, Sendable {
    let routing: ProcessRoutingType
    let uploadBytes: UInt64
    let downloadBytes: UInt64
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double
    let activeConnections: Int
    let metadataSummary: String?

    var id: String { Self.snapshotKey(routing: routing) }

    var totalBytes: UInt64 {
        uploadBytes + downloadBytes
    }

    private var routingIdentifier: String {
        switch routing {
        case .direct:
            return "direct"
        case .proxy(let chain):
            return "proxy:\(chain)"
        case .reject:
            return "reject"
        case .unknown:
            return "unknown"
        }
    }

    static func snapshotKey(routing: ProcessRoutingType) -> String {
        switch routing {
        case .direct:
            return "route:direct"
        case .proxy(let chain):
            return "route:proxy:\(chain)"
        case .reject:
            return "route:reject"
        case .unknown:
            return "route:unknown"
        }
    }
}

