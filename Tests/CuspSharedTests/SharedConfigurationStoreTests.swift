import XCTest
@testable import CuspShared

final class SharedConfigurationStoreTests: XCTestCase {
    func testRoundTripsSubscriptionCatalog() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)
        let source = SubscriptionSource(
            id: "source-main",
            name: "Airport Main",
            urlString: "https://example.com/sub/main",
            isEnabled: true,
            lastRefreshAt: Date(timeIntervalSince1970: 100),
            lastRefreshStatus: .success,
            lastErrorMessage: nil
        )
        let node = CatalogNode(
            configuration: ShadowsocksConfiguration(
                host: "1.1.1.1",
                port: 443,
                method: "aes-256-gcm",
                password: "a",
                remark: "US 01"
            ),
            sourceID: source.id,
            latestLatencyMs: 86,
            lastProbeAt: Date(timeIntervalSince1970: 200),
            probeStatus: .success
        )
        let catalog = SubscriptionCatalog(
            sources: [source],
            nodes: [node],
            selectedNodeID: node.stableID,
            selectedMode: .rules
        )

        try store.saveSubscriptionCatalog(catalog)

        XCTAssertEqual(try store.loadSubscriptionCatalog(), catalog)
    }

    func testMigratesLegacyNodeCatalogIntoSubscriptionCatalog() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)
        let legacyNode = ShadowsocksConfiguration(
            host: "2.2.2.2",
            port: 443,
            method: "aes-256-gcm",
            password: "b",
            remark: "Legacy"
        )

        try store.save(legacyNode)

        let catalog = try store.loadSubscriptionCatalog()

        XCTAssertEqual(catalog?.sources.count, 1)
        XCTAssertEqual(catalog?.nodes.first?.configuration, legacyNode)
        XCTAssertEqual(catalog?.selectedMode, .rules)
    }

    func testRoundTripsNodeCatalogWithSelectedNode() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)
        let catalog = NodeCatalog(
            nodes: [
                ShadowsocksConfiguration(
                    host: "1.1.1.1",
                    port: 443,
                    method: "aes-256-gcm",
                    password: "a",
                    remark: "US-1"
                ),
                ShadowsocksConfiguration(
                    host: "2.2.2.2",
                    port: 443,
                    method: "aes-256-gcm",
                    password: "b",
                    remark: "US-2"
                )
            ],
            selectedNodeID: "US-2"
        )

        try store.saveCatalog(catalog)

        XCTAssertEqual(try store.loadCatalog(), catalog)
    }

    func testRoundTripsSharedConfiguration() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)
        let config = ShadowsocksConfiguration(
            host: "1.2.3.4",
            port: 8388,
            method: "chacha20-ietf-poly1305",
            password: "top-secret",
            remark: "Lab"
        )

        try store.save(config)

        XCTAssertEqual(try store.load(), config)
    }

    func testReturnsNilWhenConfigurationMissing() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)

        XCTAssertNil(try store.load())
    }

    func testClearRemovesSavedConfiguration() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)
        let config = ShadowsocksConfiguration(
            host: "8.8.8.8",
            port: 443,
            method: "aes-128-gcm",
            password: "clear-me"
        )

        try store.save(config)
        store.clear()

        XCTAssertNil(try store.load())
    }
}
