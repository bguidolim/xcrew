import Foundation

/// The agent skills the installed Xcode ships in its Claude plugin. Copied rather than linked:
/// the source folder is named after the Xcode build and moves with every Xcode update.
public struct XcodeSkills: Sendable {
    public let source: URL

    /// The skills folder of Xcode's plugin, or nil before Xcode 27.
    public static func locate(using runner: any CommandRunning) async -> XcodeSkills? {
        let output = await runner.run("xcrun", "mcpbridge", "run-agent", "plugin", "path", "--plugin-format", "claude")
        guard output.succeeded, let last = output.stdout.split(separator: "\n").last else { return nil }
        let skills = URL(fileURLWithPath: String(last)).appending(path: "skills")
        return FileManager.default.fileExists(atPath: skills.path) ? XcodeSkills(source: skills) : nil
    }

    /// Every skill this Xcode ships: a folder holding a `SKILL.md`.
    public var available: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: source.path)) ?? []).sorted().filter {
            FileManager.default.fileExists(atPath: source.appending(path: "\($0)/SKILL.md").path)
        }
    }

    /// Copies `names` (all available ones when empty), replacing earlier copies; returns what it copied.
    public func copy(_ names: [String] = [], to destination: URL) throws -> [String] {
        let chosen = names.isEmpty ? available : names.filter(available.contains)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in chosen {
            let target = destination.appending(path: name)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: source.appending(path: name), to: target)
        }
        return chosen
    }
}
