import Foundation

/// A command hook's JSON reply. `context` reaches Claude; `systemMessage` is shown to the person.
public struct HookReply: Sendable, Equatable {
    public let event: HookEvent
    public let context: String
    public let systemMessage: String?

    public init(event: HookEvent, context: String, systemMessage: String? = nil) {
        self.event = event
        self.context = context
        self.systemMessage = systemMessage
    }

    public var json: String {
        var object: [String: Any] = ["hookSpecificOutput": ["hookEventName": event.name, "additionalContext": context]]
        if let systemMessage { object["systemMessage"] = systemMessage }
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// After a failed Xcode MCP build: nil when no plugin needed repair.
    public static func macroRepair(_ report: MacroPluginRepairer.Report, event: HookEvent) -> HookReply? {
        guard !report.isEmpty else { return nil }
        var sentences: [String] = []
        if !report.repaired.isEmpty {
            sentences.append("xcrew repaired macro plugins macOS killed at launch: \(report.repaired.joined(separator: ", ")). Retry the Xcode MCP call that just failed.")
        }
        if !report.stillDead.isEmpty {
            sentences.append("These macro plugins still don't answer after a re-copy: \(report.stillDead.joined(separator: ", ")). Clean the build folder and rebuild.")
        }
        let text = sentences.joined(separator: " ")
        return HookReply(event: event, context: text, systemMessage: text)
    }
}
