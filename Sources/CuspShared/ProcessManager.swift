import Foundation

public final class ProcessManager: @unchecked Sendable {
    public enum Error: Swift.Error, Equatable {
        case binaryNotFound(URL)
        case alreadyRunning
        case failedToLaunch(String)
    }

    private var process: Process?
    private let fileManager: FileManager
    private let maxDiagnosticBytes = 2048
    private var stderrBuffer = Data()
    private var stdoutBuffer = Data()
    private var stderrPipe: Pipe?
    private var stdoutPipe: Pipe?

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func launch(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) throws -> Process {
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw Error.binaryNotFound(executableURL)
        }
        guard process == nil else {
            throw Error.alreadyRunning
        }

        let child = Process()
        child.executableURL = executableURL
        child.arguments = arguments
        child.environment = environment
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        stdoutBuffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)
        startCapturingDiagnostics(from: stdoutPipe.fileHandleForReading) { [weak self] data in
            self?.appendToStdout(data)
        }
        startCapturingDiagnostics(from: stderrPipe.fileHandleForReading) { [weak self] data in
            self?.appendToStderr(data)
        }

        do {
            try child.run()
        } catch {
            throw Error.failedToLaunch(error.localizedDescription)
        }

        process = child
        return child
    }

    public func diagnosticSummary() -> String {
        let stderr = String(data: stderrBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stderr.isEmpty {
            return stderr
        }

        let stdout = String(data: stdoutBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stdout
    }

    public func cleanup() {
        guard let process else {
            return
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        self.process = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    private func startCapturingDiagnostics(from handle: FileHandle, append: @escaping @Sendable (Data) -> Void) {
        handle.readabilityHandler = { readableHandle in
            let data = readableHandle.availableData
            guard !data.isEmpty else {
                readableHandle.readabilityHandler = nil
                return
            }
            append(data)
        }
    }

    private func append(_ data: Data, to buffer: inout Data) {
        buffer.append(data)
        if buffer.count > maxDiagnosticBytes {
            buffer.removeFirst(buffer.count - maxDiagnosticBytes)
        }
    }

    private func appendToStdout(_ data: Data) {
        append(data, to: &stdoutBuffer)
    }

    private func appendToStderr(_ data: Data) {
        append(data, to: &stderrBuffer)
    }
}
