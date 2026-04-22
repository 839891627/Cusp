import XCTest
@testable import CuspShared

final class TrialSetupGuideBuilderTests: XCTestCase {
    func testBuildsOrderedSetupStepsForBlockedReadiness() {
        let report = MVPReadinessEvaluator.report(
            hasConfiguration: false,
            hasBundledBinary: false,
            hasNetworkServices: false,
            proxyPreparationError: "No active network services."
        )

        let guide = TrialSetupGuideBuilder.build(from: report)

        XCTAssertFalse(guide.isComplete)
        XCTAssertEqual(guide.steps.map { $0.title }, [
            "Verify Network Services",
            "Bundle mihomo",
            "Import A Node"
        ])
    }

    func testReturnsLaunchGuidanceWhenEverythingIsReady() {
        let report = MVPReadinessEvaluator.report(
            hasConfiguration: true,
            hasBundledBinary: true,
            hasNetworkServices: true,
            proxyPreparationError: nil
        )

        let guide = TrialSetupGuideBuilder.build(from: report)

        XCTAssertTrue(guide.isComplete)
        XCTAssertEqual(guide.steps.count, 1)
        XCTAssertEqual(guide.steps.first?.title, "Run The App")
    }
}
