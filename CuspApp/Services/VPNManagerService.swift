import Foundation
@preconcurrency import NetworkExtension

@MainActor
final class VPNManagerService {
    private var manager: NETunnelProviderManager?
    var statusDidChange: ((ConnectionState) -> Void)?

    var connectionState: ConnectionState {
        guard let status = manager?.connection.status else {
            return .disconnected
        }
        return Self.map(status)
    }

    func prepare() throws {
        manager = try loadOrCreateManager()
        statusDidChange?(connectionState)
    }

    func startTunnel() throws {
        let manager = try ensureManager()

        if manager.connection.status == .connected || manager.connection.status == .connecting {
            return
        }

        try manager.connection.startVPNTunnel()
        statusDidChange?(Self.map(manager.connection.status))
    }

    func stopTunnel() throws {
        let manager = try ensureManager()
        manager.connection.stopVPNTunnel()
        statusDidChange?(Self.map(manager.connection.status))
    }

    private func ensureManager() throws -> NETunnelProviderManager {
        if let manager {
            return manager
        }

        let loaded = try loadOrCreateManager()
        self.manager = loaded
        return loaded
    }

    private func loadOrCreateManager() throws -> NETunnelProviderManager {
        let managers = try NETunnelProviderManager.loadAllFromPreferencesSync()
        if let existing = managers.first {
            existing.localizedDescription = CuspConstants.managerDescription
            return existing
        }

        let manager = NETunnelProviderManager()
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = CuspConstants.tunnelBundleIdentifier
        protocolConfiguration.serverAddress = CuspConstants.localProxyHost
        protocolConfiguration.disconnectOnSleep = false

        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = CuspConstants.managerDescription
        manager.isEnabled = true

        try manager.saveToPreferencesSync()
        try manager.loadFromPreferencesSync()

        return manager
    }

    private static func map(_ status: NEVPNStatus) -> ConnectionState {
        switch status {
        case .invalid:
            return .invalid
        case .disconnected:
            return .disconnected
        case .connecting, .reasserting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .disconnecting
        @unknown default:
            return .invalid
        }
    }
}

private extension NETunnelProviderManager {
    static func loadAllFromPreferencesSync() throws -> [NETunnelProviderManager] {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SyncResultBox<[NETunnelProviderManager]>([])

        loadAllFromPreferences { managers, error in
            box.value = managers ?? []
            box.error = error
            semaphore.signal()
        }

        semaphore.wait()
        if let error = box.error {
            throw error
        }
        return box.value
    }

    func saveToPreferencesSync() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SyncResultBox<Void>(())

        saveToPreferences { error in
            box.error = error
            semaphore.signal()
        }

        semaphore.wait()
        if let error = box.error {
            throw error
        }
    }

    func loadFromPreferencesSync() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SyncResultBox<Void>(())

        loadFromPreferences { error in
            box.error = error
            semaphore.signal()
        }

        semaphore.wait()
        if let error = box.error {
            throw error
        }
    }
}

private final class SyncResultBox<Value>: @unchecked Sendable {
    var value: Value
    var error: Error?

    init(_ value: Value) {
        self.value = value
    }
}
