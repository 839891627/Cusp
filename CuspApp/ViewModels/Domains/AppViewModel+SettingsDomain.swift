import AppKit
import Darwin
import Foundation
import ServiceManagement
import UserNotifications

extension AppViewModel {
    func configureLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLoginEnabled, forKey: Self.launchAtLoginEnabledKey)
        do {
            if launchAtLoginEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "更新开机自启失败。"
                : "Failed to update launch at login."
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled
        configureLaunchAtLogin()
    }

    func setRestoreConnectionOnLaunchEnabled(_ enabled: Bool) {
        restoreConnectionOnLaunchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.restoreConnectionOnLaunchKey)
    }

    func setNotificationEnabled(_ enabled: Bool) {
        notificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.notificationEnabledKey)
        if enabled {
            requestNotificationAuthorizationIfNeeded()
        }
    }

    func setDisconnectWhenOtherVPNActiveEnabled(_ enabled: Bool) {
        disconnectWhenOtherVPNActiveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.disconnectWhenOtherVPNActiveKey)
    }

    func requestNotificationAuthorizationIfNeeded() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
}

extension AppViewModel {
    func startMetricsRefreshLoop() {
        metricsRefreshTask?.cancel()
        metricsRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshOverviewMetrics()
                try? await Task.sleep(nanoseconds: self.metricsRefreshIntervalNanoseconds())
            }
        }
    }

    func refreshOverviewMetrics() async {
        let currentConfiguration = activeConfiguration
        let shouldProbeLatency = connectionState == .connected || connectionState == .connecting
        let shouldRefreshIP = shouldRefreshPublicIPAddress()
        async let ipResult: String = shouldRefreshIP ? fetchPublicIPAddress() : cachedPublicIPText
        async let latencyResult: (String, NodeLatencyProbe.ProbeResult?) = {
            guard shouldProbeLatency, let currentConfiguration else {
                return ("-- ms", nil)
            }
            let probeResult = await NodeLatencyProbe.measureLatency(
                host: currentConfiguration.host,
                port: currentConfiguration.port
            )
            if let latency = probeResult.latencyMs {
                return ("\(latency) ms", probeResult)
            }
            return (probeResult.status == .timeout ? "Timeout" : "-- ms", probeResult)
        }()

        let (ipText, latencyPayload) = await (ipResult, latencyResult)
        let (latencyValue, probeResult) = latencyPayload
        if shouldRefreshIP {
            cachedPublicIPText = ipText
            lastPublicIPFetchAt = Date()
        }
        latencyText = latencyValue
        ipAddressText = ipText

        if let currentConfiguration, let probeResult {
            updateProbeResult(for: currentConfiguration.stableID, result: probeResult)
            handleAutoFailoverIfNeeded(currentConfiguration: currentConfiguration, probeResult: probeResult)
        }
    }

    func metricsRefreshIntervalNanoseconds() -> UInt64 {
        connectionState == .connected || connectionState == .connecting
            ? connectedMetricsRefreshIntervalNanoseconds
            : disconnectedMetricsRefreshIntervalNanoseconds
    }

    func shouldRefreshPublicIPAddress() -> Bool {
        let now = Date()
        let refreshInterval = connectionState == .connected || connectionState == .connecting
            ? connectedPublicIPRefreshInterval
            : disconnectedPublicIPRefreshInterval
        guard let lastPublicIPFetchAt else {
            return true
        }
        return now.timeIntervalSince(lastPublicIPFetchAt) >= refreshInterval
    }

    func updateProbeResult(for stableID: String, result: NodeLatencyProbe.ProbeResult) {
        guard let index = catalogNodes.firstIndex(where: { $0.stableID == stableID }) else {
            return
        }

        let existing = catalogNodes[index]
        let resolvedLatency: Int?
        if result.status == .success, existing.latestLatencyMs != nil {
            // Keep list-card latency stable (typically from full speed test), and
            // only refresh status for periodic active-node probes.
            resolvedLatency = existing.latestLatencyMs
        } else {
            resolvedLatency = result.latencyMs
        }

        if existing.latestLatencyMs == resolvedLatency, existing.probeStatus == result.status {
            return
        }

        catalogNodes[index] = CatalogNode(
            configuration: existing.configuration,
            sourceID: existing.sourceID,
            latestLatencyMs: resolvedLatency,
            lastProbeAt: Date(),
            probeStatus: result.status
        )
        persistCurrentSubscriptionCatalog()
    }

    func handleAutoFailoverIfNeeded(
        currentConfiguration: ShadowsocksConfiguration,
        probeResult: NodeLatencyProbe.ProbeResult
    ) {
        guard connectionState == .connected, !isApplyingRuntimeChange else {
            return
        }
        guard probeResult.status == .failure || probeResult.status == .timeout else {
            return
        }
        guard
            let activeCustomGroup = activeCustomStrategyGroup(),
            activeCustomGroup.type == .fallback,
            normalizedMihomoGroupName(activeCustomGroup.name) == activeRuntimeProxyGroupName,
            let currentNode = catalogNodes.first(where: { $0.stableID == currentConfiguration.stableID }),
            currentNode.sourceID == activeCustomGroup.sourceID
        else {
            return
        }

        if let lastAutoFailoverAt, Date().timeIntervalSince(lastAutoFailoverAt) < autoFailoverCooldown {
            return
        }

        let sameGroupNodes = catalogNodes
            .filter { $0.sourceID == activeCustomGroup.sourceID && $0.stableID != currentNode.stableID }
        guard let candidate = preferredNode(in: sameGroupNodes, policy: .fallback) else {
            return
        }
        guard candidate.stableID != currentNode.stableID else {
            return
        }

        lastAutoFailoverAt = Date()
        selectConfiguration(id: candidate.stableID)
        markStrategyGroupSwitched(id: activeCustomGroup.id, source: .autoFailover, at: lastAutoFailoverAt ?? Date())
        let groupName = activeCustomGroup.name
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "检测到节点不可用，已按策略组「\(groupName)」自动切换。"
            : "Detected node failure and auto-switched by strategy group \"\(groupName)\"."
    }

    func fetchPublicIPAddress() async -> String {
        let endpoints = [
            "https://api.ipify.org",
            "https://ipv4.icanhazip.com",
            "https://ifconfig.me/ip"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else {
                continue
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 6
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Cusp/1.0", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continue
                }
                let value = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            } catch {
                continue
            }
        }

        return "--"
    }
}

extension AppViewModel {
    func startTrafficRefreshLoop() {
        trafficRefreshTask?.cancel()
        trafficRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshTrafficMetrics()
                self.trafficRefreshTick = (self.trafficRefreshTick + 1) % 2
                if self.trafficRefreshTick == 0 {
                    await self.refreshProcessTrafficMetrics()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func refreshProcessTrafficNow() {
        Task {
            await refreshProcessTrafficMetrics()
        }
    }

    func copyProcessMetadataToClipboard(entryID: String) {
        guard let entry = processTrafficEntries.first(where: { $0.id == entryID }),
              let summary = entry.metadataSummary,
              !summary.isEmpty else {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "当前条目没有可复制的 metadata。"
                : "No metadata is available for this entry."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已复制 metadata。"
            : "Copied metadata."
        lastErrorMessage = nil
    }

    func resetSessionTraffic() {
        sessionUploadBytes = 0
        sessionDownloadBytes = 0
        sessionUploadText = "0 B"
        sessionDownloadText = "0 B"
        trafficSamples = []
    }

    func normalizeTrafficCountersIfNeeded() {
        let now = Date()
        let todayTag = Self.dayFormatter.string(from: now)
        let monthTag = Self.monthFormatter.string(from: now)

        let savedTodayTag = UserDefaults.standard.string(forKey: Self.todayTrafficDateKey) ?? todayTag
        let savedMonthTag = UserDefaults.standard.string(forKey: Self.monthlyTrafficTagKey) ?? monthTag

        if savedTodayTag != todayTag {
            todayTotalBytes = 0
            persistTrafficCountersIfNeeded(force: true)
        }
        if savedMonthTag != monthTag {
            monthlyTotalBytes = 0
            persistTrafficCountersIfNeeded(force: true)
        }

        UserDefaults.standard.set(todayTag, forKey: Self.todayTrafficDateKey)
        UserDefaults.standard.set(monthTag, forKey: Self.monthlyTrafficTagKey)
        todayTotalText = Self.byteFormatter.string(fromByteCount: Int64(todayTotalBytes))
        monthlyTotalText = Self.byteFormatter.string(fromByteCount: Int64(monthlyTotalBytes))
    }

    func persistTrafficCountersIfNeeded(force: Bool) {
        let now = Date()
        if !force,
           let lastTrafficPersistenceAt,
           now.timeIntervalSince(lastTrafficPersistenceAt) < trafficPersistenceInterval {
            return
        }

        UserDefaults.standard.set(Int(todayTotalBytes), forKey: Self.todayTrafficBytesKey)
        UserDefaults.standard.set(Int(monthlyTotalBytes), forKey: Self.monthlyTrafficBytesKey)
        lastTrafficPersistenceAt = now
    }

    private func refreshTrafficMetrics() async {
        normalizeTrafficCountersIfNeeded()
        guard let current = currentNetworkByteSnapshot() else {
            return
        }

        defer {
            lastTrafficSnapshot = current
        }

        guard let previous = lastTrafficSnapshot else {
            lastTrafficSnapshot = current
            return
        }

        let deltaSeconds = max(0.001, current.timestamp.timeIntervalSince(previous.timestamp))
        let uploadDelta = current.uploadBytes >= previous.uploadBytes ? current.uploadBytes - previous.uploadBytes : 0
        let downloadDelta = current.downloadBytes >= previous.downloadBytes ? current.downloadBytes - previous.downloadBytes : 0

        let uploadRate = Double(uploadDelta) / deltaSeconds
        let downloadRate = Double(downloadDelta) / deltaSeconds
        uploadRateText = Self.rateFormatter(bytesPerSecond: uploadRate)
        downloadRateText = Self.rateFormatter(bytesPerSecond: downloadRate)

        guard connectionState == .connected || connectionState == .connecting else {
            return
        }

        sessionUploadBytes += uploadDelta
        sessionDownloadBytes += downloadDelta
        todayTotalBytes += uploadDelta + downloadDelta
        monthlyTotalBytes += uploadDelta + downloadDelta

        sessionUploadText = Self.byteFormatter.string(fromByteCount: Int64(sessionUploadBytes))
        sessionDownloadText = Self.byteFormatter.string(fromByteCount: Int64(sessionDownloadBytes))
        todayTotalText = Self.byteFormatter.string(fromByteCount: Int64(todayTotalBytes))
        monthlyTotalText = Self.byteFormatter.string(fromByteCount: Int64(monthlyTotalBytes))

        persistTrafficCountersIfNeeded(force: false)

        trafficSamples.append(
            TrafficSample(
                uploadBytesPerSecond: uploadRate,
                downloadBytesPerSecond: downloadRate
            )
        )
        if trafficSamples.count > maxTrafficSamples {
            trafficSamples.removeFirst(trafficSamples.count - maxTrafficSamples)
        }
    }

    private func refreshProcessTrafficMetrics() async {
        guard connectionState == .connected || connectionState == .connecting else {
            if !processTrafficEntries.isEmpty {
                processTrafficEntries = []
            }
            lastProcessTrafficSnapshot = [:]
            lastProcessTrafficRefreshedAt = nil
            return
        }

        do {
            let connections = try await fetchMihomoConnections()
            let currentTime = Date()
            let previousSnapshot = lastProcessTrafficSnapshot
            let deltaSeconds = max(0.001, currentTime.timeIntervalSince(lastProcessTrafficRefreshedAt ?? currentTime))
            let grouped = Dictionary(grouping: connections) { connection in
                ProcessGroupingKey(routing: routingType(for: connection))
            }

            let entries = grouped.map { key, items in
                let uploadBytes = items.reduce(0) { $0 + $1.upload }
                let downloadBytes = items.reduce(0) { $0 + $1.download }
                let snapshotKey = ProcessTrafficEntry.snapshotKey(routing: key.routing)
                let previous = previousSnapshot[snapshotKey]
                let uploadDelta = max(0, Int64(uploadBytes) - Int64(previous?.uploadBytes ?? uploadBytes))
                let downloadDelta = max(0, Int64(downloadBytes) - Int64(previous?.downloadBytes ?? downloadBytes))
                let metadataText = items.compactMap { metadataSummary(for: $0) }.first
                return ProcessTrafficEntry(
                    routing: key.routing,
                    uploadBytes: uploadBytes,
                    downloadBytes: downloadBytes,
                    uploadBytesPerSecond: Double(uploadDelta) / deltaSeconds,
                    downloadBytesPerSecond: Double(downloadDelta) / deltaSeconds,
                    activeConnections: items.count,
                    metadataSummary: metadataText
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalBytes == rhs.totalBytes {
                    return lhs.id < rhs.id
                }
                return lhs.totalBytes > rhs.totalBytes
            }

            processTrafficEntries = entries
            lastProcessTrafficSnapshot = Dictionary(
                uniqueKeysWithValues: entries.map {
                    (
                        $0.id,
                        ProcessByteSnapshot(uploadBytes: $0.uploadBytes, downloadBytes: $0.downloadBytes)
                    )
                }
            )
            lastProcessTrafficRefreshedAt = currentTime
        } catch {
            processTrafficEntries = []
            lastProcessTrafficSnapshot = [:]
            lastProcessTrafficRefreshedAt = nil
        }
    }

    private func currentNetworkByteSnapshot() -> NetworkByteSnapshot? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        var sent: UInt64 = 0
        var received: UInt64 = 0
        var pointer = firstAddr
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp && !isLoopback,
               interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                sent += UInt64(data.pointee.ifi_obytes)
                received += UInt64(data.pointee.ifi_ibytes)
            }
            guard let next = interface.ifa_next else {
                break
            }
            pointer = next
        }

        return NetworkByteSnapshot(timestamp: Date(), uploadBytes: sent, downloadBytes: received)
    }

    private func fetchMihomoConnections() async throws -> [MihomoConnection] {
        let endpoint = "http://\(CuspConstants.localProxyHost):\(CuspConstants.localControllerPort)/connections"
        guard let url = URL(string: endpoint) else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(proxyService.controllerSecret())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }

        let decoded = try JSONDecoder().decode(MihomoConnectionsResponse.self, from: data)
        return decoded.connections
    }

    private func routingType(for connection: MihomoConnection) -> ProcessRoutingType {
        let chains = connection.chains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if chains.contains(where: { $0.caseInsensitiveCompare("DIRECT") == .orderedSame }) {
            return .direct
        }
        if chains.contains(where: { $0.caseInsensitiveCompare("REJECT") == .orderedSame || $0.caseInsensitiveCompare("REJECT-DROP") == .orderedSame }) {
            return .reject
        }
        if let proxyName = chains.last(where: {
            $0.caseInsensitiveCompare("DIRECT") != .orderedSame
                && $0.caseInsensitiveCompare("REJECT") != .orderedSame
                && $0.caseInsensitiveCompare("REJECT-DROP") != .orderedSame
        }) {
            return .proxy(proxyName)
        }

        if let rule = connection.rule?.uppercased() {
            if rule.contains("DIRECT") {
                return .direct
            }
            if rule.contains("REJECT") {
                return .reject
            }
        }
        return .unknown
    }

    private func metadataSummary(for connection: MihomoConnection) -> String? {
        let metadata = connection.metadata
        var lines: [String] = []
        if let process = metadata.process, !process.isEmpty {
            lines.append("process: \(process)")
        }
        if let processName = metadata.processName, !processName.isEmpty {
            lines.append("process_name: \(processName)")
        }
        if let processPath = metadata.processPath, !processPath.isEmpty {
            lines.append("process_path: \(processPath)")
        }
        if let host = metadata.host, !host.isEmpty {
            lines.append("host: \(host)")
        }
        if let destinationIP = metadata.destinationIP, !destinationIP.isEmpty {
            if let destinationPort = metadata.destinationPort, !destinationPort.isEmpty {
                lines.append("destination: \(destinationIP):\(destinationPort)")
            } else {
                lines.append("destination: \(destinationIP)")
            }
        }
        if let network = metadata.network, !network.isEmpty {
            lines.append("network: \(network)")
        }
        if let type = metadata.type, !type.isEmpty {
            lines.append("type: \(type)")
        }
        if let sourceIP = metadata.sourceIP, !sourceIP.isEmpty {
            lines.append("source_ip: \(sourceIP)")
        }
        if let sourcePort = metadata.sourcePort, !sourcePort.isEmpty {
            lines.append("source_port: \(sourcePort)")
        }

        if let rule = connection.rule, !rule.isEmpty {
            lines.append("rule: \(rule)")
        }
        if !connection.chains.isEmpty {
            lines.append("chains: \(connection.chains.joined(separator: " -> "))")
        }
        lines.append("download_bytes: \(connection.download)")
        lines.append("upload_bytes: \(connection.upload)")
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private struct ProcessGroupingKey: Hashable {
        let routing: ProcessRoutingType
    }

    private struct MihomoConnectionsResponse: Decodable {
        let connections: [MihomoConnection]
    }

    private struct MihomoConnection: Decodable {
        let upload: UInt64
        let download: UInt64
        let chains: [String]
        let rule: String?
        let metadata: MihomoConnectionMetadata
    }

    private struct MihomoConnectionMetadata: Decodable {
        let process: String?
        let processName: String?
        let processPath: String?
        let host: String?
        let destinationIP: String?
        let destinationPort: String?
        let network: String?
        let type: String?
        let sourceIP: String?
        let sourcePort: String?

        enum CodingKeys: String, CodingKey {
            case process
            case processName
            case processPath
            case host
            case destinationIP
            case destinationPort
            case network
            case type
            case sourceIP
            case sourcePort
            case process_name
            case process_path
            case destination_ip
            case destination_port
            case source_ip
            case source_port
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            process = try container.decodeIfPresent(String.self, forKey: .process)
            processName = try container.decodeIfPresent(String.self, forKey: .processName)
                ?? container.decodeIfPresent(String.self, forKey: .process_name)
            processPath = try container.decodeIfPresent(String.self, forKey: .processPath)
                ?? container.decodeIfPresent(String.self, forKey: .process_path)
            host = try container.decodeIfPresent(String.self, forKey: .host)
            destinationIP = try container.decodeIfPresent(String.self, forKey: .destinationIP)
                ?? container.decodeIfPresent(String.self, forKey: .destination_ip)
            destinationPort = try container.decodeIfPresent(String.self, forKey: .destinationPort)
                ?? container.decodeIfPresent(String.self, forKey: .destination_port)
            network = try container.decodeIfPresent(String.self, forKey: .network)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            sourceIP = try container.decodeIfPresent(String.self, forKey: .sourceIP)
                ?? container.decodeIfPresent(String.self, forKey: .source_ip)
            sourcePort = try container.decodeIfPresent(String.self, forKey: .sourcePort)
                ?? container.decodeIfPresent(String.self, forKey: .source_port)
        }
    }
}
