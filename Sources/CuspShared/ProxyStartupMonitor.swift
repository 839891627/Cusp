import Foundation

public enum ProxyStartupMonitor {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case processExited(String?)
        case timedOut(String, Int, String?)

        public var errorDescription: String? {
            switch self {
            case .processExited(let diagnostics):
                if let diagnostics, !diagnostics.isEmpty {
                    return "mihomo exited before the local proxy became ready. Diagnostics: \(diagnostics)"
                }
                return "mihomo exited before the local proxy became ready."
            case .timedOut(let host, let port, let diagnostics):
                if let diagnostics, !diagnostics.isEmpty {
                    return "The local proxy did not start listening on \(host):\(port) before the startup timeout expired. Diagnostics: \(diagnostics)"
                }
                return "The local proxy did not start listening on \(host):\(port) before the startup timeout expired."
            }
        }
    }

    public static func waitUntilReady(
        host: String,
        port: Int,
        timeoutInterval: TimeInterval,
        pollInterval: TimeInterval = 0.1,
        isListening: () -> Bool,
        isProcessRunning: () -> Bool,
        diagnostics: () -> String
    ) throws {
        let deadline = Date().addingTimeInterval(timeoutInterval)

        while Date() < deadline {
            if isListening() {
                return
            }

            if !isProcessRunning() {
                let summary = sanitizedDiagnostics(from: diagnostics())
                throw Error.processExited(summary)
            }

            Thread.sleep(forTimeInterval: pollInterval)
        }

        throw Error.timedOut(host, port, sanitizedDiagnostics(from: diagnostics()))
    }

    public static func waitUntilReady(
        host: String,
        port: Int,
        timeoutInterval: TimeInterval,
        pollInterval: TimeInterval = 0.1,
        isProcessRunning: () -> Bool,
        diagnostics: () -> String
    ) throws {
        try waitUntilReady(
            host: host,
            port: port,
            timeoutInterval: timeoutInterval,
            pollInterval: pollInterval,
            isListening: {
                LocalPortWaiter.isListening(host: host, port: port)
            },
            isProcessRunning: isProcessRunning,
            diagnostics: diagnostics
        )
    }

    private static func sanitizedDiagnostics(from diagnostics: String) -> String? {
        let trimmed = diagnostics.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
