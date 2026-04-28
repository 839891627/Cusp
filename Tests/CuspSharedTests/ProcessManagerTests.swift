import XCTest
@testable import CuspShared

final class ProcessManagerTests: XCTestCase {
    func testThrowsWhenBinaryMissing() throws {
        let manager = ProcessManager()
        let missingURL = URL(fileURLWithPath: "/tmp/cusp-tests/missing-mihomo")

        XCTAssertThrowsError(
            try manager.launch(
                executableURL: missingURL,
                arguments: [],
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(error as? ProcessManager.Error, .binaryNotFound(missingURL))
        }
    }

    func testLaunchesAndTerminatesProcess() throws {
        let manager = ProcessManager()
        let process = try manager.launch(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 30"],
            environment: [:]
        )

        XCTAssertTrue(process.isRunning)

        manager.cleanup()

        XCTAssertFalse(process.isRunning)
    }

    func testCapturesStderrForDiagnostics() throws {
        let manager = ProcessManager()
        _ = try manager.launch(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo runtime-boom >&2; sleep 1"],
            environment: [:]
        )

        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertTrue(manager.diagnosticSummary().contains("runtime-boom"))

        manager.cleanup()
    }
}
