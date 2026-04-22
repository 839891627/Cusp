import Foundation

public struct ShadowsocksConfiguration: Codable, Equatable, Sendable {
    public enum ProxyProtocol: String, Codable, Equatable, Sendable {
        case shadowsocks = "ss"
        case vless
        case vmess
        case trojan
    }

    public let host: String
    public let port: Int
    public let method: String
    public let password: String
    public let remark: String?
    public let protocolType: ProxyProtocol
    public let uuid: String?
    public let tls: Bool
    public let skipCertVerify: Bool?
    public let flow: String?
    public let clientFingerprint: String?
    public let serverName: String?
    public let udp: Bool?
    public let alterID: Int?
    public let network: String?
    public let wsPath: String?
    public let wsHost: String?

    public init(
        host: String,
        port: Int,
        method: String = "",
        password: String = "",
        remark: String? = nil,
        protocolType: ProxyProtocol = .shadowsocks,
        uuid: String? = nil,
        tls: Bool = false,
        skipCertVerify: Bool? = nil,
        flow: String? = nil,
        clientFingerprint: String? = nil,
        serverName: String? = nil,
        udp: Bool? = nil,
        alterID: Int? = nil,
        network: String? = nil,
        wsPath: String? = nil,
        wsHost: String? = nil
    ) {
        self.host = host
        self.port = port
        self.method = method
        self.password = password
        self.remark = remark
        self.protocolType = protocolType
        self.uuid = uuid
        self.tls = tls
        self.skipCertVerify = skipCertVerify
        self.flow = flow
        self.clientFingerprint = clientFingerprint
        self.serverName = serverName
        self.udp = udp
        self.alterID = alterID
        self.network = network
        self.wsPath = wsPath
        self.wsHost = wsHost
    }

    public var stableID: String {
        [
            protocolType.rawValue,
            host,
            String(port),
            method,
            uuid ?? "",
            flow ?? "",
            serverName ?? "",
            network ?? "",
            wsPath ?? "",
            wsHost ?? "",
            alterID.map(String.init) ?? "",
            remark ?? ""
        ]
        .joined(separator: "|")
    }
}
