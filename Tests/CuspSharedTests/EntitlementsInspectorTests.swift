import Foundation
import XCTest
@testable import CuspShared

final class EntitlementsInspectorTests: XCTestCase {
    func testReadsAppGroupAndPacketTunnelCapability() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("CuspTunnel.entitlements")
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.app-groups</key>
            <array>
                <string>group.dev.cusp</string>
            </array>
            <key>com.apple.developer.networking.networkextension</key>
            <array>
                <string>packet-tunnel-provider</string>
            </array>
        </dict>
        </plist>
        """
        try plist.write(to: fileURL, atomically: true, encoding: .utf8)

        let entitlements = try EntitlementsInspector.load(from: fileURL)

        XCTAssertEqual(entitlements.appGroups, ["group.dev.cusp"])
        XCTAssertTrue(entitlements.supportsPacketTunnel)
    }

    func testReturnsEmptyEntitlementsWhenFileMissing() throws {
        let entitlements = try EntitlementsInspector.load(
            from: URL(fileURLWithPath: "/tmp/cusp-tests/missing.entitlements")
        )

        XCTAssertTrue(entitlements.appGroups.isEmpty)
        XCTAssertFalse(entitlements.supportsPacketTunnel)
    }
}
