import Foundation

public struct MVPReadinessItem: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let isPassing: Bool

    public init(title: String, detail: String, isPassing: Bool) {
        self.title = title
        self.detail = detail
        self.isPassing = isPassing
    }
}

public struct MVPReadinessReport: Equatable, Sendable {
    public let statusTitle: String
    public let checks: [MVPReadinessItem]

    public init(statusTitle: String, checks: [MVPReadinessItem]) {
        self.statusTitle = statusTitle
        self.checks = checks
    }

    public var isReady: Bool {
        checks.allSatisfy(\.isPassing)
    }

    public var blockingItems: [MVPReadinessItem] {
        checks.filter { !$0.isPassing }
    }
}

public enum MVPReadinessEvaluator {
    public static func report(
        hasConfiguration: Bool,
        hasBundledBinary: Bool,
        hasNetworkServices: Bool,
        proxyPreparationError: String? = nil
    ) -> MVPReadinessReport {
        let checks = [
            MVPReadinessItem(
                title: "Server Configuration",
                detail: hasConfiguration ? "A valid Shadowsocks node is stored." : "Import and save an ss:// URI before connecting.",
                isPassing: hasConfiguration
            ),
            MVPReadinessItem(
                title: "System Proxy Control",
                detail: proxyPreparationError ?? (
                    hasNetworkServices
                        ? "Enabled macOS network services were detected for proxy switching."
                        : "No enabled macOS network services were detected."
                ),
                isPassing: proxyPreparationError == nil && hasNetworkServices
            ),
            MVPReadinessItem(
                title: "Bundled mihomo",
                detail: hasBundledBinary
                    ? "A local mihomo executable is available for the app runtime."
                    : "Add a real mihomo binary to Resources/mihomo/mihomo and rebuild.",
                isPassing: hasBundledBinary
            )
        ]

        return MVPReadinessReport(
            statusTitle: checks.allSatisfy(\.isPassing) ? "Ready To Trial" : "Setup Required",
            checks: checks
        )
    }
}
