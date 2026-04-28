import XCTest
@testable import CuspShared

final class RuntimeStateStoreTests: XCTestCase {
    func testRoundTripsLastRuntimeError() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)

        store.saveLastRuntimeError("mihomo failed to bind 1086")

        XCTAssertEqual(store.loadLastRuntimeError(), "mihomo failed to bind 1086")
    }

    func testClearRemovesLastRuntimeError() throws {
        let suiteName = "CuspTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedConfigurationStore(userDefaults: defaults)

        store.saveLastRuntimeError("temporary failure")
        store.clearLastRuntimeError()

        XCTAssertNil(store.loadLastRuntimeError())
    }
}
