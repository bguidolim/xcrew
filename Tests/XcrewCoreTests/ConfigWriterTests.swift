import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct ConfigWriterTests {
    let answers = ProfileAnswers(container: "App.xcworkspace", testSimulator: "iPhone 17")

    @Test func writesAndMarksTheConfig() async throws {
        let project = Project.temporary()
        #expect(try ConfigWriter.write(answers, to: project) == .written(backup: nil))
        #expect(FileManager.default.fileExists(atPath: project.managedMarker.path))
        #expect(try String(contentsOf: project.mobileBuildMCPConfig, encoding: .utf8).contains("iPhone 17"))
    }

    @Test func rewritesItsOwnConfig() async throws {
        let project = Project.temporary()
        _ = try ConfigWriter.write(answers, to: project)
        var changed = answers
        changed.testSimulator = "iPhone 18"
        #expect(try ConfigWriter.write(changed, to: project) == .written(backup: nil))
        #expect(try String(contentsOf: project.mobileBuildMCPConfig, encoding: .utf8).contains("iPhone 18"))
    }

    @Test func leavesAHandWrittenConfigAlone() async throws {
        let project = Project.temporary()
        project.write("mine: true\n", to: ".mobilebuildmcp/config.yaml")
        #expect(try ConfigWriter.write(answers, to: project) == .keptUnmanaged)
        #expect(try String(contentsOf: project.mobileBuildMCPConfig, encoding: .utf8) == "mine: true\n")
    }

    @Test func forceReplacesAHandWrittenConfigAndKeepsABackup() async throws {
        let project = Project.temporary()
        project.write("mine: true\n", to: ".mobilebuildmcp/config.yaml")
        guard case .written(let backup?) = try ConfigWriter.write(answers, to: project, force: true) else {
            Issue.record("expected a backup")
            return
        }
        #expect(try String(contentsOf: backup, encoding: .utf8) == "mine: true\n")
    }
}
