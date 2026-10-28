import Foundation

/// Probes the macro plugins in the project's DerivedData; changes nothing.
struct MacroPluginsCheck: Check {
    let id = "xcode-mcp/macro-plugins"
    let title = "Macro plugins answer"

    func run(_ context: CheckContext) async -> CheckResult {
        let locator = MacroPluginLocator(project: context.project, machine: context.machine)
        guard !locator.productFolders.isEmpty else { return .skip("no DerivedData for this project yet") }
        let plugins = locator.plugins()
        guard !plugins.isEmpty else { return .skip("this project builds no macro plugins") }
        let repairer = MacroPluginRepairer(locator: locator, probe: CapabilityProbe(runner: context.runner))
        let dead = await repairer.deadPlugins()
        guard dead.isEmpty else {
            return .warn("dead: \(dead.map(\.label).joined(separator: ", ")) (xcrew repair-macros)")
        }
        return .pass("\(plugins.count) answer")
    }
}
