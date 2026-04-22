import SwiftUI

struct SubscriptionsView: View {
    @ObservedObject var viewModel: AppViewModel

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private var pageHeaderFont: Font {
        .system(size: 32, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CuspLayout.sectionSpacing) {
                header

                sourceCard

                summaryCard

                if let action = viewModel.lastActionMessage {
                    statusBanner(text: action, color: CuspPalette.success)
                }

                if let error = viewModel.lastErrorMessage {
                    statusBanner(text: error, color: CuspPalette.error)
                }
            }
            .padding(CuspLayout.contentInset)
            .controlSize(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Subscriptions", "订阅"))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("New Source", "新增来源"))
                .font(CuspPalette.sectionTitleFont)
                .foregroundStyle(CuspPalette.primaryText)

            HStack(spacing: 10) {
                TextField(
                    t("Paste subscription URL, e.g. https://example.com/sub", "粘贴订阅链接，例如 https://example.com/sub"),
                    text: $viewModel.importText
                )
                .font(.system(.callout, design: .monospaced))
                .flowGateFilledInputField()

                Button(t("Add", "添加")) {
                    viewModel.subscriptionNameInput = ""
                    viewModel.saveSubscriptionSource()
                }
                .flowGatePrimaryActionStyle()
                .frame(minWidth: 96)
            }
        }
        .flowGatePanelCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Saved Sources", "已保存来源"))
                    .font(CuspPalette.sectionTitleFont)
                    .foregroundStyle(CuspPalette.primaryText)
                Spacer()
                Menu {
                    ForEach(SubscriptionRefreshInterval.allCases) { interval in
                        Button {
                            viewModel.selectedSubscriptionRefreshInterval = interval
                        } label: {
                            if viewModel.selectedSubscriptionRefreshInterval == interval {
                                Label(viewModel.displayName(for: interval), systemImage: "checkmark")
                            } else {
                                Text(viewModel.displayName(for: interval))
                            }
                        }
                    }
                } label: {
                    Text("\(t("Cycle", "周期")): \(viewModel.displayName(for: viewModel.selectedSubscriptionRefreshInterval))")
                }
                .menuStyle(.borderlessButton)

                Button(t("Refresh Enabled", "刷新已启用")) {
                    viewModel.refreshAllSubscriptions()
                }
                .flowGateSecondaryActionStyle()
                .disabled(viewModel.subscriptionSources.isEmpty)
            }

            HStack(spacing: 14) {
                summaryMetric(title: t("Sources", "来源"), value: viewModel.totalSubscriptionCountText)
                summaryMetric(title: t("Saved Nodes", "已保存节点"), value: viewModel.totalSavedNodeCountText)
                summaryMetric(title: t("Selected", "已选中"), value: viewModel.selectedNodeDisplayName)
            }

            if viewModel.subscriptionSources.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.subscriptionSources, id: \.id) { source in
                        sourceRow(for: source)
                    }
                }
            }
        }
        .flowGatePanelCard()
    }

    private var emptyState: some View {
        Text(t("No saved subscription sources yet. Add one above to start building a grouped node catalog.",
               "还没有已保存的订阅来源。请先在上方添加一个，用于构建分组节点目录。"))
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(CuspPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(CuspPalette.raisedCardFill)
            .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func sourceRow(for source: SubscriptionSource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CuspPalette.primaryText)
                    Text(source.urlString.isEmpty ? t("Manual import", "手动导入") : source.urlString)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(CuspPalette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(source.isEnabled ? t("ENABLED", "已启用") : t("DISABLED", "已停用"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .flowGateSemanticCapsule(source.isEnabled ? .success : .neutral)
            }

            HStack(spacing: 14) {
                inlineMeta(title: t("Nodes", "节点"), value: "\(viewModel.catalogNodes.filter { $0.sourceID == source.id }.count)")
                inlineMeta(title: t("Updated", "更新时间"), value: refreshTimeText(for: source))
                inlineMeta(title: t("Status", "状态"), value: statusText(for: source))
                inlineMeta(
                    title: t("Nodes Page", "节点页"),
                    value: viewModel.selectedSourceFilterID == source.id ? t("Current", "当前") : t("Inactive", "未使用")
                )
                Spacer()
            }

            if let usageInfo = source.usageInfo {
                HStack(spacing: 14) {
                    inlineMeta(title: t("Remaining", "剩余流量"), value: remainingTrafficText(from: usageInfo))
                    inlineMeta(title: t("Expires", "有效期"), value: expirationText(from: usageInfo))
                    Spacer()
                }
                .padding(.top, 2)
            }

            if source.lastRefreshStatus == .failure, let message = source.lastErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(CuspPalette.error)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 10) {
                Button(source.urlString.isEmpty ? t("No URL", "无 URL") : t("Refresh", "刷新")) {
                    viewModel.refreshSubscription(id: source.id)
                }
                .flowGateSecondaryActionStyle()
                .disabled(source.urlString.isEmpty)

                Button(t("Edit Source", "编辑来源")) {
                    viewModel.loadSubscriptionIntoEditor(id: source.id)
                }
                .flowGateSecondaryActionStyle()

                Button(source.isEnabled ? t("Disable", "停用") : t("Enable", "启用")) {
                    viewModel.toggleSubscription(id: source.id)
                }
                .flowGateSecondaryActionStyle()

                Button(t("Use In Nodes", "设为节点来源")) {
                    viewModel.selectSourceFilter(id: source.id)
                }
                .flowGatePrimaryActionStyle()
                .disabled(!source.isEnabled || viewModel.selectedSourceFilterID == source.id)

                Button(t("Delete", "删除")) {
                    viewModel.deleteSubscription(id: source.id)
                }
                .flowGateDangerActionStyle()
            }
        }
        .padding(14)
        .background(
            (
                viewModel.selectedSourceFilterID == source.id
                    ? CuspPalette.accent
                    : (viewModel.editingSubscriptionID == source.id ? CuspPalette.accent : CuspPalette.raisedCardFill)
            )
            .opacity(viewModel.selectedSourceFilterID == source.id ? 0.2 : (viewModel.editingSubscriptionID == source.id ? 0.18 : 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func inlineMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CuspPalette.metricLabelFont)
                .foregroundStyle(CuspPalette.tertiaryText)
            Text(value)
                .font(CuspPalette.metricValueFont)
                .monospacedDigit()
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private func statusText(for source: SubscriptionSource) -> String {
        switch source.lastRefreshStatus {
        case .idle:
            return t("Idle", "空闲")
        case .success:
            return t("Healthy", "正常")
        case .failure:
            return t("Failed", "失败")
        }
    }

    private func refreshTimeText(for source: SubscriptionSource) -> String {
        guard let date = source.lastRefreshAt else {
            return "--"
        }
        let relative = Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
        let absolute = Self.dateFormatter.string(from: date)
        return "\(relative) · \(absolute)"
    }

    private func remainingTrafficText(from usageInfo: SubscriptionUsageInfo) -> String {
        guard let total = usageInfo.totalBytes else {
            return "--"
        }
        let used = max(0, (usageInfo.uploadBytes ?? 0) + (usageInfo.downloadBytes ?? 0))
        let remaining = max(0, total - used)
        return Self.byteFormatter.string(fromByteCount: remaining)
    }

    private func expirationText(from usageInfo: SubscriptionUsageInfo) -> String {
        guard let expireAt = usageInfo.expireAt else {
            return "--"
        }
        return Self.expireFormatter.string(from: expireAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let expireFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CuspPalette.metricLabelFont)
                .foregroundStyle(CuspPalette.tertiaryText)
            Text(value)
                .font(CuspPalette.metricValueFont)
                .monospacedDigit()
                .foregroundStyle(CuspPalette.primaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CuspPalette.raisedCardFill)
        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func statusBanner(text: String, color: Color) -> some View {
        Text(text)
            .flowGateStatusBanner(color: color)
    }
}
