import Foundation

/// The project xcrew serves: its root folder and the files xcrew reads or writes there.
public struct Project: Sendable, Equatable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    /// The project mcs or Claude Code names, else the working directory.
    public static func current(machine: Machine = .live) -> Project {
        let path = machine.value("MCS_PROJECT_PATH") ?? machine.value("CLAUDE_PROJECT_DIR") ?? FileManager.default.currentDirectoryPath
        return Project(root: URL(fileURLWithPath: path, isDirectory: true))
    }

    public var mobileBuildMCPConfig: URL { root.appending(path: ".mobilebuildmcp/config.yaml") }
    /// Marks the config as xcrew's: setup rewrites a marked config and leaves an unmarked one alone.
    public var managedMarker: URL { root.appending(path: ".mobilebuildmcp/.xcrew-managed") }
    /// Where XcodeBuildMCP kept its config before the rename; no longer read by anything.
    public var legacyConfigFolder: URL { root.appending(path: ".xcodebuildmcp") }
    public var skillsFolder: URL { root.appending(path: ".claude/skills") }

    /// `.xcworkspace` and `.xcodeproj` bundles at the root, workspaces first.
    public var xcodeContainers: [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.filter { $0.hasSuffix(".xcworkspace") }.sorted() + names.filter { $0.hasSuffix(".xcodeproj") }.sorted()
    }

    /// The names Xcode gives this project's DerivedData folders (`<name>-<hash>`): each workspace
    /// or project, and for a Swift package opened directly, the package folder.
    public var derivedDataNames: Set<String> {
        var names = Set(xcodeContainers.map { ($0 as NSString).deletingPathExtension })
        if FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path) {
            names.insert(root.lastPathComponent)
        }
        return names
    }

    /// Files whose presence marks an Apple-platform project, including generated ones
    /// (Tuist, XcodeGen) whose workspace may not exist yet.
    static let appleProjectMarkers = ["Package.swift", "Project.swift", "Workspace.swift", "Tuist", "project.yml"]

    public var isApplePlatformProject: Bool {
        !xcodeContainers.isEmpty
            || Self.appleProjectMarkers.contains { FileManager.default.fileExists(atPath: root.appending(path: $0).path) }
    }
}
