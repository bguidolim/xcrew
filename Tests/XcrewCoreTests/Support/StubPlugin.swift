import Foundation

/// Compiles Fixtures/stub_plugin.c into a real Mach-O binary, healthy or dead.
enum StubPlugin {
    static let source = Bundle.module.url(forResource: "stub_plugin", withExtension: "c", subdirectory: "Fixtures")!

    static func build(at url: URL, healthy: Bool) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        process.arguments = (healthy ? ["-DHEALTHY"] : []) + ["-o", url.path, source.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
    }
}
