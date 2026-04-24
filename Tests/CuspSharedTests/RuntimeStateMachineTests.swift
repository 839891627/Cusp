import XCTest
@testable import CuspShared

final class RuntimeStateMachineTests: XCTestCase {
    func testAllowsExpectedLifecycleTransitions() {
        var state: ConnectionState = .invalid
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .disconnected))
        XCTAssertEqual(state, .disconnected)
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .connecting))
        XCTAssertEqual(state, .connecting)
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .connected))
        XCTAssertEqual(state, .connected)
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .disconnecting))
        XCTAssertEqual(state, .disconnecting)
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .disconnected))
        XCTAssertEqual(state, .disconnected)
    }

    func testRejectsInvalidTransitionsUnderRapidToggleSequence() {
        var state: ConnectionState = .disconnected
        XCTAssertFalse(RuntimeStateMachine.transition(&state, to: .connected))
        XCTAssertEqual(state, .disconnected)

        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .connecting))
        XCTAssertFalse(RuntimeStateMachine.transition(&state, to: .connecting))
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .disconnecting))
        XCTAssertFalse(RuntimeStateMachine.transition(&state, to: .connected))
        XCTAssertTrue(RuntimeStateMachine.transition(&state, to: .disconnected))
        XCTAssertFalse(RuntimeStateMachine.transition(&state, to: .disconnecting))
        XCTAssertEqual(state, .disconnected)
    }
}
