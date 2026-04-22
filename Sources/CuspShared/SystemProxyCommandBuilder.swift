import Foundation

public struct ProxyCommand: Equatable, Sendable {
    public let launchPath: String
    public let arguments: [String]

    public init(launchPath: String, arguments: [String]) {
        self.launchPath = launchPath
        self.arguments = arguments
    }
}

public enum SystemProxyCommandBuilder {
    public static let networksetupPath = "/usr/sbin/networksetup"

    public static func enableCommands(
        services: [String],
        host: String,
        httpPort: Int,
        socksPort: Int
    ) -> [ProxyCommand] {
        services.flatMap { service in
            [
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setwebproxy", service, host, String(httpPort)]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setsecurewebproxy", service, host, String(httpPort)]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setsocksfirewallproxy", service, host, String(socksPort)]
                )
            ]
        }
    }

    public static func disableCommands(services: [String]) -> [ProxyCommand] {
        services.flatMap { service in
            [
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setwebproxystate", service, "off"]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setsecurewebproxystate", service, "off"]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-setsocksfirewallproxystate", service, "off"]
                )
            ]
        }
    }
}
