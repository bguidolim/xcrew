import Foundation

/// Tells a working macro plugin from one macOS kills at launch.
public protocol MacroPluginProbing: Sendable {
    func answers(_ plugin: MacroPlugin) async -> Bool
}

/// Sends the compiler's capability request, as swift-frontend does before expanding a macro: an
/// 8-byte little-endian length, then the JSON message, on stdin.
public struct CapabilityProbe: MacroPluginProbing {
    let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    static let request = Data(#"{"getCapability":{"capability":{"protocolVersion":7}}}"#.utf8)

    static var framedRequest: Data {
        let length = UInt64(request.count)
        return Data((0..<8).map { UInt8(truncatingIfNeeded: length >> (8 * $0)) }) + request
    }

    public func answers(_ plugin: MacroPlugin) async -> Bool {
        await runner.run([plugin.path.path], stdin: Self.framedRequest, timeout: .seconds(10)).stdout.contains("getCapabilityResult")
    }
}
