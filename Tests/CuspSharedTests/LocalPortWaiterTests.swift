import Network
import XCTest
@testable import CuspShared

final class LocalPortWaiterTests: XCTestCase {
    func testWaitsUntilPortStartsListening() async throws {
        let port = NWEndpoint.Port(rawValue: 27864)!
        let listener = try NWListener(using: .tcp, on: port)
        let ready = expectation(description: "listener ready")

        listener.stateUpdateHandler = { state in
            if case .ready = state {
                ready.fulfill()
            }
        }

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
        }

        listener.start(queue: .global())
        await fulfillment(of: [ready], timeout: 2)

        try await LocalPortWaiter.waitUntilListening(
            host: "127.0.0.1",
            port: 27864,
            timeout: .seconds(2)
        )

        listener.cancel()
    }

    func testTimeoutErrorProvidesReadableDescription() {
        let error = LocalPortWaiter.Error.timedOut("127.0.0.1", 1086)

        XCTAssertEqual(
            error.localizedDescription,
            "The local proxy did not start listening on 127.0.0.1:1086 before the startup timeout expired."
        )
    }
}
