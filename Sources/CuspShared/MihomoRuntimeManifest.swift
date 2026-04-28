import CryptoKit
import Foundation

public struct MihomoRuntimeManifest: Equatable, Sendable {
    public let name: String
    public let version: String
    public let buildInfo: String
    public let sha256: String
    public let upstreamURL: URL
    public let licenseName: String

    public static let bundled = MihomoRuntimeManifest(
        name: "Mihomo Meta",
        version: "1.19.23",
        buildInfo: "darwin arm64 with go1.26.2 (2026-04-07T22:45:04Z)",
        sha256: "d7dfedd3120c17a7a3e80f6b7d637834ea102776c2d70a1d6e2553467a82db90",
        upstreamURL: URL(string: "https://github.com/MetaCubeX/mihomo")!,
        licenseName: "GNU General Public License v3.0"
    )

    public func validateBinary(at fileURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else {
            return false
        }
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return digest == sha256
    }
}
