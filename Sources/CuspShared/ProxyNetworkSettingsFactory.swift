import NetworkExtension

public enum ProxyNetworkSettingsFactory {
    public static func makeProxySettings(localHTTPPort: Int) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: CuspConstants.localProxyHost)
        settings.ipv4Settings = NEIPv4Settings(
            addresses: ["192.0.2.1"],
            subnetMasks: ["255.255.255.255"]
        )
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]

        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpsEnabled = true
        proxy.httpServer = NEProxyServer(address: CuspConstants.localProxyHost, port: localHTTPPort)
        proxy.httpsServer = NEProxyServer(address: CuspConstants.localProxyHost, port: localHTTPPort)
        proxy.excludeSimpleHostnames = true
        proxy.matchDomains = [""]
        settings.proxySettings = proxy

        return settings
    }
}
