import Foundation

/// Repairs macro plugins macOS kills at launch.
///
/// When Xcode rebuilds a macro plugin it can rewrite the signed binary in place, and macOS then
/// kills the next launch before it starts. The build fails with "External macro implementation
/// type '…' could not be found … produced malformed response". A copy of the same bytes, at a new
/// inode, runs; so the repair is to copy each dead plugin and swap the copy in.
public struct MacroPluginRepairer: Sendable {
    public struct Report: Sendable, Equatable {
        public var repaired: [String] = []
        public var stillDead: [String] = []
        public var isEmpty: Bool { repaired.isEmpty && stillDead.isEmpty }

        public init(repaired: [String] = [], stillDead: [String] = []) {
            self.repaired = repaired
            self.stillDead = stillDead
        }
    }

    let locator: MacroPluginLocator
    let probe: any MacroPluginProbing

    public init(locator: MacroPluginLocator, probe: any MacroPluginProbing) {
        self.locator = locator
        self.probe = probe
    }

    /// Probes every plugin concurrently; the result keeps the locator's order.
    public func deadPlugins() async -> [MacroPlugin] {
        let plugins = locator.plugins()
        let answers = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, plugin) in plugins.enumerated() {
                group.addTask { (index, await probe.answers(plugin)) }
            }
            return await group.reduce(into: [Int: Bool]()) { $0[$1.0] = $1.1 }
        }
        return plugins.indices.filter { answers[$0] == false }.map { plugins[$0] }
    }

    public func repair() async -> Report {
        var report = Report()
        for plugin in await deadPlugins() {
            if Self.recopy(plugin), await probe.answers(plugin) {
                report.repaired.append(plugin.label)
            } else {
                report.stillDead.append(plugin.label)
            }
        }
        return report
    }

    /// Copies the binary beside itself and swaps the copy in atomically, so no reader ever sees
    /// a half-written plugin.
    static func recopy(_ plugin: MacroPlugin) -> Bool {
        let fresh = plugin.path.appendingPathExtension("xcrew-new")
        try? FileManager.default.removeItem(at: fresh)
        do {
            try FileManager.default.copyItem(at: plugin.path, to: fresh)
            _ = try FileManager.default.replaceItemAt(plugin.path, withItemAt: fresh)
            return true
        } catch {
            try? FileManager.default.removeItem(at: fresh)
            return false
        }
    }
}
