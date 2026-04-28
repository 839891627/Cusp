import Foundation

public struct ProxyCommand: Equatable, Sendable {
    public let launchPath: String
    public let arguments: [String]

    public init(launchPath: String, arguments: [String]) {
        self.launchPath = launchPath
        self.arguments = arguments
    }
}

public struct ProxyCommandResult: Equatable, Sendable {
    public let command: ProxyCommand
    public let output: String

    public init(command: ProxyCommand, output: String) {
        self.command = command
        self.output = output
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

    public static func readCommands(services: [String]) -> [ProxyCommand] {
        services.flatMap { service in
            [
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-getwebproxy", service]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-getsecurewebproxy", service]
                ),
                ProxyCommand(
                    launchPath: networksetupPath,
                    arguments: ["-getsocksfirewallproxy", service]
                )
            ]
        }
    }
}

public enum SystemProxyResidualDetector {
    public static func servicesWithResidualCuspProxy(
        from results: [ProxyCommandResult],
        host: String,
        httpPort: Int,
        socksPort: Int
    ) -> [String] {
        var services: [String] = []

        for result in results where isEnabledCuspProxy(result, host: host, httpPort: httpPort, socksPort: socksPort) {
            guard let service = serviceName(from: result.command.arguments), !services.contains(service) else {
                continue
            }
            services.append(service)
        }

        return services
    }

    private static func isEnabledCuspProxy(
        _ result: ProxyCommandResult,
        host: String,
        httpPort: Int,
        socksPort: Int
    ) -> Bool {
        let values = keyValueLines(from: result.output)
        guard values["enabled"]?.lowercased() == "yes",
              values["server"] == host,
              let port = Int(values["port"] ?? "") else {
            return false
        }

        let expectedPort = result.command.arguments.first == "-getsocksfirewallproxy" ? socksPort : httpPort
        return port == expectedPort
    }

    private static func keyValueLines(from output: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    private static func serviceName(from arguments: [String]) -> String? {
        guard arguments.count >= 2 else {
            return nil
        }
        return arguments[1]
    }
}
