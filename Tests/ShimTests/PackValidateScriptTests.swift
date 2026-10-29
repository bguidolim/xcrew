import Foundation
import Testing

/// Runs the real `scripts/pack-validate.sh` with a stand-in `mcs` that prints a report in the shape `mcs pack validate`
/// prints it, against a pack whose manifest takes a formula from a third-party tap.
@Suite struct PackValidateScriptTests {
    let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let tapWarning = "[WARN] Component 'xcrew.mobilebuildmcp' installs 'getsentry/xcodebuildmcp/mobilebuildmcp' from third-party tap 'getsentry/xcodebuildmcp' — 'mcs sync' taps it without confirmation from Homebrew or mcs."

    func validate(_ report: [String], status: Int32 = 0) async throws -> (status: Int32, output: String, errors: String) {
        let root = FileManager.default.temporaryDirectory.appending(path: "xcrew-pack-validate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appending(path: "bin"), withIntermediateDirectories: true)
        try "components:\n  - id: mobilebuildmcp\n    brew: getsentry/xcodebuildmcp/mobilebuildmcp\n".write(to: root.appending(path: "techpack.yaml"), atomically: true, encoding: .utf8)
        try (report.joined(separator: "\n") + "\n").write(to: root.appending(path: "report.txt"), atomically: true, encoding: .utf8)
        let mcs = root.appending(path: "bin/mcs")
        try """
        #!/bin/sh
        [ "$1 $2 $3" = "pack validate \(root.path)" ] || { echo "unexpected arguments: $*" >&2; exit 64; }
        cat "\(root.path)/report.txt"
        exit \(status)
        """.write(to: mcs, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mcs.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [repository.appending(path: "scripts/pack-validate.sh").path, root.path]
        process.environment = ["PATH": "\(root.appending(path: "bin").path):/usr/bin:/bin"]
        process.standardInput = FileHandle.nullDevice
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try await ShimTests.runToEnd(process)
        return (process.terminationStatus,
                String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
                String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }

    /// The pack can't move MobileBuildMCP off the tap Sentry publishes it from, so that advice is the one warning allowed.
    @Test func aCleanReportWithTheTapItDeclaresPasses() async throws {
        let result = try await validate(["  xcrew", Self.tapWarning, "", "1 passed  1 warnings  0 issues"])
        #expect(result.status == 0)
        #expect(result.output.contains(Self.tapWarning))
    }

    @Test func anyOtherWarningFails() async throws {
        let warning = "[WARN] docs/x.md is not referenced by any component or template"
        let result = try await validate(["  xcrew", Self.tapWarning, warning, "", "1 passed  2 warnings  0 issues"])
        #expect(result.status == 1)
        #expect(result.errors == "mcs pack validate warned; CI treats a warning as an error:\n\(warning)\n")
    }

    @Test func aTapThePackDoesNotDeclareFails() async throws {
        let other = "[WARN] Component 'xcrew.x' installs 'someone/tap/x' from third-party tap 'someone/tap' — 'mcs sync' taps it without confirmation from Homebrew or mcs."
        let result = try await validate([other, "", "1 passed  1 warnings  0 issues"])
        #expect(result.status == 1)
        #expect(result.errors == "mcs pack validate warned; CI treats a warning as an error:\n\(other)\n")
    }

    @Test func anErrorFailsWithMCSsOwnStatus() async throws {
        let result = try await validate(["[ERROR] Invalid pack: Pack 'xcrew' requires mcs >= 2026.10.30, current is 2026.10.29", "", "0 passed  0 warnings  1 issues"], status: 1)
        #expect(result.status == 1)
        #expect(result.output.contains("requires mcs >= 2026.10.30"))
    }
}
