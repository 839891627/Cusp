import Foundation

extension AppViewModel {
    func saveImportedConfiguration() {
        saveSubscriptionSource()
    }

    func saveSubscriptionSource() {
        Task {
            do {
                let importResult = try await importConfigurationsAndUsage(from: importText)
                let configurations = importResult.configurations
                guard let configuration = configurations.first else {
                    throw SubscriptionParser.Error.noNodesFound
                }
                let existingCatalog = (try? store.loadSubscriptionCatalog())
                    ?? currentSubscriptionCatalog()
                    ?? .empty
                let preservedUsage = editingSubscriptionID.flatMap { sourceID in
                    existingCatalog.sources.first(where: { $0.id == sourceID })?.usageInfo
                }
                let importName = effectiveImportName(defaultConfiguration: configuration)
                let catalog = SubscriptionCatalogBuilder.merging(
                    existing: existingCatalog,
                    sourceID: editingSubscriptionID,
                    importName: importName,
                    importURLString: normalizedImportURLString,
                    configurations: configurations,
                    refreshedAt: Date(),
                    usageInfo: importResult.usageInfo ?? preservedUsage
                )

                let storedCatalog = try saveCatalogSecurely(catalog)
                hydrate(from: storedCatalog)
                let summary = configuration.remark ?? configuration.host
                let wasEditing = editingSubscriptionID != nil
                if configurations.count > 1 {
                    lastActionMessage = "\(wasEditing ? "Updated" : "Imported") \(configurations.count) nodes into \(importName). Current node is \(summary)."
                } else {
                    lastActionMessage = "\(wasEditing ? "Updated" : "Saved") \(summary) into \(importName)."
                }
                lastErrorMessage = nil
                importText = ""
                subscriptionNameInput = ""
                editingSubscriptionID = nil
                refreshReadiness()
            } catch {
                lastActionMessage = nil
                lastErrorMessage = userFacingParseError(error)
            }
        }
    }

    func clearSubscriptionForm() {
        editingSubscriptionID = nil
        subscriptionNameInput = ""
        importText = ""
        lastActionMessage = "Cleared input fields."
        lastErrorMessage = nil
    }

    func toggleSubscription(id: String) {
        guard let index = subscriptionSources.firstIndex(where: { $0.id == id }) else {
            return
        }

        let source = subscriptionSources[index]
        subscriptionSources[index] = SubscriptionSource(
            id: source.id,
            name: source.name,
            urlString: source.urlString,
            isEnabled: !source.isEnabled,
            lastRefreshAt: source.lastRefreshAt,
            lastRefreshStatus: source.lastRefreshStatus,
            lastErrorMessage: source.lastErrorMessage,
            usageInfo: source.usageInfo
        )
        if selectedSourceFilterID == id, subscriptionSources[index].isEnabled == false {
            selectedSourceFilterID = nil
        }
        reconcileSelectionIfNeeded()
        persistCurrentSubscriptionCatalog()
        lastActionMessage = subscriptionSources[index].isEnabled ? "Enabled \(source.name)." : "Disabled \(source.name)."
        lastErrorMessage = nil
        refreshReadiness()
    }

    func refreshSubscription(id: String) {
        guard let source = subscriptionSources.first(where: { $0.id == id }), !source.urlString.isEmpty else {
            return
        }

        Task {
            do {
                let fetchResult = try await fetchSubscriptionPayload(from: source.urlString)
                let configurations = try SubscriptionParser.parseConfigurations(from: fetchResult.body)
                let existingCatalog = currentSubscriptionCatalog() ?? .empty
                let catalog = SubscriptionCatalogBuilder.merging(
                    existing: existingCatalog,
                    importName: source.name,
                    importURLString: source.urlString,
                    configurations: configurations,
                    refreshedAt: Date(),
                    usageInfo: fetchResult.usageInfo ?? source.usageInfo
                )
                let storedCatalog = try saveCatalogSecurely(catalog)
                hydrate(from: storedCatalog)
                lastActionMessage = "Refreshed \(source.name) with \(configurations.count) nodes."
                lastErrorMessage = nil
                refreshReadiness()
            } catch {
                updateSourceFailure(id: id, message: userFacingParseError(error))
            }
        }
    }

    func refreshAllSubscriptions() {
        Task {
            await refreshAllSubscriptions(trigger: .manual)
        }
    }

    func loadSubscriptionIntoEditor(id: String) {
        guard let source = subscriptionSources.first(where: { $0.id == id }) else {
            return
        }

        editingSubscriptionID = source.id
        subscriptionNameInput = source.name
        importText = source.urlString
        lastActionMessage = "Editing \(source.name)."
        lastErrorMessage = nil
    }

    func cancelEditingSubscription() {
        editingSubscriptionID = nil
        subscriptionNameInput = ""
        importText = ""
        lastActionMessage = "Cancelled subscription editing."
        lastErrorMessage = nil
    }

    func deleteSubscription(id: String) {
        removeKeychainValue(for: subscriptionURLKey(sourceID: id))
        for node in catalogNodes where node.sourceID == id {
            removeKeychainValue(for: nodePasswordKey(sourceID: id, stableID: node.stableID))
        }
        if editingSubscriptionID == id {
            editingSubscriptionID = nil
            subscriptionNameInput = ""
            importText = ""
        }
        subscriptionSources.removeAll { $0.id == id }
        catalogNodes.removeAll { $0.sourceID == id }
        if selectedSourceFilterID == id {
            selectedSourceFilterID = nil
        }
        reconcileSelectionIfNeeded()
        persistCurrentSubscriptionCatalog()
        syncStrategyGroupPreferences()
        lastActionMessage = "Deleted the selected subscription source."
        lastErrorMessage = nil
        refreshReadiness()
    }

    func configureAutoRefreshTask() {
        autoRefreshTask?.cancel()
        guard let seconds = selectedSubscriptionRefreshInterval.secondsInterval else {
            return
        }

        autoRefreshTask = Task { [weak self] in
            let intervalNanoseconds = UInt64(seconds * 1_000_000_000)
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else {
                    break
                }
                await self.refreshAllSubscriptions(trigger: .automatic)
            }
        }
    }

    func refreshAllSubscriptions(trigger: SubscriptionRefreshTrigger) async {
        var refreshedCount = 0
        var failedNames: [String] = []

        let targets = subscriptionSources.filter { $0.isEnabled && !$0.urlString.isEmpty }
        guard !targets.isEmpty else {
            if trigger == .manual {
                lastActionMessage = selectedLanguage == .simplifiedChinese
                    ? "没有可刷新的已启用订阅。"
                    : "No enabled subscriptions available to refresh."
                lastErrorMessage = nil
            }
            return
        }

        for source in targets {
            do {
                let fetchResult = try await fetchSubscriptionPayload(from: source.urlString)
                let configurations = try SubscriptionParser.parseConfigurations(from: fetchResult.body)
                let existingCatalog = currentSubscriptionCatalog() ?? .empty
                let catalog = SubscriptionCatalogBuilder.merging(
                    existing: existingCatalog,
                    importName: source.name,
                    importURLString: source.urlString,
                    configurations: configurations,
                    refreshedAt: Date(),
                    usageInfo: fetchResult.usageInfo ?? source.usageInfo
                )
                let storedCatalog = try saveCatalogSecurely(catalog)
                hydrate(from: storedCatalog)
                refreshedCount += 1
            } catch {
                failedNames.append(source.name)
                updateSourceFailure(id: source.id, message: userFacingParseError(error))
            }
        }

        let refreshedMessage: String
        switch selectedLanguage {
        case .english:
            refreshedMessage = trigger == .automatic
                ? "Auto-refreshed \(refreshedCount) subscription sources."
                : "Refreshed \(refreshedCount) subscription sources."
        case .simplifiedChinese:
            refreshedMessage = trigger == .automatic
                ? "自动刷新了 \(refreshedCount) 个订阅来源。"
                : "刷新了 \(refreshedCount) 个订阅来源。"
        }

        if failedNames.isEmpty {
            lastActionMessage = refreshedMessage
            lastErrorMessage = nil
            if trigger == .automatic || trigger == .manual {
                sendNotificationIfNeeded(
                    title: selectedLanguage == .simplifiedChinese ? "订阅刷新完成" : "Subscriptions Updated",
                    body: refreshedMessage
                )
            }
        } else {
            lastActionMessage = refreshedCount > 0 ? refreshedMessage : nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "刷新失败：\(failedNames.joined(separator: "、"))。"
                : "Failed to refresh: \(failedNames.joined(separator: ", "))."
            sendNotificationIfNeeded(
                title: selectedLanguage == .simplifiedChinese ? "订阅刷新异常" : "Subscription Refresh Errors",
                body: lastErrorMessage ?? ""
            )
        }
        notifyIfLowRemainingTraffic()
        refreshReadiness()
    }

    func userFacingParseError(_ error: Error) -> String {
        switch error as? SSURLParser.Error {
        case .invalidScheme:
            return "The link must start with ss://."
        case .invalidPayload:
            return "This ss:// payload could not be decoded."
        case .invalidServer:
            return "The server address or port in this ss:// link is invalid."
        case .none:
            break
        }

        switch error as? SubscriptionParser.Error {
        case .noNodesFound:
            return selectedLanguage == .simplifiedChinese
                ? "没有找到可用节点。请检查订阅是否为空，或链接是否已过期。"
                : "No usable nodes were found. The subscription may be empty or expired."
        case .invalidSubscriptionPayload:
            return selectedLanguage == .simplifiedChinese
                ? "订阅格式无法解析。请确认这是 Clash/Mihomo/SS 标准订阅内容。"
                : "The subscription format is not supported. Please provide a valid Clash/Mihomo/SS subscription payload."
        case .none:
            break
        }

        switch error as? ImportError {
        case .invalidURL:
            return selectedLanguage == .simplifiedChinese
                ? "订阅链接无效，请检查 URL 格式。"
                : "This subscription URL is invalid."
        case .invalidResponse:
            return selectedLanguage == .simplifiedChinese
                ? "订阅服务返回了无效响应。"
                : "The subscription server returned an invalid response."
        case .httpStatus(let statusCode):
            switch statusCode {
            case 401, 403:
                return selectedLanguage == .simplifiedChinese
                    ? "订阅鉴权失败（HTTP \(statusCode)）。请检查 token 或订阅权限。"
                    : "Subscription authorization failed (HTTP \(statusCode)). Check the token or account permissions."
            case 404:
                return selectedLanguage == .simplifiedChinese
                    ? "订阅地址不存在（HTTP 404）。请确认链接是否正确。"
                    : "Subscription URL not found (HTTP 404). Verify the link."
            case 429:
                return selectedLanguage == .simplifiedChinese
                    ? "请求过于频繁（HTTP 429）。请稍后重试。"
                    : "Too many requests (HTTP 429). Please retry later."
            case 500...599:
                return selectedLanguage == .simplifiedChinese
                    ? "订阅服务暂时不可用（HTTP \(statusCode)）。请稍后重试。"
                    : "Subscription server is temporarily unavailable (HTTP \(statusCode)). Try again later."
            default:
                return selectedLanguage == .simplifiedChinese
                    ? "订阅请求失败（HTTP \(statusCode)）。"
                    : "The subscription request failed with HTTP \(statusCode)."
            }
        case .unreadableSubscription:
            return selectedLanguage == .simplifiedChinese
                ? "订阅内容无法按文本读取，可能是返回格式异常。"
                : "The subscription response could not be read as text."
        case .timeout:
            return selectedLanguage == .simplifiedChinese
                ? "订阅请求超时。请检查网络或稍后重试。"
                : "The subscription request timed out. Check your network and retry."
        case .networkUnavailable:
            return selectedLanguage == .simplifiedChinese
                ? "网络不可用或连接失败，请检查当前网络环境。"
                : "Network is unavailable or connection failed. Please check your network."
        case .none:
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    return selectedLanguage == .simplifiedChinese
                        ? "订阅请求超时。请检查网络或稍后重试。"
                        : "The subscription request timed out. Check your network and retry."
                case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                    return selectedLanguage == .simplifiedChinese
                        ? "网络不可用或连接失败，请检查当前网络环境。"
                        : "Network is unavailable or connection failed. Please check your network."
                default:
                    break
                }
            }
            return selectedLanguage == .simplifiedChinese
                ? "导入失败，请检查链接或订阅格式。"
                : "Unable to import configuration."
        }
    }

    private func effectiveImportName(defaultConfiguration: ShadowsocksConfiguration) -> String {
        let trimmedName = subscriptionNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedInput = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedInput), let host = url.host, !host.isEmpty {
            return host
        }

        return defaultConfiguration.remark ?? "Manual Import"
    }

    private var normalizedImportURLString: String {
        let trimmedInput = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.lowercased().hasPrefix("http://") || trimmedInput.lowercased().hasPrefix("https://") else {
            return ""
        }

        return trimmedInput
    }

    private func updateSourceFailure(id: String, message: String) {
        guard let index = subscriptionSources.firstIndex(where: { $0.id == id }) else {
            lastActionMessage = nil
            lastErrorMessage = message
            return
        }

        let source = subscriptionSources[index]
        subscriptionSources[index] = SubscriptionSource(
            id: source.id,
            name: source.name,
            urlString: source.urlString,
            isEnabled: source.isEnabled,
            lastRefreshAt: source.lastRefreshAt,
            lastRefreshStatus: .failure,
            lastErrorMessage: message,
            usageInfo: source.usageInfo
        )
        persistCurrentSubscriptionCatalog()
        lastActionMessage = nil
        lastErrorMessage = message
    }

    private func importConfigurationsAndUsage(from input: String) async throws -> (configurations: [ShadowsocksConfiguration], usageInfo: SubscriptionUsageInfo?) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionParser.Error.noNodesFound
        }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            let payload = try await fetchSubscriptionPayload(from: trimmed)
            return (
                try SubscriptionParser.parseConfigurations(from: payload.body),
                payload.usageInfo
            )
        }

        return (
            try SubscriptionParser.parseConfigurations(from: trimmed),
            nil
        )
    }

    private func fetchSubscriptionPayload(from urlString: String) async throws -> SubscriptionFetchResult {
        guard let url = URL(string: urlString) else {
            throw ImportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Clash Verge/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw ImportError.timeout
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                throw ImportError.networkUnavailable
            default:
                throw urlError
            }
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImportError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ImportError.httpStatus(httpResponse.statusCode)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            throw ImportError.unreadableSubscription
        }
        let usageInfo = parseSubscriptionUsageInfo(from: httpResponse)
        return SubscriptionFetchResult(body: body, usageInfo: usageInfo)
    }

    private func parseSubscriptionUsageInfo(from response: HTTPURLResponse) -> SubscriptionUsageInfo? {
        guard let userInfoHeader = response.value(forHTTPHeaderField: "subscription-userinfo"),
              !userInfoHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var uploadBytes: Int64?
        var downloadBytes: Int64?
        var totalBytes: Int64?
        var expireAt: Date?

        let fields = userInfoHeader.split(separator: ";")
        for field in fields {
            let pair = field.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            guard pair.count == 2 else {
                continue
            }

            let value = pair[1]
            switch pair[0] {
            case "upload":
                uploadBytes = Int64(value)
            case "download":
                downloadBytes = Int64(value)
            case "total":
                totalBytes = Int64(value)
            case "expire":
                if let timestamp = TimeInterval(value), timestamp > 0 {
                    expireAt = Date(timeIntervalSince1970: timestamp)
                }
            default:
                continue
            }
        }

        if uploadBytes == nil, downloadBytes == nil, totalBytes == nil, expireAt == nil {
            return nil
        }

        return SubscriptionUsageInfo(
            uploadBytes: uploadBytes,
            downloadBytes: downloadBytes,
            totalBytes: totalBytes,
            expireAt: expireAt
        )
    }
}
