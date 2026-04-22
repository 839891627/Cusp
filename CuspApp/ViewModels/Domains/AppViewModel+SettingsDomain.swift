import Foundation
import ServiceManagement
import UserNotifications

extension AppViewModel {
    func configureLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLoginEnabled, forKey: Self.launchAtLoginEnabledKey)
        do {
            if launchAtLoginEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "更新开机自启失败。"
                : "Failed to update launch at login."
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled
        configureLaunchAtLogin()
    }

    func setRestoreConnectionOnLaunchEnabled(_ enabled: Bool) {
        restoreConnectionOnLaunchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.restoreConnectionOnLaunchKey)
    }

    func setNotificationEnabled(_ enabled: Bool) {
        notificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.notificationEnabledKey)
        if enabled {
            requestNotificationAuthorizationIfNeeded()
        }
    }

    func setDisconnectWhenOtherVPNActiveEnabled(_ enabled: Bool) {
        disconnectWhenOtherVPNActiveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.disconnectWhenOtherVPNActiveKey)
    }

    func requestNotificationAuthorizationIfNeeded() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
}
