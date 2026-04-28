import XCTest
@testable import CuspShared

final class MihomoRuntimeManifestTests: XCTestCase {
    func testBundledManifestPinsVersionSourceLicenseAndChecksum() {
        let manifest = MihomoRuntimeManifest.bundled

        XCTAssertEqual(manifest.name, "Mihomo Meta")
        XCTAssertEqual(manifest.version, "1.19.23")
        XCTAssertEqual(manifest.sha256, "d7dfedd3120c17a7a3e80f6b7d637834ea102776c2d70a1d6e2553467a82db90")
        XCTAssertEqual(manifest.upstreamURL.absoluteString, "https://github.com/MetaCubeX/mihomo")
        XCTAssertFalse(manifest.licenseName.isEmpty)
    }

    func testChecksumValidationRejectsMismatchedDigest() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("mihomo")
        try Data("hello".utf8).write(to: fileURL)

        XCTAssertFalse(MihomoRuntimeManifest.bundled.validateBinary(at: fileURL))
    }
}
