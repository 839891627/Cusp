import SwiftUI

struct NodesView: View {
    private enum AddStrategyStep {
        case selectType
        case configure
    }

    @ObservedObject var viewModel: AppViewModel
    @State private var showAddStrategyGroupSheet = false
    @State private var addStrategyStep: AddStrategyStep = .selectType
    @State private var draftStrategyType: CustomStrategyGroupType = .manual
    @State private var draftStrategyName = ""
    @State private var draftStrategySourceID: String?
    @State private var editingStrategyGroupID: String?
    @State private var draftTestURL = "https://www.gstatic.com/generate_204"
    @State private var draftIntervalSecondsText = "300"
    @State private var pendingDeleteStrategyGroup: CustomStrategyGroup?
    @State private var editingNodeID: String?
    @State private var draftNodeName = ""
    @State private var pendingDeleteNode: CatalogNode?

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private var enabledSources: [SubscriptionSource] {
        viewModel.subscriptionSources.filter(\.isEnabled)
    }

    private var strategyGroupColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10, alignment: .top), count: 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CuspLayout.sectionSpacing) {
                if let runtimeActivityMessage = viewModel.runtimeActivityMessage {
                    activityBanner(text: runtimeActivityMessage)
                }

                if viewModel.catalogNodes.isEmpty {
                    emptyState
                } else {
                    StrategyBoardSection(
                        nodes: viewModel.visibleCatalogNodes,
                        visibleNodes: viewModel.filteredCatalogNodes,
                        searchText: $viewModel.nodeSearchText,
                        selectedID: viewModel.activeConfiguration?.stableID,
                        selectedMode: viewModel.selectedRuntimeMode,
                        sortMode: viewModel.nodeSortMode,
                        selectedLanguage: viewModel.selectedLanguage,
                        isRunningSpeedTest: viewModel.isRunningSpeedTest,
                        isApplyingRuntimeChange: viewModel.isApplyingRuntimeChange,
                        probingNodeIDs: viewModel.probingNodeIDs,
                        speedTestCompletedCount: viewModel.speedTestCompletedCount,
                        speedTestTotalCount: viewModel.speedTestTotalCount
                    ) { id in
                        viewModel.selectConfigurationFromNodeTap(id: id)
                    } onSelectMode: { mode in
                        viewModel.selectRuntimeMode(mode)
                    } onRunSpeedTest: {
                        viewModel.runSpeedTest()
                    } onSelectSortMode: { mode in
                        viewModel.setNodeSortMode(mode)
                    } onSetDefaultNode: { id in
                        viewModel.setDefaultNode(id: id)
                    } onRequestRenameNode: { node in
                        editingNodeID = node.stableID
                        draftNodeName = node.configuration.remark ?? node.configuration.host
                    } onDuplicateNode: { id in
                        viewModel.duplicateNode(id: id)
                    } onDeleteNode: { node in
                        pendingDeleteNode = node
                    } onMoveNodeUp: { id in
                        viewModel.moveNode(id: id, by: -1)
                    } onMoveNodeDown: { id in
                        viewModel.moveNode(id: id, by: 1)
                    }
                    .flowGatePanelCard()

                    strategyGroupsPanel
                }
            }
            .padding(CuspLayout.contentInset)
            .controlSize(.large)
        }
        .sheet(isPresented: $showAddStrategyGroupSheet) {
            addStrategyGroupSheet
        }
        .sheet(
            isPresented: Binding(
                get: { editingNodeID != nil },
                set: { if !$0 { editingNodeID = nil } }
            )
        ) {
            renameNodeSheet
        }
        .confirmationDialog(
            t("Delete this strategy group?", "确定删除该策略组？"),
            isPresented: Binding(
                get: { pendingDeleteStrategyGroup != nil },
                set: { if !$0 { pendingDeleteStrategyGroup = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(t("Delete", "删除"), role: .destructive) {
                guard let pendingDeleteStrategyGroup else {
                    return
                }
                viewModel.removeCustomStrategyGroup(id: pendingDeleteStrategyGroup.id)
                self.pendingDeleteStrategyGroup = nil
            }
            Button(t("Cancel", "取消"), role: .cancel) {
                pendingDeleteStrategyGroup = nil
            }
        } message: {
            Text(pendingDeleteStrategyGroup?.name ?? "")
        }
        .confirmationDialog(
            t("Delete this node?", "确定删除该节点？"),
            isPresented: Binding(
                get: { pendingDeleteNode != nil },
                set: { if !$0 { pendingDeleteNode = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(t("Delete", "删除"), role: .destructive) {
                guard let pendingDeleteNode else {
                    return
                }
                viewModel.deleteNode(id: pendingDeleteNode.stableID)
                self.pendingDeleteNode = nil
            }
            Button(t("Cancel", "取消"), role: .cancel) {
                pendingDeleteNode = nil
            }
        } message: {
            Text(nodeDisplayName(pendingDeleteNode))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("No nodes yet", "暂无节点"))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(CuspPalette.primaryText)
            Text(t("Import an `ss://` link or subscription from the Subscriptions page, then your nodes will appear here.",
                   "请在“订阅”页面导入 `ss://` 链接或订阅地址，策略将显示在这里。"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CuspPalette.secondaryText)
            Button(t("Open Subscriptions", "打开订阅")) {
                viewModel.selectedSection = .subscriptions
            }
            .flowGatePrimaryActionStyle()
        }
        .padding(CuspLayout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowGatePanelCard(padding: 0)
    }

    private func activityBanner(text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
        }
        .flowGateStatusBanner(color: CuspPalette.accent)
    }

    private var strategyGroupsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Strategy Groups", "策略组"))
                .font(CuspPalette.sectionTitleFont)
                .foregroundStyle(CuspPalette.sectionHeaderAccent)

            LazyVGrid(columns: strategyGroupColumns, spacing: 10) {
                ForEach(viewModel.customStrategyGroups, id: \.id) { group in
                    let isActive = normalizedGroupName(group.name) == viewModel.activeRuntimeProxyGroupName

                    Button {
                        viewModel.applyCustomStrategyGroup(id: group.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.strategyGroupCardTitle(group))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(CuspPalette.primaryText)
                                .lineLimit(1)
                            Text("\(t("Node", "节点")): \(viewModel.strategyGroupResolvedNodeSummary(for: group.id))")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                                .foregroundStyle(CuspPalette.secondaryText)
                                .lineLimit(1)
                            Text("\(t("Reason", "依据")): \(viewModel.strategyGroupDecisionSummary(for: group.id))")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(CuspPalette.tertiaryText)
                                .lineLimit(1)
                            Text("\(t("Latest", "最近切换")): \(viewModel.strategyGroupLatestSwitchSummary(for: group.id))")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(CuspPalette.tertiaryText.opacity(0.95))
                                .lineLimit(1)
                            if isActive {
                                Text(t("Active", "已生效"))
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .flowGateSemanticCapsule(.success)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
                        .background(isActive ? CuspPalette.accent.opacity(0.12) : CuspPalette.raisedCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                                .stroke(isActive ? CuspPalette.accentBright.opacity(0.45) : CuspPalette.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(t("Edit Strategy Group…", "编辑策略组…")) {
                            editingStrategyGroupID = group.id
                            draftStrategyType = group.type
                            draftStrategyName = group.name
                            draftStrategySourceID = group.sourceID
                            draftTestURL = group.testURL ?? "https://www.gstatic.com/generate_204"
                            draftIntervalSecondsText = "\(group.intervalSeconds ?? 300)"
                            addStrategyStep = .configure
                            showAddStrategyGroupSheet = true
                        }

                        Button(t("Duplicate", "创建副本")) {
                            viewModel.duplicateCustomStrategyGroup(id: group.id)
                        }

                        Button(role: .destructive) {
                            pendingDeleteStrategyGroup = group
                        } label: {
                            Text(t("Delete Strategy Group…", "删除策略组…"))
                        }

                        Divider()

                        Button(t("Run Latency Test", "延迟测试")) {
                            viewModel.runSpeedTest()
                        }

                        let sourceNodes = viewModel.catalogNodes.filter { $0.sourceID == group.sourceID }
                        if !sourceNodes.isEmpty {
                            Divider()
                        }
                        if viewModel.isManualCustomStrategyGroup(id: group.id) {
                            ForEach(NodeLatencyProbe.sortForDisplay(sourceNodes), id: \.stableID) { node in
                                Button {
                                    viewModel.setPreferredNodeForCustomStrategyGroup(id: group.id, nodeID: node.stableID)
                                    viewModel.applyCustomStrategyGroup(id: group.id)
                                } label: {
                                    HStack {
                                        if group.preferredNodeID == node.stableID {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(menuNodeTitle(node))
                                    }
                                }
                            }
                        } else {
                            Button(t("Node selection is automatic for this strategy group.", "该策略组节点由策略自动选择。")) {}
                                .disabled(true)
                        }
                    }
                }

                Button {
                    editingStrategyGroupID = nil
                    addStrategyStep = .selectType
                    draftStrategyType = .manual
                    draftStrategyName = ""
                    draftStrategySourceID = viewModel.selectedSourceFilterID ?? enabledSources.first?.id
                    draftTestURL = "https://www.gstatic.com/generate_204"
                    draftIntervalSecondsText = "300"
                    showAddStrategyGroupSheet = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(CuspPalette.secondaryText)
                        Text(t("Add Group", "添加策略组"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(CuspPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 102)
                .background(
                    RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                        .fill(CuspPalette.raisedCardFill.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                        .stroke(CuspPalette.hairline, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
        }
        .flowGatePanelCard()
    }

    private var addStrategyGroupSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Strategy Group", "策略组"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            if addStrategyStep == .selectType {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CustomStrategyGroupType.allCases) { type in
                        Button {
                            draftStrategyType = type
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: draftStrategyType == type ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(draftStrategyType == type ? CuspPalette.accentBright : CuspPalette.tertiaryText)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.displayName(for: type))
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(CuspPalette.primaryText)
                                    Text(viewModel.strategyTypeDescription(type))
                                        .font(.system(.callout, design: .rounded))
                                        .foregroundStyle(CuspPalette.secondaryText)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(t("Type", "类型"))
                            .foregroundStyle(CuspPalette.secondaryText)
                        Text(viewModel.displayName(for: draftStrategyType))
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .font(.system(.callout, design: .rounded))

                    TextField(t("Group Name", "策略组名称"), text: $draftStrategyName)
                        .flowGateFilledInputField()

                    Picker(t("Source", "来源"), selection: Binding(
                        get: { draftStrategySourceID ?? "" },
                        set: { draftStrategySourceID = $0.isEmpty ? nil : $0 }
                    )) {
                        ForEach(enabledSources, id: \.id) { source in
                            Text(viewModel.strategyGroupTitle(for: source)).tag(source.id)
                        }
                    }

                    if draftStrategyType != .manual {
                        TextField("Test URL", text: $draftTestURL)
                            .flowGateFilledInputField()
                        TextField(t("Interval (seconds)", "检测间隔（秒）"), text: $draftIntervalSecondsText)
                            .flowGateFilledInputField()
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button(t("Cancel", "取消")) {
                    editingStrategyGroupID = nil
                    showAddStrategyGroupSheet = false
                }
                .flowGateSecondaryActionStyle()
                if addStrategyStep == .selectType {
                    Button(t("Next", "下一步")) {
                        if draftStrategyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draftStrategyName = viewModel.displayName(for: draftStrategyType)
                        }
                        if draftStrategySourceID == nil {
                            draftStrategySourceID = viewModel.selectedSourceFilterID ?? enabledSources.first?.id
                        }
                        if draftTestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draftTestURL = "https://www.gstatic.com/generate_204"
                        }
                        if Int(draftIntervalSecondsText) == nil {
                            draftIntervalSecondsText = "300"
                        }
                        addStrategyStep = .configure
                    }
                    .flowGatePrimaryActionStyle()
                    .disabled(enabledSources.isEmpty)
                } else {
                    Button(t("Back", "上一步")) {
                        addStrategyStep = .selectType
                    }
                    .flowGateSecondaryActionStyle()
                    Button(editingStrategyGroupID == nil ? t("Create", "创建") : t("Save", "保存")) {
                        guard let sourceID = draftStrategySourceID else {
                            return
                        }
                        if let editingStrategyGroupID {
                            viewModel.updateCustomStrategyGroup(
                                id: editingStrategyGroupID,
                                name: draftStrategyName,
                                type: draftStrategyType,
                                sourceID: sourceID,
                                testURL: strategyTestURL,
                                intervalSeconds: strategyIntervalSeconds
                            )
                        } else {
                            viewModel.createCustomStrategyGroup(
                                name: draftStrategyName,
                                type: draftStrategyType,
                                sourceID: sourceID,
                                testURL: strategyTestURL,
                                intervalSeconds: strategyIntervalSeconds
                            )
                        }
                        editingStrategyGroupID = nil
                        showAddStrategyGroupSheet = false
                    }
                    .flowGatePrimaryActionStyle()
                    .disabled(draftStrategySourceID == nil)
                }
            }
        }
        .padding(22)
        .frame(width: 620, height: 460, alignment: .topLeading)
        .background(CuspPalette.cardFill)
        .controlSize(.large)
    }

    private var renameNodeSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Rename Node", "重命名节点"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(CuspPalette.primaryText)
            TextField(t("Node name", "节点名称"), text: $draftNodeName)
                .flowGateFilledInputField()

            HStack(spacing: 10) {
                Spacer()
                Button(t("Cancel", "取消")) {
                    editingNodeID = nil
                }
                .flowGateSecondaryActionStyle()
                Button(t("Save", "保存")) {
                    if let editingNodeID {
                        viewModel.renameNode(id: editingNodeID, to: draftNodeName)
                    }
                    editingNodeID = nil
                }
                .flowGatePrimaryActionStyle()
            }
        }
        .padding(22)
        .frame(width: 420, height: 190, alignment: .topLeading)
        .background(CuspPalette.cardFill)
        .controlSize(.large)
    }

    private var strategyTestURL: String? {
        guard draftStrategyType != .manual else {
            return nil
        }
        let trimmed = draftTestURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var strategyIntervalSeconds: Int? {
        guard draftStrategyType != .manual else {
            return nil
        }
        guard let value = Int(draftIntervalSecondsText) else {
            return nil
        }
        return min(max(value, 10), 86400)
    }

    private func menuNodeTitle(_ node: CatalogNode) -> String {
        let name = node.configuration.remark ?? node.configuration.host
        let status: String
        switch node.probeStatus {
        case .success:
            status = node.latestLatencyMs.map { "\($0)ms" } ?? "--"
        case .failure:
            status = t("failed", "失败")
        case .timeout:
            status = t("timeout", "超时")
        case .idle:
            status = "--"
        }
        return "\(name) · \(status)"
    }

    private func normalizedGroupName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func nodeDisplayName(_ node: CatalogNode?) -> String {
        guard let node else {
            return ""
        }
        let remark = node.configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty {
            return remark
        }
        return node.configuration.host
    }
}
