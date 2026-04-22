import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case nodes
    case rules
    case subscriptions
    case logs
    case settings

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return language == .simplifiedChinese ? "总览" : "Overview"
        case .nodes:
            return language == .simplifiedChinese ? "策略" : "Strategy"
        case .rules:
            return language == .simplifiedChinese ? "规则" : "Rules"
        case .subscriptions:
            return language == .simplifiedChinese ? "订阅" : "Subscriptions"
        case .logs:
            return language == .simplifiedChinese ? "日志" : "Logs"
        case .settings:
            return language == .simplifiedChinese ? "设置" : "Settings"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return language == .simplifiedChinese ? "连接与运行时摘要" : "Connection and runtime summary"
        case .nodes:
            return language == .simplifiedChinese ? "浏览并切换策略与节点" : "Browse and switch strategies"
        case .rules:
            return language == .simplifiedChinese ? "分流规则管理" : "Routing rule management"
        case .subscriptions:
            return language == .simplifiedChinese ? "导入或刷新远程来源" : "Import or refresh remote sources"
        case .logs:
            return language == .simplifiedChinese ? "运行与导入事件" : "Runtime and import events"
        case .settings:
            return language == .simplifiedChinese ? "本地运行操作" : "Local runtime actions"
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .nodes:
            return "point.3.connected.trianglepath.dotted"
        case .rules:
            return "list.bullet.clipboard"
        case .subscriptions:
            return "tray.and.arrow.down"
        case .logs:
            return "text.alignleft"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}
