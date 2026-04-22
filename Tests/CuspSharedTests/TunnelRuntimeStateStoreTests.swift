import XCTest
@testable import CuspShared

final class TunnelRuntimeStateStoreTests: XCTestCase {
    func testRoundTripsLastTunnelError() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)

        store.saveLastTunnelError("mihomo failed to bind 1086")

        XCTAssertEqual(store.loadLastTunnelError(), "mihomo failed to bind 1086")
    }

    func testClearRemovesLastTunnelError() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)

        store.saveLastTunnelError("temporary failure")
        store.clearLastTunnelError()

        XCTAssertNil(store.loadLastTunnelError())
    }
}
