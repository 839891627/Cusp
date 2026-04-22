import Foundation

public enum CuspConstants {
    public static let appGroupIdentifier = "group.com.example.Cusp"
    public static let tunnelBundleIdentifier = "com.example.Cusp.CuspTunnel"
    public static let managerDescription = "Cusp"
    public static let sharedConfigKey = "shared.shadowsocks.config"
    public static let sharedNodeCatalogKey = "shared.shadowsocks.catalog"
    public static let subscriptionCatalogKey = "shared.subscription.catalog"
    public static let selectedNodeIDKey = "shared.shadowsocks.selected-node-id"
    public static let selectedModeKey = "shared.runtime.mode"
    public static let lastTunnelErrorKey = "shared.tunnel.last-error"
    public static let localProxyHost = "127.0.0.1"
    public static let localHTTPProxyPort = 1086
    public static let localSOCKSProxyPort = 1087
    public static let proxyStartupTimeoutInterval: TimeInterval = 45
}
