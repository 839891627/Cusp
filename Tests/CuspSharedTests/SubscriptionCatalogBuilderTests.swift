import XCTest
@testable import CuspShared

final class SubscriptionCatalogBuilderTests: XCTestCase {
    func testCreatesSubscriptionSourceAndNodesFromRemotePayload() throws {
        let nodes = [
            ShadowsocksConfiguration(
                host: "1.1.1.1",
                port: 443,
                method: "aes-256-gcm",
                password: "a",
                remark: "US 01"
            ),
            ShadowsocksConfiguration(
                host: "2.2.2.2",
                port: 443,
                method: "aes-256-gcm",
                password: "b",
                remark: "JP 01"
            )
        ]

        let catalog = SubscriptionCatalogBuilder.merging(
            existing: SubscriptionCatalog(
                sources: [],
                nodes: [],
                selectedNodeID: nil,
                selectedMode: .rules
            ),
            importName: "Airport Main",
            importURLString: "https://example.com/sub/main",
            configurations: nodes,
            refreshedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(catalog.sources.map(\.name), ["Airport Main"])
        XCTAssertEqual(catalog.nodes.map(\.sourceID), ["airport-main", "airport-main"])
        XCTAssertEqual(catalog.selectedNodeID, nodes.first?.stableID)
    }

    func testRefreshPreservesOtherSources() throws {
        let existing = SubscriptionCatalog(
            sources: [
                SubscriptionSource(
                    id: "airport-main",
                    name: "Airport Main",
                    urlString: "https://example.com/sub/main",
                    isEnabled: true,
                    lastRefreshAt: nil,
                    lastRefreshStatus: .idle,
                    lastErrorMessage: nil
                ),
                SubscriptionSource(
                    id: "backup-line",
                    name: "Backup Line",
                    urlString: "https://example.com/sub/backup",
                    isEnabled: true,
                    lastRefreshAt: nil,
                    lastRefreshStatus: .idle,
                    lastErrorMessage: nil
                )
            ],
            nodes: [
                CatalogNode(
                    configuration: ShadowsocksConfiguration(
                        host: "1.1.1.1",
                        port: 443,
                        method: "aes-256-gcm",
                        password: "a",
                        remark: "US 01"
                    ),
                    sourceID: "airport-main",
                    latestLatencyMs: nil,
                    lastProbeAt: nil,
                    probeStatus: .idle
                ),
                CatalogNode(
                    configuration: ShadowsocksConfiguration(
                        host: "9.9.9.9",
                        port: 443,
                        method: "aes-256-gcm",
                        password: "z",
                        remark: "HK 01"
                    ),
                    sourceID: "backup-line",
                    latestLatencyMs: nil,
                    lastProbeAt: nil,
                    probeStatus: .idle
                )
            ],
            selectedNodeID: nil,
            selectedMode: .rules
        )

        let refreshed = SubscriptionCatalogBuilder.merging(
            existing: existing,
            importName: "Airport Main",
            importURLString: "https://example.com/sub/main",
            configurations: [
                ShadowsocksConfiguration(
                    host: "2.2.2.2",
                    port: 443,
                    method: "aes-256-gcm",
                    password: "b",
                    remark: "JP 01"
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(refreshed.sources.count, 2)
        XCTAssertEqual(refreshed.nodes.filter { $0.sourceID == "backup-line" }.count, 1)
        XCTAssertEqual(refreshed.nodes.filter { $0.sourceID == "airport-main" }.count, 1)
    }

    func testUpdatePreservesExplicitSourceIdentityWhenRenaming() throws {
        let existing = SubscriptionCatalog(
            sources: [
                SubscriptionSource(
                    id: "airport-main",
                    name: "Airport Main",
                    urlString: "https://example.com/sub/main",
                    isEnabled: true,
                    lastRefreshAt: nil,
                    lastRefreshStatus: .idle,
                    lastErrorMessage: nil
                )
            ],
            nodes: [
                CatalogNode(
                    configuration: ShadowsocksConfiguration(
                        host: "1.1.1.1",
                        port: 443,
                        method: "aes-256-gcm",
                        password: "a",
                        remark: "US 01"
                    ),
                    sourceID: "airport-main",
                    latestLatencyMs: nil,
                    lastProbeAt: nil,
                    probeStatus: .idle
                )
            ],
            selectedNodeID: nil,
            selectedMode: .rules
        )

        let updated = SubscriptionCatalogBuilder.merging(
            existing: existing,
            sourceID: "airport-main",
            importName: "Airport Primary",
            importURLString: "https://example.com/sub/primary",
            configurations: [
                ShadowsocksConfiguration(
                    host: "2.2.2.2",
                    port: 443,
                    method: "aes-256-gcm",
                    password: "b",
                    remark: "JP 01"
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(updated.sources.count, 1)
        XCTAssertEqual(updated.sources.first?.id, "airport-main")
        XCTAssertEqual(updated.sources.first?.name, "Airport Primary")
        XCTAssertEqual(updated.sources.first?.urlString, "https://example.com/sub/primary")
        XCTAssertEqual(updated.nodes.map(\.sourceID), ["airport-main"])
    }
}
