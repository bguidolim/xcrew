import Foundation

/// The JSON a Claude Code command hook receives on stdin; xcrew reads only what it needs.
public struct HookEvent: Sendable, Equatable {
    /// What the compiler prints when a macro plugin it launched was killed. `hooks/mod/repair.ts`
    /// holds the same text; `ManifestTests` keeps the two equal.
    public static let killedMacroPluginSignature = "produced malformed response"

    public let name: String
    public let cwd: String?
    /// The failed tool's error, or the finished tool's output, as text.
    public let toolText: String

    public init(name: String, cwd: String? = nil, toolText: String = "") {
        self.name = name
        self.cwd = cwd
        self.toolText = toolText
    }

    public init(json: Data) {
        let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]
        let response = object["tool_response"].flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed]) }
        let text = [object["error"] as? String, response.map { String(decoding: $0, as: UTF8.self) }].compactMap { $0 }.joined(separator: "\n")
        self.init(name: object["hook_event_name"] as? String ?? "PostToolUse", cwd: object["cwd"] as? String, toolText: text)
    }

    /// Whether the tool failed the way a killed macro plugin makes it fail. The repair hook acts
    /// only then, so projects that never hit it pay nothing.
    public var mentionsKilledMacroPlugin: Bool {
        toolText.contains(Self.killedMacroPluginSignature)
    }
}
