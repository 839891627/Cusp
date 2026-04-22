import Foundation

extension AppViewModel {
    func text(_ key: AppTextKey) -> String {
        switch selectedLanguage {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return simplifiedChineseText(for: key)
        }
    }

    func languageDisplayName(_ language: AppLanguage) -> String {
        switch selectedLanguage {
        case .english:
            switch language {
            case .english:
                return "English"
            case .simplifiedChinese:
                return "Simplified Chinese"
            }
        case .simplifiedChinese:
            switch language {
            case .english:
                return "英文"
            case .simplifiedChinese:
                return "简体中文"
            }
        }
    }

    func localizedConnectionStateTitle(_ state: ConnectionState) -> String {
        switch selectedLanguage {
        case .english:
            return state.title
        case .simplifiedChinese:
            switch state {
            case .disconnected:
                return "未连接"
            case .connecting:
                return "连接中"
            case .connected:
                return "已连接"
            case .disconnecting:
                return "断开中"
            case .invalid:
                return "不可用"
            }
        }
    }

    private func englishText(for key: AppTextKey) -> String {
        switch key {
        case .appSubtitle:
            return "Native proxy control for macOS"
        case .currentNode:
            return "CURRENT NODE"
        case .connect:
            return "Connect"
        case .disconnect:
            return "Disconnect"
        case .settings:
            return "Settings"
        case .settingsSubtitle:
            return "Lightweight local controls for the MVP runtime."
        case .runtimeStatus:
            return "Runtime Status"
        case .connection:
            return "Connection"
        case .readiness:
            return "Readiness"
        case .savedNodes:
            return "Saved Nodes"
        case .actions:
            return "Actions"
        case .actionsSubtitle:
            return "Use these local cleanup actions if you want to reset the imported catalog before trying another source."
        case .clearSavedConfig:
            return "Clear Saved Config"
        case .language:
            return "Language"
        case .languageSubtitle:
            return "Switch app language instantly between English and Simplified Chinese."
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .overview:
            return "Overview"
        case .overviewSubtitle:
            return "Connection and runtime summary"
        case .nodes:
            return "Strategy"
        case .nodesSubtitle:
            return "Browse and switch strategies"
        case .subscriptions:
            return "Subscriptions"
        case .subscriptionsSubtitle:
            return "Import or refresh remote sources"
        case .logs:
            return "Logs"
        case .logsSubtitle:
            return "Runtime and import events"
        }
    }

    private func simplifiedChineseText(for key: AppTextKey) -> String {
        switch key {
        case .appSubtitle:
            return "macOS 原生代理控制"
        case .currentNode:
            return "当前节点"
        case .connect:
            return "连接"
        case .disconnect:
            return "断开连接"
        case .settings:
            return "设置"
        case .settingsSubtitle:
            return "用于 MVP 运行时的本地控制。"
        case .runtimeStatus:
            return "运行状态"
        case .connection:
            return "连接"
        case .readiness:
            return "就绪状态"
        case .savedNodes:
            return "已保存节点"
        case .actions:
            return "操作"
        case .actionsSubtitle:
            return "如果你想在导入新的订阅前重置当前目录，可使用这些本地清理操作。"
        case .clearSavedConfig:
            return "清空已保存配置"
        case .language:
            return "语言"
        case .languageSubtitle:
            return "可在英文和简体中文之间即时切换。"
        case .english:
            return "英文"
        case .simplifiedChinese:
            return "简体中文"
        case .overview:
            return "总览"
        case .overviewSubtitle:
            return "连接与运行时摘要"
        case .nodes:
            return "策略"
        case .nodesSubtitle:
            return "浏览并切换策略与节点"
        case .subscriptions:
            return "订阅"
        case .subscriptionsSubtitle:
            return "导入或刷新远程来源"
        case .logs:
            return "日志"
        case .logsSubtitle:
            return "运行与导入事件"
        }
    }
}

