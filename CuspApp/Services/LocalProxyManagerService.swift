import Foundation

@MainActor
final class LocalProxyManagerService {
    enum Error: LocalizedError {
        case missingBinary
        case noEnabledNetworkServices
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingBinary:
                return "mihomo binary was not found in the app resources."
            case .noEnabledNetworkServices:
                return "No enabled macOS network services were found."
            case .commandFailed(let message):
                return message
            }
        }
    }

    var statusDidChange: ((ConnectionState) -> Void)?

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            statusDidChange?(connectionState)
        }
    }

    private(set) var availableNetworkServices: [String] = []
    private let processManager = ProcessManager()

    func prepare() throws {
        availableNetworkServices = try loadEnabledNetworkServices()
        if connectionState == .invalid {
            connectionState = .disconnected
        }
    }

    func start(
        with configuration: ShadowsocksConfiguration,
        allConfigurations: [ShadowsocksConfiguration] = [],
        mode: RuntimeMode = .rules,
        routingRules: [RoutingRule] = RoutingRulePreset.commonMVP,
        proxyGroups: [MihomoProxyGroup] = [],
        activeProxyGroupName: String = "Cusp"
    ) throws {
        if connectionState == .connected || connectionState == .connecting {
            return
        }

        connectionState = .connecting
        let services = try loadEnabledNetworkServices()
        guard !services.isEmpty else {
            connectionState = .disconnected
            throw Error.noEnabledNetworkServices
        }

        let binaryURL = try locateMihomoBinary()
        let configURL = try writeRuntimeConfiguration(
            from: configuration,
            allConfigurations: allConfigurations,
            mode: mode,
            routingRules: routingRules,
            proxyGroups: proxyGroups,
            activeProxyGroupName: activeProxyGroupName
        )

        do {
            let process = try processManager.launch(
                executableURL: binaryURL,
                arguments: ["-f", configURL.path],
                environment: ProcessInfo.processInfo.environment
            )
            try ProxyStartupMonitor.waitUntilReady(
                host: CuspConstants.localProxyHost,
                port: CuspConstants.localHTTPProxyPort,
                timeoutInterval: CuspConstants.proxyStartupTimeoutInterval,
                isProcessRunning: { process.isRunning },
                diagnostics: { self.processManager.diagnosticSummary() }
            )
            try run(SystemProxyCommandBuilder.enableCommands(
                services: services,
                host: CuspConstants.localProxyHost,
                httpPort: CuspConstants.localHTTPProxyPort,
                socksPort: CuspConstants.localSOCKSProxyPort
            ))
            availableNetworkServices = services
            connectionState = .connected
        } catch {
            try? run(SystemProxyCommandBuilder.disableCommands(services: services))
            processManager.cleanup()
            connectionState = .disconnected
            throw Error.commandFailed(error.localizedDescription)
        }
    }

    func stop() throws {
        if connectionState == .disconnected || connectionState == .disconnecting {
            return
        }

        connectionState = .disconnecting
        let services = availableNetworkServices.isEmpty ? (try? loadEnabledNetworkServices()) ?? [] : availableNetworkServices
        var capturedError: Swift.Error?

        do {
            try run(SystemProxyCommandBuilder.disableCommands(services: services))
        } catch {
            capturedError = error
        }

        processManager.cleanup()
        connectionState = .disconnected

        if let capturedError {
            throw capturedError
        }
    }

    private func locateMihomoBinary() throws -> URL {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.url(forResource: "mihomo", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("mihomo"),
            locateProjectRoot()?.appendingPathComponent("Resources/mihomo/mihomo")
        ]
        .compactMap { $0 }

        guard let url = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) || fileManager.fileExists(atPath: $0.path) }) else {
            throw Error.missingBinary
        }

        return url
    }

    private func writeRuntimeConfiguration(
        from configuration: ShadowsocksConfiguration,
        allConfigurations: [ShadowsocksConfiguration],
        mode: RuntimeMode,
        routingRules: [RoutingRule],
        proxyGroups: [MihomoProxyGroup],
        activeProxyGroupName: String
    ) throws -> URL {
        let root = try runtimeDirectory()
        let fileURL = root.appendingPathComponent("config.yaml")
        let contents = MihomoConfigBuilder.build(
            from: configuration,
            allConfigurations: allConfigurations,
            mode: mode,
            routingRules: routingRules,
            proxyGroups: proxyGroups,
            activeProxyGroupName: activeProxyGroupName
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func runtimeDirectory() throws -> URL {
        let fileManager = FileManager.default
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL
            .appendingPathComponent("Cusp", isDirectory: true)
            .appendingPathComponent("Runtime", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func loadEnabledNetworkServices() throws -> [String] {
        let output = try run(ProxyCommand(
            launchPath: SystemProxyCommandBuilder.networksetupPath,
            arguments: ["-listallnetworkservices"]
        ))
        let services = NetworkServiceParser.parseEnabledServices(from: output)
        availableNetworkServices = services
        return services
    }

    private func run(_ commands: [ProxyCommand]) throws {
        for command in commands {
            _ = try run(command)
        }
    }

    private func run(_ command: ProxyCommand) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: command.launchPath)
        process.arguments = command.arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw Error.commandFailed("Unable to run \(command.arguments.joined(separator: " ")): \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = [errorOutput, output]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? "networksetup exited with code \(process.terminationStatus)."
            throw Error.commandFailed(message)
        }

        return output
    }

    private func locateProjectRoot() -> URL? {
        let candidates = [
            Bundle.main.bundleURL,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ]

        for candidate in candidates {
            var current = candidate
            for _ in 0..<8 {
                if FileManager.default.fileExists(atPath: current.appendingPathComponent("Cusp.xcodeproj").path) {
                    return current
                }
                current.deleteLastPathComponent()
            }
        }

        return nil
    }
}
