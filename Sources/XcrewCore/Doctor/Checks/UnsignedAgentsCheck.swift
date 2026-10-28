import Foundation

/// With this Xcode default on, any unsigned process on the Mac may drive Xcode's tools.
struct UnsignedAgentsCheck: Check {
    let id = "xcode-mcp/unsigned-agents-off"
    let title = "Xcode refuses unsigned agents"

    func run(_ context: CheckContext) async -> CheckResult {
        let value = await context.runner.run("defaults", "read", "com.apple.dt.Xcode", "IDEAllowUnauthenticatedAgents")
            .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != "1" else {
            return .warn("Xcode accepts unsigned agents: defaults write com.apple.dt.Xcode IDEAllowUnauthenticatedAgents -bool NO")
        }
        return .pass("off")
    }
}
