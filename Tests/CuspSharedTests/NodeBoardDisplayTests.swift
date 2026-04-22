import XCTest
@testable import CuspShared

final class NodeBoardDisplayTests: XCTestCase {
    func testBuildsCurrentViewUsingFiltersSearchAndLatencySorting() {
        let sources = [
            SubscriptionSource(
                id: "alpha",
                name: "Alpha",
                urlString: "https://example.com/a",
                isEnabled: true,
                lastRefreshAt: nil,
                lastRefreshStatus: .success,
                lastErrorMessage: nil
            ),
            SubscriptionSource(
                id: "beta",
                name: "Beta",
                urlString: "https://example.com/b",
                isEnabled: false,
                lastRefreshAt: nil,
                lastRefreshStatus: .success,
                lastErrorMessage: nil
            )
        ]

        let slowUS = makeNode(sourceID: "alpha", host: "1.1.1.1", remark: "US Slow", latency: 220, status: .success)
        let idleUS = makeNode(sourceID: "alpha", host: "2.2.2.2", remark: "US Idle", latency: nil, status: .idle)
        let fastUS = makeNode(sourceID: "alpha", host: "3.3.3.3", remark: "US Fast", latency: 80, status: .success)
        let fastJP = makeNode(sourceID: "alpha", host: "4.4.4.4", remark: "JP Fast", latency: 60, status: .success)
        let disabledUS = makeNode(sourceID: "beta", host: "5.5.5.5", remark: "US Disabled", latency: 40, status: .success)

        let currentView = NodeBoardDisplay.currentViewNodes(
            from: [slowUS, idleUS, fastUS, fastJP, disabledUS],
            sources: sources,
            selectedSourceFilterID: "alpha",
            searchQuery: "us",
            sortMode: .latency
        )

        XCTAssertEqual(
            currentView.map(\.configuration.remark),
            ["US Fast", "US Slow", "US Idle"]
        )
    }

    func testKeepsCurrentViewOrderWhenLatencySortingDisabled() {
        let sources = [
            SubscriptionSource(
                id: "alpha",
                name: "Alpha",
                urlString: "https://example.com/a",
                isEnabled: true,
                lastRefreshAt: nil,
                lastRefreshStatus: .success,
                lastErrorMessage: nil
            )
        ]

        let slowUS = makeNode(sourceID: "alpha", host: "1.1.1.1", remark: "US Slow", latency: 220, status: .success)
        let idleUS = makeNode(sourceID: "alpha", host: "2.2.2.2", remark: "US Idle", latency: nil, status: .idle)
        let fastUS = makeNode(sourceID: "alpha", host: "3.3.3.3", remark: "US Fast", latency: 80, status: .success)

        let currentView = NodeBoardDisplay.currentViewNodes(
            from: [slowUS, idleUS, fastUS],
            sources: sources,
            selectedSourceFilterID: nil,
            searchQuery: "us",
            sortMode: .manual
        )

        XCTAssertEqual(
            currentView.map(\.configuration.remark),
            ["US Slow", "US Idle", "US Fast"]
        )
    }

    private func makeNode(
        sourceID: String,
        host: String,
        remark: String,
        latency: Int?,
        status: CatalogNode.ProbeStatus
    ) -> CatalogNode {
        CatalogNode(
            configuration: ShadowsocksConfiguration(
                host: host,
                port: 443,
                method: "aes-256-gcm",
                password: "secret",
                remark: remark
            ),
            sourceID: sourceID,
            latestLatencyMs: latency,
            lastProbeAt: nil,
            probeStatus: status
        )
    }

    func testSortsByNodeNameWhenNameModeSelected() {
        let sources = [
            SubscriptionSource(
                id: "alpha",
                name: "Alpha",
                urlString: "https://example.com/a",
                isEnabled: true,
                lastRefreshAt: nil,
                lastRefreshStatus: .success,
                lastErrorMessage: nil
            )
        ]
        let n1 = makeNode(sourceID: "alpha", host: "3.3.3.3", remark: "Tokyo", latency: nil, status: .idle)
        let n2 = makeNode(sourceID: "alpha", host: "1.1.1.1", remark: "Amsterdam", latency: nil, status: .idle)
        let n3 = makeNode(sourceID: "alpha", host: "2.2.2.2", remark: "Berlin", latency: nil, status: .idle)

        let currentView = NodeBoardDisplay.currentViewNodes(
            from: [n1, n2, n3],
            sources: sources,
            selectedSourceFilterID: nil,
            searchQuery: "",
            sortMode: .name
        )

        XCTAssertEqual(currentView.map(\.configuration.remark), ["Amsterdam", "Berlin", "Tokyo"])
    }
}
