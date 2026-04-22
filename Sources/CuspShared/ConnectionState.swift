import Foundation

public enum ConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case invalid

    public var title: String {
        switch self {
        case .disconnected:
            "Disconnected"
        case .connecting:
            "Connecting"
        case .connected:
            "Connected"
        case .disconnecting:
            "Disconnecting"
        case .invalid:
            "Unavailable"
        }
    }
}
