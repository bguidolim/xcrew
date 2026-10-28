import Foundation

/// Keeps a path out of git through the repository's own `info/exclude`, which isn't committed,
/// so xcrew never changes a tracked `.gitignore`.
public enum GitExclusion {
    public enum Outcome: Sendable, Equatable {
        case added, alreadyExcluded, notARepository
    }

    public static func exclude(_ path: String, in project: Project, using runner: any CommandRunning) async -> Outcome {
        let located = await runner.run("git", "-C", project.root.path, "rev-parse", "--git-path", "info/exclude")
        guard located.succeeded, let relative = located.stdout.split(separator: "\n").first else { return .notARepository }
        let file = URL(fileURLWithPath: String(relative), relativeTo: project.root)
        let rule = "/" + path
        let existing = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        let rules = Set(existing.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        guard rules.isDisjoint(with: [rule, path, String(path.dropLast())]) else { return .alreadyExcluded }

        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (existing + separator + rule + "\n").write(to: file, atomically: true, encoding: .utf8)
            return .added
        } catch {
            return .notARepository
        }
    }
}
