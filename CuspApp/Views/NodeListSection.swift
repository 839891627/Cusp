import SwiftUI

struct NodeListSection: View {
    let configurations: [ShadowsocksConfiguration]
    let selectedLanguage: AppLanguage
    let selectedID: String?
    let onSelect: (String) -> Void

    private var isChinese: Bool {
        selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    var body: some View {
        if !configurations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t("Nodes", "节点"))
                        .font(CuspPalette.sectionTitleFont)
                        .foregroundStyle(CuspPalette.primaryText)
                    Spacer()
                    Text("\(configurations.count)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(CuspPalette.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CuspPalette.pillFill)
                        .clipShape(Capsule())
                }

                ForEach(configurations, id: \.stableID) { configuration in
                    Button {
                        onSelect(configuration.stableID)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: configuration.stableID == selectedID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(configuration.stableID == selectedID ? CuspPalette.success : CuspPalette.tertiaryText)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(configuration.remark ?? t("Unnamed Node", "未命名节点"))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(CuspPalette.primaryText)
                                Text("\(configuration.host):\(configuration.port)")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(CuspPalette.secondaryText)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            configuration.stableID == selectedID
                                ? CuspPalette.accent.opacity(0.16)
                                : CuspPalette.raisedCardFill
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CuspLayout.nestedCornerRadius, style: .continuous)
                                .stroke(configuration.stableID == selectedID ? CuspPalette.selectionStroke : CuspPalette.hairline.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .flowGatePanelCard()
        }
    }
}
