import XCTest
@testable import CuspShared

final class MVPReadinessEvaluatorTests: XCTestCase {
    func testMarksProjectBlockedWhenCriticalInputsAreMissing() {
        let report = MVPReadinessEvaluator.report(
            hasConfiguration: false,
            hasBundledBinary: false,
            hasNetworkServices: false,
            proxyPreparationError: "Permission denied"
        )

        XCTAssertFalse(report.isReady)
        XCTAssertEqual(report.blockingItems.map { $0.title }, [
            "Server Configuration",
            "System Proxy Control",
            "Bundled mihomo"
        ])
    }

    func testMarksProjectReadyWhenConfigurationAndRuntimeInputsExist() {
        let report = MVPReadinessEvaluator.report(
            hasConfiguration: true,
            hasBundledBinary: true,
            hasNetworkServices: true,
            proxyPreparationError: nil
        )

        XCTAssertTrue(report.isReady)
        XCTAssertTrue(report.blockingItems.isEmpty)
        XCTAssertEqual(report.statusTitle, "Ready To Trial")
    }
}
