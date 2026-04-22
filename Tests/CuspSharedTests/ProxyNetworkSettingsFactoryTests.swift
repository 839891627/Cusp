import NetworkExtension
import XCTest
@testable import CuspShared

final class ProxyNetworkSettingsFactoryTests: XCTestCase {
    func testBuildsLoopbackProxySettings() {
        let settings = ProxyNetworkSettingsFactory.makeProxySettings(localHTTPPort: 1086)

        XCTAssertEqual(settings.tunnelRemoteAddress, "127.0.0.1")
        XCTAssertEqual(settings.ipv4Settings?.addresses, ["192.0.2.1"])
        XCTAssertEqual(settings.ipv4Settings?.subnetMasks, ["255.255.255.255"])
        XCTAssertEqual(settings.proxySettings?.httpEnabled, true)
        XCTAssertEqual(settings.proxySettings?.httpsEnabled, true)
        XCTAssertEqual(settings.proxySettings?.httpServer?.address, "127.0.0.1")
        XCTAssertEqual(settings.proxySettings?.httpServer?.port, 1086)
        XCTAssertEqual(settings.proxySettings?.httpsServer?.address, "127.0.0.1")
        XCTAssertEqual(settings.proxySettings?.httpsServer?.port, 1086)
    }
}
