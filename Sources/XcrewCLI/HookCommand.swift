import Foundation
import XcrewCore

/// Entry points for Claude Code command hooks. Each reads the event on stdin and prints a reply
/// only when it has something to say.
struct HookCommand: Command {
    let name = "hook"
    let usage = [
        "hook session-start   (hook) routing rules and what this project still lacks",
        "hook repair-macros   (hook) repair macro plugins after a failed Xcode MCP build",
    ]

    func run(_ invocation: Invocation) async throws -> Int32 {
        let event = HookEvent(json: invocation.standardInput())
        let machine = invocation.context.machine
        let project = event.cwd.map { Project(root: URL(fileURLWithPath: $0, isDirectory: true)) } ?? invocation.context.project

        switch invocation.arguments.positional.first {
        case "session-start":
            let routing = (try? String(contentsOf: Self.pluginRoot(machine).appending(path: "context/routing.md"), encoding: .utf8)) ?? ""
            if let text = SessionBriefing(project: project, machine: machine).text(routing: routing) {
                invocation.print(HookReply(event: event, context: text).json)
            }
        case "repair-macros":
            guard event.mentionsKilledMacroPlugin else { return 0 }
            let locator = MacroPluginLocator(project: project, machine: machine)
            let report = await MacroPluginRepairer(locator: locator, probe: CapabilityProbe(runner: machine.runner)).repair()
            if let reply = HookReply.macroRepair(report, event: event) { invocation.print(reply.json) }
        default:
            throw UsageError(description: "unknown hook '\(invocation.arguments.positional.first ?? "")'")
        }
        return 0
    }

    /// Claude Code sets CLAUDE_PLUGIN_ROOT for plugin hooks; bin/xcrew sets XCREW_ROOT.
    static func pluginRoot(_ machine: Machine) -> URL {
        URL(fileURLWithPath: machine.value("CLAUDE_PLUGIN_ROOT") ?? machine.value("XCREW_ROOT") ?? ".")
    }
}
