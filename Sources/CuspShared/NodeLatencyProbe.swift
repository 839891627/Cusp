import Foundation
import Network

public enum NodeLatencyProbe {
    public struct ProbeResult: Sendable {
        public let latencyMs: Int?
        public let status: CatalogNode.ProbeStatus

        public init(latencyMs: Int?, status: CatalogNode.ProbeStatus) {
            self.latencyMs = latencyMs
            self.status = status
        }
    }

    public static func sortForDisplay(_ nodes: [CatalogNode]) -> [CatalogNode] {
        nodes.sorted { lhs, rhs in
            displayRank(for: lhs) < displayRank(for: rhs)
        }
    }

    public static func measureLatency(
        host: String,
        port: Int,
        timeoutInterval: TimeInterval = 3
    ) async -> ProbeResult {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return ProbeResult(latencyMs: nil, status: .failure)
        }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "Cusp.NodeLatencyProbe.\(host).\(port)")
        let stateBox = ProbeStateBox()
        let startTime = DispatchTime.now().uptimeNanoseconds

        return await withCheckedContinuation { continuation in
            @Sendable func finish(_ result: ProbeResult) {
                stateBox.finish {
                    connection.cancel()
                    continuation.resume(returning: result)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startTime) / 1_000_000)
                    finish(ProbeResult(latencyMs: elapsedMs, status: .success))
                case .failed:
                    finish(ProbeResult(latencyMs: nil, status: .failure))
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeoutInterval) {
                finish(ProbeResult(latencyMs: nil, status: .timeout))
            }
        }
    }

    private static func displayRank(for node: CatalogNode) -> (Int, Int, String) {
        switch (node.probeStatus, node.latestLatencyMs) {
        case (.success, let latency?):
            return (0, latency, node.stableID)
        case (.idle, _):
            return (1, Int.max, node.stableID)
        default:
            return (2, Int.max, node.stableID)
        }
    }
}

private final class ProbeStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false

    func finish(_ action: () -> Void) {
        lock.lock()
        let shouldRun = !isFinished
        if shouldRun {
            isFinished = true
        }
        lock.unlock()

        if shouldRun {
            action()
        }
    }
}
