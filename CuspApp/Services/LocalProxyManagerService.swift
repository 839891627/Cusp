import Foundation
import Security

@MainActor
final class LocalProxyManagerService {
    struct RuntimeTransitionEvent {
        let timestamp: Date
        let from: ConnectionState
        let to: ConnectionState
        let reason: String
        let accepted: Bool
        let elapsedMilliseconds: Int?

        var logLine: String {
            let elapsedText = elapsedMilliseconds.map { " (\($0) ms)" } ?? ""
            let decision = accepted ? "accepted" : "rejected"
            return "\(from.rawValue) -> \(to.rawValue) [\(decision)] \(reason)\(elapsedText)"
        }
    }

    enum Error: LocalizedError {
        case missingBinary
        case invalidBinaryChecksum
        case noEnabledNetworkServices
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingBinary:
                return "mihomo binary was not found in the app resources."
            case .invalidBinaryChecksum:
                return "mihomo binary checksum did not match the pinned runtime manifest."
            case .noEnabledNetworkServices:
                return "No enabled macOS network services were found."
            case .commandFailed(let message):
                return message
            }
        }
    }

    var statusDidChange: ((ConnectionState) -> Void)?
    var transitionDidOccur: ((RuntimeTransitionEvent) -> Void)?

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            statusDidChange?(connectionState)
        }
    }

    private(set) var availableNetworkServices: [String] = []
    private(set) var residualSystemProxyServices: [String] = []
    private let processManager = ProcessManager()
    private let commandExecutor = CommandExecutor()
    private let credentialStore = SecureCredentialStore(service: "org.cusp.runtime")
    private static let controllerSecretAccount = "mihomo-controller-secret"
    private var runtimeConfigURL: URL?

    func prepare() async throws {
        let startedAt = Date()
        cleanupStaleRuntimeConfiguration()
        availableNetworkServices = try await loadEnabledNetworkServices()
        residualSystemProxyServices = try await detectResidualSystemProxyServices(in: availableNetworkServices)
        _ = transition(to: .disconnected, reason: "prepare completed", startedAt: startedAt)
    }

    @discardableResult
    private func transition(to next: ConnectionState, reason: String, startedAt: Date? = nil) -> Bool {
        let previous = connectionState
        let elapsedMilliseconds = startedAt.map { Int(max(0, Date().timeIntervalSince($0) * 1000)) }
        let normalizedReason = normalizeTransitionReason(reason)
        guard canTransition(from: previous, to: next) else {
            emitTransitionEvent(
                RuntimeTransitionEvent(
                    timestamp: Date(),
                    from: previous,
                    to: next,
                    reason: normalizedReason,
                    accepted: false,
                    elapsedMilliseconds: elapsedMilliseconds
                )
            )
            return false
        }
        connectionState = next
        emitTransitionEvent(
            RuntimeTransitionEvent(
                timestamp: Date(),
                from: previous,
                to: next,
                reason: normalizedReason,
                accepted: true,
                elapsedMilliseconds: elapsedMilliseconds
            )
        )
        return true
    }

    private func canTransition(from current: ConnectionState, to next: ConnectionState) -> Bool {
        switch next {
        case .connecting:
            return current == .disconnected || current == .invalid
        case .connected:
            return current == .connecting
        case .disconnecting:
            return current == .connected || current == .connecting
        case .disconnected:
            return current == .invalid || current == .connecting || current == .disconnecting || current == .connected
        case .invalid:
            return false
        }
    }

    func controllerSecret() -> String {
        ensureControllerSecret()
    }

    func start(
        with configuration: ShadowsocksConfiguration,
        allConfigurations: [ShadowsocksConfiguration] = [],
        mode: RuntimeMode = .rules,
        routingRules: [RoutingRule] = RoutingRulePreset.commonMVP,
        proxyGroups: [MihomoProxyGroup] = [],
        activeProxyGroupName: String = "Cusp"
    ) async throws {
        let startedAt = Date()
        guard transition(to: .connecting, reason: "start requested") else {
            return
        }
        let services = try await loadEnabledNetworkServices()
        guard !services.isEmpty else {
            _ = transition(to: .disconnected, reason: "start aborted: no enabled network services", startedAt: startedAt)
            throw Error.noEnabledNetworkServices
        }

        let binaryURL = try locateMihomoBinary()
        let controllerSecret = ensureControllerSecret()
        let configURL = try writeRuntimeConfiguration(
            from: configuration,
            allConfigurations: allConfigurations,
            mode: mode,
            routingRules: routingRules,
            proxyGroups: proxyGroups,
            activeProxyGroupName: activeProxyGroupName,
            controllerSecret: controllerSecret
        )

        do {
            let process = try processManager.launch(
                executableURL: binaryURL,
                arguments: ["-f", configURL.path],
                environment: ProcessInfo.processInfo.environment
            )
            try await ProxyStartupMonitor.waitUntilReadyAsync(
                host: CuspConstants.localProxyHost,
                port: CuspConstants.localHTTPProxyPort,
                timeoutInterval: CuspConstants.proxyStartupTimeoutInterval,
                isProcessRunning: { process.isRunning },
                diagnostics: { self.processManager.diagnosticSummary() }
            )
            try await run(SystemProxyCommandBuilder.enableCommands(
                services: services,
                host: CuspConstants.localProxyHost,
                httpPort: CuspConstants.localHTTPProxyPort,
                socksPort: CuspConstants.localSOCKSProxyPort
            ))
            availableNetworkServices = services
            residualSystemProxyServices = []
            _ = transition(to: .connected, reason: "start completed", startedAt: startedAt)
        } catch {
            try? await run(SystemProxyCommandBuilder.disableCommands(services: services))
            cleanupRuntimeArtifacts()
            _ = transition(to: .disconnected, reason: "start failed: \(error.localizedDescription)", startedAt: startedAt)
            throw Error.commandFailed(error.localizedDescription)
        }
    }

    func stop() async throws {
        let startedAt = Date()
        guard transition(to: .disconnecting, reason: "stop requested") else {
            return
        }
        let services = availableNetworkServices.isEmpty
            ? ((try? await loadEnabledNetworkServices()) ?? [])
            : availableNetworkServices
        var capturedError: Swift.Error?

        do {
            try await run(SystemProxyCommandBuilder.disableCommands(services: services))
        } catch {
            capturedError = error
        }

        cleanupRuntimeArtifacts()
        _ = transition(to: .disconnected, reason: "stop completed", startedAt: startedAt)

        if let capturedError {
            throw capturedError
        }
    }

    func restoreResidualSystemProxySettings() async throws {
        let services = residualSystemProxyServices.isEmpty
            ? try await detectResidualSystemProxyServices(in: availableNetworkServices)
            : residualSystemProxyServices
        guard !services.isEmpty else {
            return
        }
        try await run(SystemProxyCommandBuilder.disableCommands(services: services))
        residualSystemProxyServices = []
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
        guard MihomoRuntimeManifest.bundled.validateBinary(at: url) else {
            throw Error.invalidBinaryChecksum
        }

        return url
    }

    private func writeRuntimeConfiguration(
        from configuration: ShadowsocksConfiguration,
        allConfigurations: [ShadowsocksConfiguration],
        mode: RuntimeMode,
        routingRules: [RoutingRule],
        proxyGroups: [MihomoProxyGroup],
        activeProxyGroupName: String,
        controllerSecret: String
    ) throws -> URL {
        let root = try runtimeDirectory()
        let fileURL = root.appendingPathComponent("config.yaml")
        let contents = MihomoConfigBuilder.build(
            from: configuration,
            allConfigurations: allConfigurations,
            mode: mode,
            routingRules: routingRules,
            proxyGroups: proxyGroups,
            activeProxyGroupName: activeProxyGroupName,
            localControllerSecret: controllerSecret
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        runtimeConfigURL = fileURL
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
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return directory
    }

    private func loadEnabledNetworkServices() async throws -> [String] {
        let output = try await run(ProxyCommand(
            launchPath: SystemProxyCommandBuilder.networksetupPath,
            arguments: ["-listallnetworkservices"]
        ))
        return NetworkServiceParser.parseEnabledServices(from: output)
    }

    private func detectResidualSystemProxyServices(in services: [String]) async throws -> [String] {
        guard !services.isEmpty,
              !LocalPortWaiter.isListening(
                host: CuspConstants.localProxyHost,
                port: CuspConstants.localHTTPProxyPort
              ) else {
            return []
        }

        var results: [ProxyCommandResult] = []
        for command in SystemProxyCommandBuilder.readCommands(services: services) {
            let output = try await run(command)
            results.append(ProxyCommandResult(command: command, output: output))
        }

        return SystemProxyResidualDetector.servicesWithResidualCuspProxy(
            from: results,
            host: CuspConstants.localProxyHost,
            httpPort: CuspConstants.localHTTPProxyPort,
            socksPort: CuspConstants.localSOCKSProxyPort
        )
    }

    private func run(_ commands: [ProxyCommand]) async throws {
        for command in commands {
            _ = try await run(command)
        }
    }

    private func run(_ command: ProxyCommand) async throws -> String {
        try await commandExecutor.run(command)
    }

    nonisolated private static func execute(_ command: ProxyCommand) throws -> String {
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
            throw Error.commandFailed(RuntimeLogSanitizer.sanitize(message))
        }

        return output
    }

    private func ensureControllerSecret() -> String {
        if let existing = credentialStore.string(for: Self.controllerSecretAccount), !existing.isEmpty {
            return existing
        }
        let generated = makeRandomSecret()
        credentialStore.setString(generated, for: Self.controllerSecretAccount)
        return generated
    }

    private func makeRandomSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private func cleanupRuntimeArtifacts() {
        processManager.cleanup()
        if let runtimeConfigURL {
            try? FileManager.default.removeItem(at: runtimeConfigURL)
            self.runtimeConfigURL = nil
        }
    }

    private func cleanupStaleRuntimeConfiguration() {
        let fileURL = try? runtimeDirectory().appendingPathComponent("config.yaml")
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        runtimeConfigURL = nil
    }

    private func emitTransitionEvent(_ event: RuntimeTransitionEvent) {
        transitionDidOccur?(event)
    }

    private func normalizeTransitionReason(_ reason: String) -> String {
        let collapsed = reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if collapsed.count <= 220 {
            return collapsed
        }
        let prefix = collapsed.prefix(220)
        return "\(prefix)..."
    }

    private actor CommandExecutor {
        func run(_ command: ProxyCommand) throws -> String {
            try LocalProxyManagerService.execute(command)
        }
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
