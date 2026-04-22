import XCTest
@testable import CuspShared

final class NetworkServiceParserTests: XCTestCase {
    func testParsesEnabledNetworkServices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        Wi-Fi
        Ethernet
        *iPhone USB
        Thunderbolt Bridge
        """

        XCTAssertEqual(
            NetworkServiceParser.parseEnabledServices(from: output),
            ["Wi-Fi", "Ethernet", "Thunderbolt Bridge"]
        )
    }
}
