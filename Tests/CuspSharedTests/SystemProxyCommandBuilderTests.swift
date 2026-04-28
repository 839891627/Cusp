import XCTest
@testable import CuspShared

final class SystemProxyCommandBuilderTests: XCTestCase {
    func testBuildsEnableCommandsForServices() {
        let commands = SystemProxyCommandBuilder.enableCommands(
            services: ["Wi-Fi"],
            host: "127.0.0.1",
            httpPort: 1086,
            socksPort: 1087
        )

        XCTAssertEqual(commands.count, 3)
        XCTAssertEqual(commands[0].arguments, ["-setwebproxy", "Wi-Fi", "127.0.0.1", "1086"])
        XCTAssertEqual(commands[1].arguments, ["-setsecurewebproxy", "Wi-Fi", "127.0.0.1", "1086"])
        XCTAssertEqual(commands[2].arguments, ["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "1087"])
    }

    func testBuildsDisableCommandsForServices() {
        let commands = SystemProxyCommandBuilder.disableCommands(services: ["Wi-Fi"])

        XCTAssertEqual(commands.count, 3)
        XCTAssertEqual(commands[0].arguments, ["-setwebproxystate", "Wi-Fi", "off"])
        XCTAssertEqual(commands[1].arguments, ["-setsecurewebproxystate", "Wi-Fi", "off"])
        XCTAssertEqual(commands[2].arguments, ["-setsocksfirewallproxystate", "Wi-Fi", "off"])
    }

    func testBuildsReadCommandsForServices() {
        let commands = SystemProxyCommandBuilder.readCommands(services: ["Wi-Fi"])

        XCTAssertEqual(commands.count, 3)
        XCTAssertEqual(commands[0].arguments, ["-getwebproxy", "Wi-Fi"])
        XCTAssertEqual(commands[1].arguments, ["-getsecurewebproxy", "Wi-Fi"])
        XCTAssertEqual(commands[2].arguments, ["-getsocksfirewallproxy", "Wi-Fi"])
    }

    func testDetectsResidualCuspProxySettings() {
        let results = [
            ProxyCommandResult(
                command: ProxyCommand(
                    launchPath: SystemProxyCommandBuilder.networksetupPath,
                    arguments: ["-getwebproxy", "Wi-Fi"]
                ),
                output: """
                Enabled: Yes
                Server: 127.0.0.1
                Port: 1086
                Authenticated Proxy Enabled: 0
                """
            ),
            ProxyCommandResult(
                command: ProxyCommand(
                    launchPath: SystemProxyCommandBuilder.networksetupPath,
                    arguments: ["-getsocksfirewallproxy", "Wi-Fi"]
                ),
                output: """
                Enabled: No
                Server: 127.0.0.1
                Port: 1087
                """
            )
        ]

        let services = SystemProxyResidualDetector.servicesWithResidualCuspProxy(
            from: results,
            host: "127.0.0.1",
            httpPort: 1086,
            socksPort: 1087
        )

        XCTAssertEqual(services, ["Wi-Fi"])
    }
}
