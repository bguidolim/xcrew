import Foundation
import Testing

/// Runs the real `bin/xcrew` against a copy of the repository's layout, with a fake `swift` that
/// records each build and produces a stand-in binary.
@Suite struct ShimTests {
    let root: URL
    let cache: URL
    let log: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "xcrew-shim-\(UUID().uuidString)")
        root = base.appending(path: "plugin")
        cache = base.appending(path: "cache")
        log = base.appending(path: "builds.log")
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root.appending(path: "bin"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: repository.appending(path: "bin/xcrew"), to: root.appending(path: "bin/xcrew"))
        try write("// swift-tools-version:6.0\n", to: "Package.swift")
        try write("print(1)\n", to: "Sources/xcrew/main.swift")

        // The fake swift writes a binary that prints its arguments and XCREW_ROOT.
        let fakeSwift = """
        #!/bin/sh
        echo build >> "\(log.path)"
        [ -n "${FAIL_BUILD:-}" ] && { echo "compile error" >&2; exit 1; }
        while [ $# -gt 0 ]; do [ "$1" = --scratch-path ] && scratch="$2"; shift; done
        mkdir -p "$scratch/release"
        printf '#!/bin/sh\\necho "ran $* root=$XCREW_ROOT"\\n' > "$scratch/release/xcrew"
        chmod +x "$scratch/release/xcrew"
        """
        try write(fakeSwift, to: "fakebin/swift", executable: true)
    }

    func write(_ text: String, to path: String, executable: Bool = false) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        if executable { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path) }
    }

    func shim(_ arguments: String..., environment: [String: String] = [:]) throws -> (status: Int32, output: String, errors: String) {
        let process = Process()
        process.executableURL = root.appending(path: "bin/xcrew")
        process.arguments = arguments
        process.environment = [
            "PATH": "\(root.appending(path: "fakebin").path):/usr/bin:/bin",
            "HOME": FileManager.default.temporaryDirectory.path,
            "XCREW_CACHE": cache.path,
        ].merging(environment) { $1 }
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let read = { (pipe: Pipe) in String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) }
        return (process.terminationStatus, read(output), read(errors))
    }

    /// The path with every symlink resolved, as `pwd -P` prints it (Foundation drops `/private`).
    func physicalPath(_ url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/pwd")
        process.arguments = ["-P"]
        process.currentDirectoryURL = url
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    var builds: Int {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    @Test func buildsOnFirstUseAndRunsTheBinary() async throws {
        let run = try shim("doctor", "--list")
        #expect(run.status == 0)
        #expect(run.output == "ran doctor --list root=\(try physicalPath(root))\n")
        #expect(builds == 1)
    }

    @Test func reusesTheBuild() async throws {
        _ = try shim("help")
        _ = try shim("help")
        #expect(builds == 1)
    }

    @Test func rebuildsWhenTheSourcesChange() async throws {
        _ = try shim("help")
        try write("print(2)\n", to: "Sources/xcrew/main.swift")
        _ = try shim("help")
        #expect(builds == 2)
    }

    @Test func aFailedBuildFailsLoudlyAndCachesNothing() async throws {
        let failed = try shim("help", environment: ["FAIL_BUILD": "1"])
        #expect(failed.status != 0)
        #expect(failed.errors.contains("compile error"))
        _ = try shim("help")
        #expect(builds == 2)
    }

    @Test func buildOutputStaysOffStandardOutput() async throws {
        // Hooks print JSON on stdout; anything else there breaks the reply.
        let run = try shim("help")
        #expect(!run.output.contains("build"))
    }
}

extension ShimTests {
    @Test func aRebuildRemovesTheBuildItReplaces() throws {
        _ = try shim("help")
        let first = try FileManager.default.contentsOfDirectory(atPath: cache.path).filter { $0 != "build" }
        try write("print(3)\n", to: "Sources/xcrew/main.swift")
        _ = try shim("help")
        let second = try FileManager.default.contentsOfDirectory(atPath: cache.path).filter { $0 != "build" }
        #expect(first.count == 1)
        #expect(second.count == 1)
        #expect(second != first)
    }
}
