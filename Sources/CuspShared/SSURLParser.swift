import Foundation

public enum SSURLParser {
    public enum Error: Swift.Error, Equatable {
        case invalidScheme
        case invalidPayload
        case invalidServer
    }

    public static func parse(_ uri: String) throws -> ShadowsocksConfiguration {
        guard uri.hasPrefix("ss://") else {
            throw Error.invalidScheme
        }

        let payload = String(uri.dropFirst("ss://".count))
        let pieces = payload.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let encodedCore = String(pieces[0])
        let remark = pieces.count > 1 ? String(pieces[1]).removingPercentEncoding ?? String(pieces[1]) : nil

        let decodedCore = try decodeCore(encodedCore)

        let segments = decodedCore.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard segments.count == 2 else {
            throw Error.invalidPayload
        }

        let credentials = segments[0].split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard credentials.count == 2 else {
            throw Error.invalidPayload
        }

        let server = segments[1].split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard server.count == 2, let port = Int(server[1]) else {
            throw Error.invalidServer
        }

        return ShadowsocksConfiguration(
            host: String(server[0]),
            port: port,
            method: String(credentials[0]),
            password: String(credentials[1]),
            remark: remark
        )
    }

    private static func decodeCore(_ encodedCore: String) throws -> String {
        if let data = Data(base64URLEncoded: encodedCore),
           let raw = String(data: data, encoding: .utf8),
           raw.contains("@"),
           raw.contains(":") {
            return raw
        }

        let segments = encodedCore.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard segments.count == 2 else {
            throw Error.invalidPayload
        }

        let encodedUserInfo = String(segments[0])
        let server = String(segments[1])

        guard let data = Data(base64URLEncoded: encodedUserInfo),
              let userInfo = String(data: data, encoding: .utf8),
              userInfo.contains(":") else {
            throw Error.invalidPayload
        }

        return "\(userInfo)@\(server)"
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - normalized.count % 4) % 4
        self.init(base64Encoded: normalized + String(repeating: "=", count: padding))
    }
}
