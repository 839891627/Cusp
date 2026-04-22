import XCTest
@testable import CuspShared

final class ProxyStartupMonitorTests: XCTestCase {
    func testThrowsProcessExitedWithDiagnosticsBeforeTimeout() {
        XCTAssertThrowsError(
            try ProxyStartupMonitor.waitUntilReady(
                host: "127.0.0.1",
                port: 1086,
                timeoutInterval: 1,
                pollInterval: 0.01,
                isListening: { false },
                isProcessRunning: { false },
                diagnostics: { "MMDB invalid, remove and download" }
            )
        ) { error in
            XCTAssertEqual(
                error as? ProxyStartupMonitor.Error,
                .processExited("MMDB invalid, remove and download")
            )
        }
    }

    func testThrowsTimedOutWithDiagnosticsWhenProcessStaysAlive() {
        XCTAssertThrowsError(
            try ProxyStartupMonitor.waitUntilReady(
                host: "127.0.0.1",
                port: 1086,
                timeoutInterval: 0.05,
                pollInterval: 0.01,
                isListening: { false },
                isProcessRunning: { true },
                diagnostics: { "Still warming geodata" }
            )
        ) { error in
            XCTAssertEqual(
                error as? ProxyStartupMonitor.Error,
                .timedOut("127.0.0.1", 1086, "Still warming geodata")
            )
        }
    }

    func testReturnsWhenPortBecomesReadyBeforeTimeout() throws {
        var attempts = 0

        XCTAssertNoThrow(
            try ProxyStartupMonitor.waitUntilReady(
                host: "127.0.0.1",
                port: 1086,
                timeoutInterval: 0.2,
                pollInterval: 0.01,
                isListening: {
                    attempts += 1
                    return attempts >= 3
                },
                isProcessRunning: { true },
                diagnostics: { "" }
            )
        )
    }
}
