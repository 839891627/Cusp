import SwiftUI

struct AppShellView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            CuspPalette.windowBackground
                .ignoresSafeArea()

            CuspPalette.ambientHighlight
                .ignoresSafeArea()

            HStack(spacing: CuspLayout.shellSpacing) {
                sidebar
                    .frame(width: 218)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(CuspLayout.shellPadding)
        }
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cusp")
                    .font(CuspPalette.pageTitleFont)
                    .foregroundStyle(CuspPalette.primaryText)
                Text(viewModel.localizedConnectionStateTitle(viewModel.connectionState))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(AppSection.allCases) { section in
                    sidebarItem(for: section)
                }
            }

            Spacer()
        }
        .padding(CuspLayout.panelPadding)
        .background(CuspPalette.sidebarFill)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CuspPalette.hairline, lineWidth: 1)
        )
    }

    private var content: some View {
        Group {
            switch viewModel.selectedSection {
            case .overview:
                HomeView(viewModel: viewModel)
            case .processes:
                ProcessesView(viewModel: viewModel)
            case .nodes:
                NodesView(viewModel: viewModel)
            case .rules:
                RulesView(viewModel: viewModel)
            case .subscriptions:
                SubscriptionsView(viewModel: viewModel)
            case .logs:
                LogsView(viewModel: viewModel)
            case .settings:
                SettingsView(viewModel: viewModel)
            }
        }
        .padding(CuspLayout.shellPadding)
        .background(CuspPalette.contentFill)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CuspPalette.hairline.opacity(0.9), lineWidth: 1)
        )
    }

    private func sidebarItem(for section: AppSection) -> some View {
        let isSelected = viewModel.selectedSection == section

        return Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)

                Text(section.title(language: viewModel.selectedLanguage))
                    .font(.system(.body, design: .rounded, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(CuspPalette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                    .fill(isSelected ? CuspPalette.selectionFill : CuspPalette.sidebarItemFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                    .stroke(isSelected ? CuspPalette.selectionStroke : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return CuspPalette.success
        case .connecting, .disconnecting:
            return CuspPalette.warning
        case .disconnected:
            return CuspPalette.idle
        case .invalid:
            return CuspPalette.error
        }
    }
}

private struct ProcessesView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var showUnknownOnly = false
    @State private var selectedRouteFilter: ProcessRouteFilter = .all

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private var pageHeaderFont: Font {
        .system(size: 28, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    private var visibleEntries: [ProcessTrafficEntry] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.processTrafficEntries.filter { entry in
            guard routeMatchesFilter(entry.routing) else {
                return false
            }
            if showUnknownOnly {
                guard case .unknown = entry.routing else {
                    return false
                }
            }
            guard !keyword.isEmpty else {
                return true
            }
            if routeTitle(entry.routing).lowercased().contains(keyword) {
                return true
            }
            switch entry.routing {
            case .proxy(let chain):
                return chain.lowercased().contains(keyword)
            case .direct, .reject, .unknown:
                return false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CuspLayout.sectionSpacing) {
                header
                controls
                processListCard
            }
            .padding(CuspLayout.contentInset)
            .controlSize(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Connection Routes", "连接路由"))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
            Text(t("Inspect and manage active connection routes and traffic.", "查看并管理活跃连接路由与流量。"))
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(CuspPalette.secondaryText)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(t("Search route or proxy chain", "搜索路由或代理链路"), text: $searchText)
                .flowGateFilledInputField()
            HStack(spacing: 10) {
                Picker(t("Route", "路由"), selection: $selectedRouteFilter) {
                    ForEach(ProcessRouteFilter.allCases, id: \.rawValue) { filter in
                        Text(routeFilterTitle(filter)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $showUnknownOnly) {
                    Text(t("Unknown only", "仅未知路由"))
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(CuspPalette.secondaryText)
                }
                .toggleStyle(.switch)
                Button(t("Refresh", "刷新")) {
                    viewModel.refreshProcessTrafficNow()
                }
                .flowGateSecondaryActionStyle()
            }
        }
    }

    private var processListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Active Connection Routes", "活跃连接路由"))
                    .font(CuspPalette.sectionTitleFont)
                    .foregroundStyle(CuspPalette.primaryText)
                Spacer()
                Text("\(visibleEntries.count)")
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .foregroundStyle(CuspPalette.tertiaryText)
            }

            if visibleEntries.isEmpty {
                Text(t("No routes under current filter.", "当前筛选下暂无路由连接。"))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(CuspPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(CuspPalette.raisedCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous))
            } else {
                ForEach(visibleEntries) { entry in
                    processEntryRow(entry)
                }
            }
        }
        .flowGatePanelCard()
    }

    private func processEntryRow(_ entry: ProcessTrafficEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routeTitle(entry.routing))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CuspPalette.primaryText)
                Text(t("\(entry.activeConnections) active", "\(entry.activeConnections) 个连接"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CuspPalette.tertiaryText)
                if case .unknown = entry.routing, entry.metadataSummary != nil {
                    Button(t("Copy metadata", "复制 metadata")) {
                        viewModel.copyProcessMetadataToClipboard(entryID: entry.id)
                    }
                    .flowGateSecondaryActionStyle()
                }
            }
            Spacer()
            routeBadge(for: entry.routing)
            VStack(alignment: .trailing, spacing: 3) {
                Text(t("Total ↓ ", "累计↓ ") + byteCountString(entry.downloadBytes))
                Text(t("Total ↑ ", "累计↑ ") + byteCountString(entry.uploadBytes))
                Text(t("Rate ↓ ", "速率↓ ") + rateString(entry.downloadBytesPerSecond))
                    .foregroundStyle(CuspPalette.secondaryText)
                Text(t("Rate ↑ ", "速率↑ ") + rateString(entry.uploadBytesPerSecond))
                    .foregroundStyle(CuspPalette.secondaryText)
                Text("Σ \(byteCountString(entry.totalBytes))")
                    .foregroundStyle(CuspPalette.tertiaryText)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(CuspPalette.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CuspPalette.raisedCardFill.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func routeBadge(for routing: ProcessRoutingType) -> some View {
        let text: String
        let tint: Color
        switch routing {
        case .direct:
            text = t("Direct", "直连")
            tint = CuspPalette.success
        case .proxy(let chain):
            text = t("Proxy", "代理") + " · " + chain
            tint = CuspPalette.accentBright
        case .reject:
            text = t("Reject", "拒绝")
            tint = CuspPalette.error
        case .unknown:
            text = t("Unknown", "未知")
            tint = CuspPalette.secondaryText
        }
        return Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func byteCountString(_ bytes: UInt64) -> String {
        Self.processByteFormatter.string(fromByteCount: Int64(bytes))
    }

    private func rateString(_ bytesPerSecond: Double) -> String {
        "\(Self.processByteFormatter.string(fromByteCount: Int64(max(0, bytesPerSecond))))/s"
    }

    private func routeFilterTitle(_ filter: ProcessRouteFilter) -> String {
        switch filter {
        case .all:
            return t("All", "全部")
        case .direct:
            return t("Direct", "直连")
        case .proxy:
            return t("Proxy", "代理")
        case .reject:
            return t("Reject", "拒绝")
        case .unknown:
            return t("Unknown", "未知")
        }
    }

    private func routeTitle(_ routing: ProcessRoutingType) -> String {
        switch routing {
        case .direct:
            return t("Direct Route", "直连路由")
        case .proxy(let chain):
            return t("Proxy Route", "代理路由") + " · " + chain
        case .reject:
            return t("Rejected Route", "拒绝路由")
        case .unknown:
            return t("Unknown Route", "未知路由")
        }
    }

    private func routeMatchesFilter(_ routing: ProcessRoutingType) -> Bool {
        switch selectedRouteFilter {
        case .all:
            return true
        case .direct:
            if case .direct = routing { return true }
            return false
        case .proxy:
            if case .proxy = routing { return true }
            return false
        case .reject:
            if case .reject = routing { return true }
            return false
        case .unknown:
            if case .unknown = routing { return true }
            return false
        }
    }

    private static let processByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private enum ProcessRouteFilter: String, CaseIterable {
        case all
        case direct
        case proxy
        case reject
        case unknown
    }
}

private struct LogsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedLevel: AppLogLevel?

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private var pageHeaderFont: Font {
        .system(size: 32, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    private var filteredEntries: [AppLogEntry] {
        let entries = viewModel.logEntries
        guard let selectedLevel else {
            return Array(entries.reversed())
        }

        return Array(entries.filter { $0.level == selectedLevel }.reversed())
    }

    private var errorCount: Int {
        viewModel.logEntries.filter { $0.level == .error }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CuspLayout.sectionSpacing) {
                header
                summaryRow
                controlBar
                logsPanel
            }
            .padding(CuspLayout.contentInset)
            .controlSize(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Logs", "日志"))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 14) {
            metricCard(title: t("Total", "总计"), value: "\(viewModel.logEntries.count)")
            metricCard(title: t("Errors", "错误"), value: "\(errorCount)")
            metricCard(title: t("Visible", "当前可见"), value: "\(filteredEntries.count)")
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Picker(t("Level", "级别"), selection: $selectedLevel) {
                Text(t("All", "全部")).tag(AppLogLevel?.none)
                ForEach(AppLogLevel.allCases, id: \.self) { level in
                    Text(levelTitle(level)).tag(Optional(level))
                }
            }
            .pickerStyle(.segmented)

            Button(t("Copy Logs", "复制日志")) {
                viewModel.copyLogsToClipboard()
            }
            .flowGateSecondaryActionStyle()

            Button(t("Clear Logs", "清空日志")) {
                viewModel.clearLogs()
            }
            .flowGateDangerActionStyle()
            .disabled(viewModel.logEntries.isEmpty)
        }
    }

    private var logsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filteredEntries.isEmpty {
                Text(t("No logs in this filter yet.", "当前筛选下暂无日志。"))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(CuspPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(CuspPalette.raisedCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(filteredEntries) { entry in
                    logRow(entry)
                }
            }
        }
        .flowGatePanelCard()
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(CuspPalette.metricLabelFont)
                .foregroundStyle(CuspPalette.tertiaryText)
            Text(value)
                .font(CuspPalette.metricValueFont)
                .monospacedDigit()
                .foregroundStyle(CuspPalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CuspPalette.raisedCardFill)
        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func logRow(_ entry: AppLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(levelTitle(entry.level))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .flowGateSemanticCapsule(levelTone(entry.level))

                Text(entry.category.uppercased())
                    .font(CuspPalette.metricLabelFont)
                    .foregroundStyle(CuspPalette.tertiaryText)

                Spacer()

                Text(Self.logTimeFormatter.string(from: entry.timestamp))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(CuspPalette.tertiaryText)
            }

            Text(entry.message)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(CuspPalette.primaryText)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CuspPalette.raisedCardFill.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func levelTitle(_ level: AppLogLevel) -> String {
        switch level {
        case .info:
            return t("INFO", "信息")
        case .success:
            return t("SUCCESS", "成功")
        case .error:
            return t("ERROR", "错误")
        }
    }

    private func levelTone(_ level: AppLogLevel) -> CuspSemanticTone {
        switch level {
        case .info:
            return .info
        case .success:
            return .success
        case .error:
            return .danger
        }
    }

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct RulesView: View {
    @ObservedObject var viewModel: AppViewModel

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private var pageHeaderFont: Font {
        .system(size: 28, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CuspLayout.sectionSpacing) {
                header
                editorCard
                listCard
            }
            .padding(CuspLayout.contentInset)
            .controlSize(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Rules", "规则"))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Picker(t("Type", "类型"), selection: $viewModel.selectedRuleType) {
                    ForEach(RoutingRuleType.allCases, id: \.self) { type in
                        Text(viewModel.displayName(for: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                Picker(t("Action", "动作"), selection: $viewModel.selectedRuleAction) {
                    ForEach(RoutingRuleAction.allCases, id: \.self) { action in
                        Text(viewModel.displayName(for: action)).tag(action)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 8) {
                TextField(t("Matcher, for example google.com / CN / 192.168.0.0/16",
                            "匹配值，例如 google.com / CN / 192.168.0.0/16"), text: $viewModel.ruleMatcherInput)
                    .flowGateFilledInputField()

                Button(t("Add Rule", "添加规则")) {
                    viewModel.addRoutingRule()
                }
                .flowGatePrimaryActionStyle()
            }
        }
        .flowGatePanelCard()
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Rule List", "规则列表"))
                    .font(CuspPalette.sectionTitleFont)
                    .foregroundStyle(CuspPalette.primaryText)
                Spacer()
                Menu(t("Templates", "模板")) {
                    ForEach(RuleTemplateKind.allCases) { template in
                        Button(viewModel.displayName(for: template)) {
                            viewModel.applyRuleTemplate(template)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                Button(t("Import Rules", "导入规则")) {
                    viewModel.importRulesFromFile()
                }
                .flowGateSecondaryActionStyle()
                Menu {
                    Button(t("Export YAML", "导出 YAML")) {
                        viewModel.exportRules(asYAML: true)
                    }
                    Button(t("Export CONF", "导出 CONF")) {
                        viewModel.exportRules(asYAML: false)
                    }
                } label: {
                    Label(t("Export", "导出"), systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                Button(t("Reset to Preset", "重置为预设")) {
                    viewModel.resetRoutingRulesToPreset()
                }
                .flowGateSecondaryActionStyle()
            }

            if viewModel.routingRules.isEmpty {
                Text(t("No rules configured.", "暂无规则。"))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(CuspPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(CuspPalette.raisedCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: CuspLayout.compactCornerRadius, style: .continuous))
            } else {
                ForEach(Array(viewModel.routingRules.enumerated()), id: \.element.id) { index, rule in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(.callout, design: .monospaced, weight: .bold))
                            .foregroundStyle(CuspPalette.tertiaryText)
                            .frame(width: 28)

                        Text(rule.type.rawValue)
                            .font(.system(.callout, design: .monospaced, weight: .semibold))
                            .foregroundStyle(CuspPalette.primaryText)
                            .frame(width: 120, alignment: .leading)

                        Text(rule.matcher)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(CuspPalette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(viewModel.displayName(for: rule.action))
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(CuspPalette.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CuspPalette.pillFill)
                            .clipShape(Capsule())

                        Button {
                            viewModel.moveRoutingRule(id: rule.id, by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .flowGateSecondaryActionStyle()
                        .disabled(index == 0)

                        Button {
                            viewModel.moveRoutingRule(id: rule.id, by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .flowGateSecondaryActionStyle()
                        .disabled(index == viewModel.routingRules.count - 1)

                        Button(t("Delete", "删除")) {
                            viewModel.removeRoutingRule(id: rule.id)
                        }
                        .flowGateDangerActionStyle()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .flowGatePanelCard()
    }
}

enum CuspPalette {
    static let pageTitleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let sectionTitleFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let panelCornerRadius: CGFloat = 24
    static let panelStroke = Color.white.opacity(0.11)
    static let metricLabelFont = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let metricValueFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let metricValueMonoFont = Font.system(size: 15, weight: .semibold, design: .monospaced)
    static let sectionHeaderAccent = Color(red: 0.58, green: 0.80, blue: 0.98)
    static let controlHeight: CGFloat = 38
    static let inputFieldHeight: CGFloat = 42
    static let primaryButtonTint = accent
    static let secondaryButtonTint = accentBright
    static let dangerButtonTint = error

    static let primaryText = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let secondaryText = Color(red: 0.82, green: 0.89, blue: 0.95)
    static let tertiaryText = Color(red: 0.68, green: 0.77, blue: 0.86)

    static let idle = Color(red: 0.72, green: 0.80, blue: 0.88)
    static let success = Color(red: 0.20, green: 0.84, blue: 0.48)
    static let successBright = Color(red: 0.43, green: 0.94, blue: 0.62)
    static let warning = Color(red: 0.99, green: 0.66, blue: 0.18)
    static let warningBright = Color(red: 1.00, green: 0.79, blue: 0.38)
    static let error = Color(red: 0.97, green: 0.32, blue: 0.30)
    static let errorBright = Color(red: 1.00, green: 0.53, blue: 0.46)
    static let accent = Color(red: 0.24, green: 0.66, blue: 0.86)
    static let accentBright = Color(red: 0.40, green: 0.76, blue: 0.94)

    static let hairline = Color.white.opacity(0.18)
    static let pillFill = Color(red: 0.17, green: 0.28, blue: 0.38).opacity(0.68)
    static let sidebarItemFill = Color(red: 0.12, green: 0.21, blue: 0.30).opacity(0.52)
    static let sidebarFill = Color(red: 0.03, green: 0.09, blue: 0.15).opacity(0.90)
    static let sidebarCardFill = Color(red: 0.08, green: 0.19, blue: 0.28).opacity(0.84)
    static let contentFill = Color(red: 0.07, green: 0.15, blue: 0.23).opacity(0.84)
    static let cardFill = Color(red: 0.09, green: 0.18, blue: 0.26).opacity(0.76)
    static let raisedCardFill = Color(red: 0.13, green: 0.25, blue: 0.35).opacity(0.88)
    static let inputFill = Color(red: 0.16, green: 0.30, blue: 0.42).opacity(0.90)
    static let selectionFill = Color(red: 0.16, green: 0.38, blue: 0.53).opacity(0.95)
    static let selectionStroke = accentBright.opacity(0.38)

    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.09, blue: 0.14),
            Color(red: 0.05, green: 0.13, blue: 0.20),
            Color(red: 0.06, green: 0.12, blue: 0.19)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambientHighlight = RadialGradient(
        colors: [
            success.opacity(0.12),
            accent.opacity(0.12),
            .clear
        ],
        center: .topTrailing,
        startRadius: 30,
        endRadius: 520
    )
}

enum CuspLayout {
    static let shellPadding: CGFloat = 20
    static let shellSpacing: CGFloat = 20
    static let contentInset: CGFloat = 8
    static let sectionSpacing: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let nestedCornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 14
    static let inputCornerRadius: CGFloat = 14
    static let inputHorizontalPadding: CGFloat = 12
}

enum CuspSemanticTone {
    case neutral
    case info
    case success
    case warning
    case danger
}

extension View {
    func flowGatePrimaryActionStyle() -> some View {
        buttonStyle(.borderedProminent)
            .tint(CuspPalette.primaryButtonTint)
            .controlSize(.large)
    }

    func flowGateSecondaryActionStyle() -> some View {
        buttonStyle(.bordered)
            .tint(CuspPalette.secondaryButtonTint)
            .controlSize(.large)
    }

    func flowGateDangerActionStyle() -> some View {
        buttonStyle(.bordered)
            .tint(CuspPalette.dangerButtonTint)
            .controlSize(.large)
    }

    func flowGateSemanticCapsule(_ tone: CuspSemanticTone) -> some View {
        self
            .foregroundStyle(flowGateSemanticForeground(tone))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(flowGateSemanticBackground(tone))
            .clipShape(Capsule())
    }

    func flowGatePanelCard(padding: CGFloat = CuspLayout.panelPadding) -> some View {
        self
            .padding(padding)
            .background(CuspPalette.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: CuspPalette.panelCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CuspPalette.panelCornerRadius, style: .continuous)
                    .stroke(CuspPalette.panelStroke, lineWidth: 1)
            )
    }

    func flowGateFilledInputField(cornerRadius: CGFloat = CuspLayout.inputCornerRadius) -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, CuspLayout.inputHorizontalPadding)
            .frame(height: CuspPalette.inputFieldHeight)
            .background(CuspPalette.inputFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func flowGateStatusBanner(color: Color) -> some View {
        self
            .font(.system(.callout, design: .rounded, weight: .medium))
            .foregroundStyle(CuspPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                    .stroke(color.opacity(0.36), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
    }

    private func flowGateSemanticForeground(_ tone: CuspSemanticTone) -> Color {
        switch tone {
        case .neutral:
            return CuspPalette.idle
        case .info:
            return CuspPalette.accentBright
        case .success:
            return CuspPalette.success
        case .warning:
            return CuspPalette.warning
        case .danger:
            return CuspPalette.error
        }
    }

    private func flowGateSemanticBackground(_ tone: CuspSemanticTone) -> Color {
        switch tone {
        case .neutral:
            return CuspPalette.idle.opacity(0.16)
        case .info:
            return CuspPalette.accentBright.opacity(0.16)
        case .success:
            return CuspPalette.success.opacity(0.16)
        case .warning:
            return CuspPalette.warning.opacity(0.16)
        case .danger:
            return CuspPalette.error.opacity(0.16)
        }
    }
}
