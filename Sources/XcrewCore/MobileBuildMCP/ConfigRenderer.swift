import Foundation

/// Renders and reads `.mobilebuildmcp/config.yaml`. The format is MobileBuildMCP's; see its
/// configuration docs when a key changes.
public enum ConfigRenderer {
    /// Tool groups xcrew enables. `sim-env` is defined by `customWorkflows` below.
    public static let workflows = ["simulator", "sim-env", "xcode-ide", "ui-automation", "debugging"]
    /// Simulator-environment tools from MobileBuildMCP's `simulator-management` group, without
    /// the ones `simulator` already has.
    public static let simEnvTools = [
        "erase_sims", "set_sim_appearance", "set_sim_location", "reset_sim_location",
        "toggle_software_keyboard", "toggle_connect_hardware_keyboard",
    ]

    public static func render(_ answers: ProfileAnswers, root: URL) -> String {
        let pathKey = answers.container.hasSuffix(".xcodeproj") ? "projectPath" : "workspacePath"
        let location = quoted(root.appending(path: answers.container).path)

        func profile(_ name: String, scheme: String?, simulator: String, extra: [String] = []) -> [String] {
            ["  \(name):", "    \(pathKey): \(location)"]
                + (scheme.map { ["    scheme: \(quoted($0))"] } ?? [])
                + ["    simulatorName: \(quoted(simulator))"]
                + extra
        }

        var lines = ["schemaVersion: 1", "enabledWorkflows:"] + workflows.map { "  - \($0)" }
        lines += ["customWorkflows:", "  sim-env:"] + simEnvTools.map { "    - \($0)" }
        lines += ["sentryDisabled: true", "showTestTiming: true", "sessionDefaultsProfiles:"]
        lines += profile("unit", scheme: nil, simulator: answers.testSimulator)
        if let scheme = answers.uiTestScheme {
            lines += profile("ui", scheme: scheme, simulator: answers.appSimulator)
        }
        if let scheme = answers.appScheme {
            let bundle = answers.bundleID.map { ["    bundleId: \(quoted($0))"] } ?? []
            lines += profile("app", scheme: scheme, simulator: answers.appSimulator, extra: bundle)
        }
        lines.append("activeSessionDefaultsProfile: unit")
        return lines.joined(separator: "\n") + "\n"
    }

    /// The simulator names a config's profiles reference, each once.
    public static func simulatorNames(in yaml: String) -> [String] {
        values(of: ["simulatorName:"], in: yaml)
    }

    static func values(of keys: [String], in yaml: String) -> [String] {
        let found = yaml.split(separator: "\n").compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let key = keys.first(where: trimmed.hasPrefix) else { return nil }
            return unquoted(trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces))
        }
        return Array(Set(found)).sorted()
    }

    /// The workspace and project paths a config's profiles point at, each once.
    public static func containerPaths(in yaml: String) -> [String] {
        values(of: ["workspacePath:", "projectPath:"], in: yaml)
    }

    /// A YAML single-quoted scalar, so names with `: `, ` #` or quotes stay intact.
    static func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    static func unquoted(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("'"), value.hasSuffix("'") else { return value }
        return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
    }
}
