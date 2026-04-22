import Darwin
import Foundation

public enum LocalPortWaiter {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case timedOut(String, Int)

        public var errorDescription: String? {
            switch self {
            case .timedOut(let host, let port):
                return "The local proxy did not start listening on \(host):\(port) before the startup timeout expired."
            }
        }
    }

    public static func waitUntilListening(
        host: String,
        port: Int,
        timeout: Duration
    ) async throws {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            if canConnect(host: host, port: port) {
                return
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        throw Error.timedOut(host, port)
    }

    public static func waitUntilListening(
        host: String,
        port: Int,
        timeoutInterval: TimeInterval
    ) throws {
        let deadline = Date().addingTimeInterval(timeoutInterval)

        while Date() < deadline {
            if canConnect(host: host, port: port) {
                return
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        throw Error.timedOut(host, port)
    }

    public static func isListening(host: String, port: Int) -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            return false
        }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            return false
        }

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                connect(
                    socketDescriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                ) == 0
            }
        }
    }

    private static func canConnect(host: String, port: Int) -> Bool {
        isListening(host: host, port: port)
    }
}
