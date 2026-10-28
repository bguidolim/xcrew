import Foundation

public enum ConfigWriter {
    public enum Outcome: Equatable, Sendable {
        case written(backup: URL?)
        /// A config xcrew didn't write was found and left as it was.
        case keptUnmanaged
    }

    /// Writes the config unless one exists that xcrew didn't write; `force` replaces that one,
    /// keeping a timestamped backup beside it.
    public static func write(
        _ answers: ProfileAnswers,
        to project: Project,
        force: Bool = false,
        now: Date = Date()
    ) throws -> Outcome {
        let fileManager = FileManager.default
        let config = project.mobileBuildMCPConfig
        let isUnmanaged = fileManager.fileExists(atPath: config.path) && !fileManager.fileExists(atPath: project.managedMarker.path)
        if isUnmanaged, !force { return .keptUnmanaged }

        var backup: URL?
        if isUnmanaged {
            let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "")
            backup = config.appendingPathExtension("backup-\(stamp)")
            try fileManager.copyItem(at: config, to: backup!)
        }
        try fileManager.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ConfigRenderer.render(answers, root: project.root).write(to: config, atomically: true, encoding: .utf8)
        try Data().write(to: project.managedMarker)
        return .written(backup: backup)
    }
}
