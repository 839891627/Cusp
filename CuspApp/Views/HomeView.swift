import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel
    private let topSectionSpacing: CGFloat = 12
    private let overviewGridSpacing: CGFloat = 8
    private let overviewCardMinHeight: CGFloat = 66

    private var isChinese: Bool {
        viewModel.selectedLanguage == .simplifiedChinese
    }

    private var pageHeaderFont: Font {
        .system(size: 32, weight: isChinese ? .bold : .semibold, design: .rounded)
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private var visualState: ConnectionVisualState {
        switch viewModel.connectionState {
        case .connected:
            return ConnectionVisualState(
                buttonTitle: t("Disconnect", "断开连接"),
                symbolName: "bolt.horizontal.fill",
                gradientColors: [CuspPalette.success, CuspPalette.successBright],
                shadowColor: CuspPalette.success.opacity(0.34)
            )
        case .connecting, .disconnecting:
            return ConnectionVisualState(
                buttonTitle: viewModel.connectionState == .connecting ? t("Connecting", "连接中") : t("Stopping", "停止中"),
                symbolName: "sparkle",
                gradientColors: [CuspPalette.warning, CuspPalette.warningBright],
                shadowColor: CuspPalette.warning.opacity(0.30)
            )
        case .disconnected, .invalid:
            return ConnectionVisualState(
                buttonTitle: t("Connect", "连接"),
                symbolName: "power",
                gradientColors: [CuspPalette.accent.opacity(0.88), CuspPalette.accentBright.opacity(0.86)],
                shadowColor: CuspPalette.accent.opacity(0.24)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CuspLayout.sectionSpacing) {
                header

                topPanel

                trafficPanel

                if let action = viewModel.lastActionMessage {
                    messageBanner(text: action, color: CuspPalette.success)
                }

                if let error = viewModel.lastErrorMessage {
                    messageBanner(text: error, color: CuspPalette.error)
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(CuspLayout.contentInset)
            .frame(maxWidth: .infinity, alignment: .center)
            .controlSize(.large)
        }
    }

    private var topPanel: some View {
        GeometryReader { proxy in
            let buttonSize = overviewButtonSize(for: proxy.size.width)
            let gridHeight = overviewGridHeight
            HStack(alignment: .top, spacing: topSectionSpacing) {
                ConnectButton(
                    state: visualState,
                    isEnabled: viewModel.isConnectButtonEnabled,
                    size: buttonSize
                ) {
                    viewModel.toggleConnection()
                }

                overviewMetricGrid
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: max(buttonSize, gridHeight), alignment: .topLeading)
        }
        .frame(height: overviewTopSectionHeight)
        .flowGatePanelCard()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Overview", "总览"))
                    .font(pageHeaderFont)
                    .foregroundStyle(CuspPalette.primaryText)
            }

            Spacer()
        }
    }

    private var overviewMetricGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: overviewGridSpacing), count: 3)
        return LazyVGrid(columns: columns, spacing: overviewGridSpacing) {
            metricCard(
                title: t("Connection", "连接状态"),
                value: viewModel.localizedConnectionStateTitle(viewModel.connectionState),
                tint: connectionTint
            )
            metricCard(
                title: t("Mode", "出站模式"),
                value: modeTitle,
                tint: CuspPalette.accentBright
            )
            metricCard(
                title: t("Current Node", "当前节点"),
                value: viewModel.selectedNodeDisplayName,
                tint: CuspPalette.primaryText,
                monospaced: false
            )
            metricCard(
                title: t("Latency", "延迟"),
                value: viewModel.latencyText,
                tint: CuspPalette.warning
            )
            metricCard(
                title: t("IP Address", "IP 地址"),
                value: viewModel.ipAddressText,
                tint: CuspPalette.success
            )
            metricCard(
                title: t("Traffic", "上下行"),
                value: "\(viewModel.downloadRateText) / \(viewModel.uploadRateText)",
                tint: CuspPalette.secondaryText
            )
        }
    }

    private var trafficPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Traffic", "流量"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CuspPalette.primaryText)
                Spacer()
                Button(t("Reset", "重置")) {
                    viewModel.resetTrafficStatistics()
                }
                .flowGateSecondaryActionStyle()
            }

            HStack(spacing: 10) {
                summaryPill(title: t("Download", "下载"), value: viewModel.downloadRateText)
                summaryPill(title: t("Upload", "上传"), value: viewModel.uploadRateText)
                summaryPill(title: t("Session", "本次会话"), value: "\(viewModel.sessionDownloadText) / \(viewModel.sessionUploadText)")
            }

            HStack(spacing: 10) {
                summaryPill(title: t("Today", "今日"), value: viewModel.todayTotalText)
                summaryPill(title: t("Monthly", "本月"), value: viewModel.monthlyTotalText)
            }

            if !viewModel.trafficSamples.isEmpty {
                TrafficSparkline(samples: viewModel.trafficSamples)
                    .frame(height: 58)
            }
        }
        .flowGatePanelCard()
    }

    private func metricCard(title: String, value: String, tint: Color, monospaced: Bool = true) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(CuspPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
            Text(value)
                .font(monospaced
                    ? .system(size: 12, weight: .semibold, design: .monospaced)
                    : .system(size: 12, weight: .semibold, design: .rounded)
                )
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, minHeight: overviewCardMinHeight, alignment: .topLeading)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    CuspPalette.raisedCardFill.opacity(0.93),
                    CuspPalette.raisedCardFill.opacity(0.76)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            cardShape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            tint.opacity(0.28),
                            tint.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            cardShape
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(0.11),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 6,
                        endRadius: 72
                    )
                )
        )
        .overlay(
            cardShape
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
                .blur(radius: 0.4)
        )
        .clipShape(cardShape)
        .shadow(color: tint.opacity(0.14), radius: 6, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 3)
    }

    private var overviewGridHeight: CGFloat {
        overviewCardMinHeight * 2 + overviewGridSpacing
    }

    private var overviewTopSectionHeight: CGFloat {
        max(overviewGridHeight, 176)
    }

    private func overviewButtonSize(for containerWidth: CGFloat) -> CGFloat {
        let proposed = containerWidth * 0.2
        return min(max(proposed, 148), 196)
    }

    private func summaryPill(title: String, value: String) -> some View {
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

    private func messageBanner(text: String, color: Color) -> some View {
        Text(text)
            .flowGateStatusBanner(color: color)
    }

    private var modeTitle: String {
        switch viewModel.selectedRuntimeMode {
        case .rules:
            return t("Rules", "规则判定")
        case .global:
            return t("Global", "全局代理")
        case .direct:
            return t("Direct", "直接连接")
        }
    }

    private var connectionTint: Color {
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

private struct TrafficSparkline: View {
    let samples: [TrafficSample]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let values = samples.map { max($0.uploadBytesPerSecond, $0.downloadBytesPerSecond) }
            let maxValue = max(values.max() ?? 1, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CuspPalette.raisedCardFill.opacity(0.65))

                Path { path in
                    guard !values.isEmpty else { return }
                    for (index, value) in values.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                        let y = height - (CGFloat(value / maxValue) * (height - 8)) - 4
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(CuspPalette.accentBright, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }
}
