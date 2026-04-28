import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    private let sectionSpacing: CGFloat = CuspLayout.sectionSpacing
    private let cardSpacing: CGFloat = 14
    private let cardPadding: CGFloat = CuspLayout.panelPadding
    private let toggleRowMinHeight: CGFloat = 38
    private let controlsGroupTopSpacing: CGFloat = 2

    private var pageHeaderFont: Font {
        .system(size: 28, weight: viewModel.selectedLanguage == .simplifiedChinese ? .bold : .semibold, design: .rounded)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                header
                languageCard
                subscriptionRefreshCard

                runtimeCard
                runtimeLogCard
                systemIntegrationCard
            }
            .padding(CuspLayout.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.text(.settings))
                .font(pageHeaderFont)
                .foregroundStyle(CuspPalette.primaryText)
        }
    }

    private var languageCard: some View {
        settingsCard(title: viewModel.text(.language)) {
            Picker(viewModel.text(.language), selection: $viewModel.selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(viewModel.languageDisplayName(language)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, controlsGroupTopSpacing)
        }
    }

    private var subscriptionRefreshCard: some View {
        settingsCard(title: viewModel.selectedLanguage == .simplifiedChinese ? "订阅刷新" : "Subscription Refresh") {
            Picker(
                viewModel.selectedLanguage == .simplifiedChinese ? "刷新周期" : "Refresh Interval",
                selection: $viewModel.selectedSubscriptionRefreshInterval
            ) {
                ForEach(SubscriptionRefreshInterval.allCases) { interval in
                    Text(viewModel.displayName(for: interval)).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, controlsGroupTopSpacing)
        }
    }

    private var runtimeCard: some View {
        settingsCard(title: viewModel.text(.runtimeStatus)) {
            HStack(spacing: 14) {
                infoMetric(title: viewModel.text(.connection), value: viewModel.localizedConnectionStateTitle(viewModel.connectionState))
                infoMetric(title: viewModel.text(.readiness), value: viewModel.readinessReport.statusTitle)
                infoMetric(title: viewModel.text(.savedNodes), value: "\(viewModel.availableConfigurations.count)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var systemIntegrationCard: some View {
        settingsCard(title: viewModel.selectedLanguage == .simplifiedChinese ? "系统集成" : "System Integration") {
            VStack(alignment: .leading, spacing: 0) {
                settingsToggleRow(
                    title: viewModel.selectedLanguage == .simplifiedChinese ? "登录时自动启动" : "Launch at login",
                    isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: { viewModel.setLaunchAtLoginEnabled($0) }
                    )
                )
                rowDivider()

                settingsToggleRow(
                    title: viewModel.selectedLanguage == .simplifiedChinese ? "启动时恢复连接" : "Restore connection on launch",
                    isOn: Binding(
                        get: { viewModel.restoreConnectionOnLaunchEnabled },
                        set: { viewModel.setRestoreConnectionOnLaunchEnabled($0) }
                    )
                )
                rowDivider()

                settingsToggleRow(
                    title: viewModel.selectedLanguage == .simplifiedChinese ? "系统通知" : "System notifications",
                    isOn: Binding(
                        get: { viewModel.notificationEnabled },
                        set: { viewModel.setNotificationEnabled($0) }
                    )
                )
                rowDivider()

                settingsToggleRow(
                    title: viewModel.selectedLanguage == .simplifiedChinese ? "检测到其他 VPN 时自动断开" : "Auto disconnect when other VPN is active",
                    isOn: Binding(
                        get: { viewModel.disconnectWhenOtherVPNActiveEnabled },
                        set: { viewModel.setDisconnectWhenOtherVPNActiveEnabled($0) }
                    )
                )
            }
            .padding(.top, controlsGroupTopSpacing)
        }
    }

    private var runtimeLogCard: some View {
        settingsCard(title: viewModel.selectedLanguage == .simplifiedChinese ? "运行时日志聚合" : "Runtime Log Aggregation") {
            Picker(
                viewModel.selectedLanguage == .simplifiedChinese ? "FSM 重复日志聚合窗口" : "FSM Duplicate Log Aggregation Window",
                selection: $viewModel.selectedRuntimeFSMLogAggregationWindow
            ) {
                ForEach(RuntimeFSMLogAggregationWindow.allCases) { window in
                    Text(viewModel.displayName(for: window)).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, controlsGroupTopSpacing)
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            Text(title)
                .font(CuspPalette.sectionTitleFont)
                .foregroundStyle(CuspPalette.primaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowGatePanelCard(padding: cardPadding)
    }

    private func settingsToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(CuspPalette.primaryText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)

            Spacer(minLength: 10)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .frame(width: 54, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: toggleRowMinHeight, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func rowDivider() -> some View {
        Divider()
            .overlay(CuspPalette.panelStroke.opacity(0.9))
    }

    private func infoMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
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
        .frame(minHeight: 74)
    }
}
