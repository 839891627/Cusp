import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    enum ProviderError: LocalizedError {
        case missingConfiguration
        case missingBinary
        case proxyStartupFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "No shared Shadowsocks configuration was found."
            case .missingBinary:
                return "The bundled mihomo binary is missing from the extension resources."
            case .proxyStartupFailed(let message):
                return message
            }
        }
    }

    private let processManager = ProcessManager()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        do {
            let store = try SharedConfigurationStore()
            store.clearLastTunnelError()
            guard let configuration = try store.load() else {
                throw ProviderError.missingConfiguration
            }

            let executableURL = try locateMihomoBinary()
            let runtimeDirectory = try prepareRuntimeDirectory()
            let configURL = try writeMihomoConfiguration(from: configuration, into: runtimeDirectory)
            let process = try processManager.launch(
                executableURL: executableURL,
                arguments: makeMihomoArguments(configURL: configURL),
                environment: [
                    "HOME": NSHomeDirectory()
                ]
            )

            do {
                try ProxyStartupMonitor.waitUntilReady(
                    host: CuspConstants.localProxyHost,
                    port: CuspConstants.localHTTPProxyPort,
                    timeoutInterval: CuspConstants.proxyStartupTimeoutInterval,
                    isProcessRunning: { process.isRunning },
                    diagnostics: { self.processManager.diagnosticSummary() }
                )
            } catch {
                throw ProviderError.proxyStartupFailed(error.localizedDescription)
            }

            let settings = ProxyNetworkSettingsFactory.makeProxySettings(
                localHTTPPort: CuspConstants.localHTTPProxyPort
            )
            apply(settings, store: store, completionHandler: completionHandler)
        } catch {
            persistTunnelError(error)
            processManager.cleanup()
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if let store = try? SharedConfigurationStore() {
            store.clearLastTunnelError()
        }
        processManager.cleanup()
        completionHandler()
    }

    private func locateMihomoBinary() throws -> URL {
        guard let url = Bundle.main.url(forResource: "mihomo", withExtension: nil) else {
            throw ProviderError.missingBinary
        }
        return url
    }

    private func prepareRuntimeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CuspMihomo", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeMihomoConfiguration(
        from configuration: ShadowsocksConfiguration,
        into directory: URL
    ) throws -> URL {
        let configURL = directory.appendingPathComponent("config.yaml")
        let yaml = MihomoConfigBuilder.build(
            from: configuration,
            localHTTPPort: CuspConstants.localHTTPProxyPort,
            localSOCKSPort: CuspConstants.localSOCKSProxyPort
        )
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }

    private func makeMihomoArguments(configURL: URL) -> [String] {
        ["-f", configURL.path]
    }

    private func apply(
        _ settings: NEPacketTunnelNetworkSettings,
        store: SharedConfigurationStore,
        completionHandler: @escaping (Error?) -> Void
    ) {
        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                store.saveLastTunnelError(error.localizedDescription)
                self?.processManager.cleanup()
                completionHandler(error)
            } else {
                store.clearLastTunnelError()
                completionHandler(nil)
            }
        }
    }

    private func persistTunnelError(_ error: Error) {
        let diagnostics = processManager.diagnosticSummary()
        let message: String
        if diagnostics.isEmpty {
            message = error.localizedDescription
        } else {
            message = "\(error.localizedDescription)\n\(diagnostics)"
        }
        if let store = try? SharedConfigurationStore() {
            store.saveLastTunnelError(message)
        }
    }
}
