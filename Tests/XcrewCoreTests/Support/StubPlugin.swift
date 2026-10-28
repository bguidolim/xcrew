import Foundation
import XcrewCore

/// Compiles Fixtures/stub_plugin.c into a real Mach-O binary, healthy or dead.
enum StubPlugin {
    static let source = Bundle.module.url(forResource: "stub_plugin", withExtension: "c", subdirectory: "Fixtures")!

    /// Awaits the compiler rather than blocking a thread: the suites share one process.
    static func build(at url: URL, healthy: Bool) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let arguments = ["/usr/bin/cc"] + (healthy ? ["-DHEALTHY"] : []) + ["-o", url.path, source.path]
        guard await SystemCommandRunner().run(arguments, stdin: nil, timeout: .seconds(60)).succeeded else {
            throw CocoaError(.executableLoad)
        }
    }
}
