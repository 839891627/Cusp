import Foundation

public enum RuntimeStateMachine {
    public static func canTransition(from current: ConnectionState, to next: ConnectionState) -> Bool {
        switch next {
        case .connecting:
            return current == .disconnected || current == .invalid
        case .connected:
            return current == .connecting
        case .disconnecting:
            return current == .connected || current == .connecting
        case .disconnected:
            return current == .invalid || current == .connecting || current == .disconnecting || current == .connected
        case .invalid:
            return false
        }
    }

    @discardableResult
    public static func transition(_ current: inout ConnectionState, to next: ConnectionState) -> Bool {
        guard canTransition(from: current, to: next) else {
            return false
        }
        current = next
        return true
    }
}
