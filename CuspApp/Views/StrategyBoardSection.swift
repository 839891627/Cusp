import SwiftUI

struct StrategyBoardSection: View {
    let nodes: [CatalogNode]
    let visibleNodes: [CatalogNode]
    @Binding var searchText: String
    let selectedID: String?
    let selectedMode: RuntimeMode
    let sortMode: NodeSortMode
    let selectedLanguage: AppLanguage
    let isRunningSpeedTest: Bool
    let isApplyingRuntimeChange: Bool
    let probingNodeIDs: Set<String>
    let speedTestCompletedCount: Int
    let speedTestTotalCount: Int
    let onSelect: (String) -> Void
    let onSelectMode: (RuntimeMode) -> Void
    let onRunSpeedTest: () -> Void
    let onSelectSortMode: (NodeSortMode) -> Void
    let onSetDefaultNode: (String) -> Void
    let onRequestRenameNode: (CatalogNode) -> Void
    let onDuplicateNode: (String) -> Void
    let onDeleteNode: (CatalogNode) -> Void
    let onMoveNodeUp: (String) -> Void
    let onMoveNodeDown: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10, alignment: .top), count: 4)

    private var isChinese: Bool {
        selectedLanguage == .simplifiedChinese
    }

    private var pageHeaderFont: Font {
        .system(size: 28, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }
    
    private var effectiveSortMode: NodeSortMode {
        sortMode == .manual ? .latency : sortMode
    }
    
    private var selectableSortModes: [NodeSortMode] {
        NodeSortMode.allCases.filter { $0 != .manual }
    }

    var body: some View {
        if !nodes.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                header
                modeSelector
                nodeControlBar
                if visibleNodes.isEmpty {
                    emptyState
                } else {
                    cardGrid
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Strategy", "策略"))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            modePill(title: t("Direct", "直接连接"), mode: .direct, icon: "chevron.left.forwardslash.chevron.right")
            modePill(title: t("Global", "全局代理"), mode: .global, icon: "arrow.left.and.right")
            modePill(title: t("Rules", "规则判定"), mode: .rules, icon: "point.topleft.down.curvedto.point.bottomright.up")
        }
    }

    private var nodeControlBar: some View {
        HStack(spacing: 8) {
            Text(t("Nodes", "节点"))
                .font(CuspPalette.sectionTitleFont)
                .foregroundStyle(CuspPalette.sectionHeaderAccent)

            Spacer()

            TextField(
                t("Search node name or host", "搜索节点名称或主机"),
                text: $searchText
            )
            .flowGateFilledInputField()
            .frame(maxWidth: 260)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .flowGateSecondaryActionStyle()
            }

            Menu {
                ForEach(selectableSortModes, id: \.rawValue) { mode in
                    Button {
                        onSelectSortMode(mode)
                    } label: {
                        if effectiveSortMode == mode {
                            Label(displayName(for: mode), systemImage: "checkmark")
                        } else {
                            Text(displayName(for: mode))
                        }
                    }
                }
            } label: {
                controlPill(
                    title: isChinese ? "排序：\(displayName(for: effectiveSortMode))" : "Sort: \(displayName(for: effectiveSortMode))",
                    systemImage: "arrow.up.arrow.down",
                    isActive: true
                )
            }
            .menuStyle(.borderlessButton)

            Button {
                onRunSpeedTest()
            } label: {
                controlPill(
                    title: isRunningSpeedTest ? speedTestControlTitle : t("Run Speed Test", "运行测速"),
                    systemImage: isRunningSpeedTest ? "waveform.path.ecg" : "bolt.badge.clock",
                    isActive: isRunningSpeedTest
                )
            }
            .buttonStyle(.plain)
            .disabled(isRunningSpeedTest || isApplyingRuntimeChange)

            if !searchText.isEmpty {
                countBadge(text: "\(visibleNodes.count)/\(nodes.count)")
            } else {
                countBadge(text: isChinese ? "\(nodes.count) 个节点" : "\(nodes.count) Nodes")
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(visibleNodes, id: \.stableID) { node in
                strategyCard(for: node)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(CuspPalette.tertiaryText)
            Text(t("No nodes match this view", "没有匹配该视图的节点"))
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(CuspPalette.primaryText)
            Text(t("Try another search term or switch source in Subscriptions.",
                   "请尝试其他搜索词，或去“订阅”里切换节点来源。"))
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(CuspPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(CuspPalette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: CuspPalette.panelCornerRadius, style: .continuous))
    }

    private func strategyCard(for node: CatalogNode) -> some View {
        let configuration = node.configuration
        let isSelected = configuration.stableID == selectedID
        let isProbing = probingNodeIDs.contains(node.stableID)

        return Button {
            onSelect(configuration.stableID)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(protocolBadge(for: configuration))
                            .font(CuspPalette.metricLabelFont)
                            .foregroundStyle(CuspPalette.tertiaryText)
                            .lineLimit(1)
                        Text(nodeTitle(for: node))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(CuspPalette.primaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        if isProbing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(CuspPalette.accentBright)
                        } else {
                            Image(systemName: isSelected ? "bolt.horizontal.circle.fill" : "circle.dashed")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? CuspPalette.accentBright : statusAccentColor(for: node))
                        }

                        Circle()
                            .fill(statusAccentColor(for: node, isProbing: isProbing))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Text(statusAndLatencyLabel(for: node, isProbing: isProbing))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(latencyColor(for: node, isProbing: isProbing))
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .padding(10)
            .background(cardBackground(for: node, isSelected: isSelected, isProbing: isProbing))
            .overlay(cardBorder(for: node, isSelected: isSelected, isProbing: isProbing))
            .clipShape(RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous))
            .shadow(
                color: isSelected
                    ? CuspPalette.accent.opacity(0.12)
                    : statusAccentColor(for: node, isProbing: isProbing).opacity(node.probeStatus == .idle ? 0.06 : 0.12),
                radius: 6,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplyingRuntimeChange)
        .contextMenu {
            Button {
                onSetDefaultNode(configuration.stableID)
            } label: {
                if isSelected {
                    Label(t("Set As Default", "设为默认"), systemImage: "checkmark")
                } else {
                    Text(t("Set As Default", "设为默认"))
                }
            }

            Button(t("Rename Node…", "重命名节点…")) {
                onRequestRenameNode(node)
            }

            Button(t("Duplicate Node", "复制节点")) {
                onDuplicateNode(configuration.stableID)
            }

            Divider()

            Button(role: .destructive) {
                onDeleteNode(node)
            } label: {
                Text(t("Delete Node", "删除节点"))
            }
        }
    }

    private func countBadge(text: String, emphasis: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(emphasis ? CuspPalette.accentBright : CuspPalette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(emphasis ? CuspPalette.accent.opacity(0.16) : CuspPalette.pillFill)
            )
            .frame(minHeight: 38)
    }

    private func modePill(title: String, mode: RuntimeMode, icon: String) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            onSelectMode(mode)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .lineLimit(1)
            }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : CuspPalette.primaryText.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous)
                        .fill(isSelected ? CuspPalette.accent : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous)
                        .stroke(isSelected ? CuspPalette.accentBright.opacity(0.36) : CuspPalette.hairline.opacity(0.85), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isApplyingRuntimeChange)
    }

    private func controlPill(title: String, systemImage: String, isActive: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(isActive ? CuspPalette.primaryText : CuspPalette.secondaryText)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(isActive ? CuspPalette.accent.opacity(0.16) : CuspPalette.pillFill)
        .clipShape(Capsule())
    }

    private func nodeTitle(for node: CatalogNode) -> String {
        let remark = node.configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let remark, !remark.isEmpty {
            return remark
        }

        return node.configuration.host
    }

    private func displayName(for mode: NodeSortMode) -> String {
        if isChinese {
            switch mode {
            case .manual:
                return "手动"
            case .latency:
                return "按延迟"
            case .name:
                return "按名称"
            }
        }

        switch mode {
        case .manual:
            return "Manual"
        case .latency:
            return "Latency"
        case .name:
            return "Name"
        }
    }

    private func protocolBadge(for configuration: ShadowsocksConfiguration) -> String {
        switch configuration.protocolType {
        case .vmess:
            return "VMess"
        case .trojan:
            return "Trojan"
        case .vless:
            return "VLESS"
        case .shadowsocks:
            return "SS"
        }
    }

    private func statusAndLatencyLabel(for node: CatalogNode, isProbing: Bool) -> String {
        if isProbing {
            return t("Testing...", "测速中...")
        }
        switch (node.probeStatus, node.latestLatencyMs) {
        case (.success, let latency?):
            return "\(latency) ms"
        case (.success, nil):
            return "--"
        case (.timeout, _), (.failure, _):
            return t("Failed", "失败")
        case (.idle, _):
            return t("Pending", "待测")
        }
    }

    private func latencyLabel(for node: CatalogNode, isProbing: Bool) -> String {
        if isProbing {
            return t("testing", "测速中")
        }

        switch (node.probeStatus, node.latestLatencyMs) {
        case (.success, let latency?):
            return "\(latency) ms"
        case (.success, nil):
            return "--"
        case (.timeout, _):
            return t("timeout", "超时")
        case (.failure, _):
            return t("failed", "失败")
        case (.idle, _):
            return "--"
        }
    }

    private func latencyColor(for node: CatalogNode, isProbing: Bool) -> Color {
        if isProbing {
            return CuspPalette.accentBright
        }

        switch node.probeStatus {
        case .success:
            return statusAccentColor(for: node, isProbing: false)
        case .timeout, .failure:
            return CuspPalette.error
        case .idle:
            return CuspPalette.secondaryText
        }
    }

    private func statusAccentColor(for node: CatalogNode, isProbing: Bool = false) -> Color {
        if isProbing {
            return CuspPalette.accentBright
        }

        switch (node.probeStatus, node.latestLatencyMs) {
        case (.success, let latency?) where latency <= 120:
            return CuspPalette.success
        case (.success, let latency?) where latency <= 220:
            return CuspPalette.warning
        case (.success, _):
            return CuspPalette.warning.opacity(0.85)
        case (.timeout, _), (.failure, _):
            return CuspPalette.error
        case (.idle, _):
            return CuspPalette.idle
        }
    }

    private func cardBackground(for node: CatalogNode, isSelected: Bool, isProbing: Bool) -> some View {
        RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isProbing
                        ? [CuspPalette.accent.opacity(0.18), CuspPalette.accentBright.opacity(0.12), CuspPalette.cardFill]
                        : isSelected
                        ? [CuspPalette.accent.opacity(0.14), CuspPalette.raisedCardFill, CuspPalette.selectionFill.opacity(0.42)]
                        : [
                            statusAccentColor(for: node, isProbing: false).opacity(node.probeStatus == .idle ? 0.09 : 0.16),
                            CuspPalette.cardFill
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func cardBorder(for node: CatalogNode, isSelected: Bool, isProbing: Bool) -> some View {
        RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous)
            .stroke(
                isProbing
                    ? CuspPalette.accentBright.opacity(0.38)
                    : isSelected ? CuspPalette.selectionStroke : statusAccentColor(for: node, isProbing: false).opacity(node.probeStatus == .idle ? 0.18 : 0.34),
                lineWidth: 1
            )
    }

    private var speedTestControlTitle: String {
        if isRunningSpeedTest, speedTestTotalCount > 0 {
            return isChinese
                ? "测速 \(speedTestCompletedCount)/\(speedTestTotalCount)"
                : "Testing \(speedTestCompletedCount)/\(speedTestTotalCount)"
        }

        return isRunningSpeedTest ? t("Testing...", "测速中...") : t("Run Speed Test", "运行测速")
    }

    private var selectedNode: CatalogNode? {
        nodes.first(where: { $0.stableID == selectedID })
    }

}
