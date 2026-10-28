import Foundation
import XcrewCore

/// Answers commands from a table keyed by the joined argv; anything else reads as not found.
public struct FakeRunner: CommandRunning {
    public var installed: Set<String> = []
    public var responses: [String: CommandResult] = [:]

    public init(installed: Set<String> = [], responses: [String: CommandResult] = [:]) {
        self.installed = installed
        self.responses = responses
    }

    public func run(_ argv: [String], stdin: Data?, timeout: Duration) async -> CommandResult {
        responses[argv.joined(separator: " ")] ?? .notFound
    }

    public func which(_ name: String) -> String? {
        installed.contains(name) ? "/opt/homebrew/bin/\(name)" : nil
    }
}

extension CheckContext {
    public static func fake(_ runner: FakeRunner = FakeRunner(), project: Project = .temporary(), environment: [String: String] = [:]) -> CheckContext {
        CheckContext(project: project, machine: Machine(environment: environment, home: project.root.appending(path: "home"), runner: runner))
    }
}
