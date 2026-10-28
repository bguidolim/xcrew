import Foundation
import Synchronization

/// Runs real processes and awaits them without blocking a thread. A program that isn't found
/// reads as status 127 and one that outlives its timeout as 124, as a shell reports them.
public struct SystemCommandRunner: CommandRunning {
    let searchPath: [String]

    /// Homebrew's prefixes are appended because mcs and Claude Code can start xcrew without a
    /// login shell.
    public init(path: String? = ProcessInfo.processInfo.environment["PATH"]) {
        let inherited = (path ?? "").split(separator: ":").map(String.init)
        searchPath = inherited + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    }

    public func which(_ name: String) -> String? {
        searchPath.lazy.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func run(_ argv: [String], stdin: Data?, timeout: Duration) async -> CommandResult {
        guard let name = argv.first, let executable = name.hasPrefix("/") ? name : which(name) else { return .notFound }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(argv.dropFirst())
        let output = Pipe(), errors = Pipe(), input = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = input

        let exit = AsyncStream<Int32> { continuation in
            process.terminationHandler = { continuation.yield($0.terminationStatus); continuation.finish() }
        }
        do { try process.run() } catch { return CommandResult(status: 127, stderr: "\(error)") }

        // Both pipes drain while the child runs, so a chatty child can't block on a full pipe.
        async let stdout = Self.readToEnd(output.fileHandleForReading)
        async let stderr = Self.readToEnd(errors.fileHandleForReading)
        if let stdin { try? input.fileHandleForWriting.write(contentsOf: stdin) }
        try? input.fileHandleForWriting.close()

        let status = await withTaskGroup(of: Int32?.self) { group in
            group.addTask { await exit.first { _ in true } }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let status else {
            process.terminate()
            _ = await (stdout, stderr)
            return .timedOut
        }
        return CommandResult(status: status, stdout: await stdout, stderr: await stderr)
    }

    /// Collects a pipe's output as it arrives; resumes at end of file.
    static func readToEnd(_ handle: FileHandle) async -> String {
        let buffer = Buffer()
        let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard chunk.isEmpty else { return buffer.append(chunk) }
                handle.readabilityHandler = nil
                continuation.resume(returning: buffer.contents)
            }
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private final class Buffer: Sendable {
    private let data = Mutex(Data())
    func append(_ chunk: Data) { data.withLock { $0.append(chunk) } }
    var contents: Data { data.withLock { $0 } }
}
