import XCTest
@testable import CuspShared

final class NodeLatencyProbeTests: XCTestCase {
    func testSortsNodesByProbeResult() {
        let fast = CatalogNode(
            configuration: ShadowsocksConfiguration(
                host: "1.1.1.1",
                port: 443,
                method: "aes-256-gcm",
                password: "a",
                remark: "Fast"
            ),
            sourceID: "source",
            latestLatencyMs: 50,
            lastProbeAt: Date(),
            probeStatus: .success
        )
        let unknown = CatalogNode(
            configuration: ShadowsocksConfiguration(
                host: "2.2.2.2",
                port: 443,
                method: "aes-256-gcm",
                password: "b",
                remark: "Unknown"
            ),
            sourceID: "source",
            latestLatencyMs: nil,
            lastProbeAt: nil,
            probeStatus: .idle
        )
        let timeout = CatalogNode(
            configuration: ShadowsocksConfiguration(
                host: "3.3.3.3",
                port: 443,
                method: "aes-256-gcm",
                password: "c",
                remark: "Timeout"
            ),
            sourceID: "source",
            latestLatencyMs: nil,
            lastProbeAt: Date(),
            probeStatus: .timeout
        )

        let sorted = NodeLatencyProbe.sortForDisplay([timeout, unknown, fast])

        XCTAssertEqual(sorted.map(\.configuration.remark), ["Fast", "Unknown", "Timeout"])
    }
}
