import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct ProjectTests {
    func machine(_ environment: [String: String]) -> Machine {
        Machine(environment: environment, home: URL(fileURLWithPath: "/"), runner: FakeRunner())
    }

    @Test func mcsProjectWinsOverClaudeProjectDir() {
        #expect(Project.current(machine: machine(["MCS_PROJECT_PATH": "/a", "CLAUDE_PROJECT_DIR": "/b"])).root.path == "/a")
        #expect(Project.current(machine: machine(["CLAUDE_PROJECT_DIR": "/b"])).root.path == "/b")
        #expect(Project.current(machine: machine(["MCS_PROJECT_PATH": ""])).root.path == FileManager.default.currentDirectoryPath)
    }

    @Test func workspacesComeBeforeProjects() {
        let project = Project.temporary(containing: ["Z.xcworkspace", "A.xcodeproj", "B.xcworkspace", "Notes"])
        #expect(project.xcodeContainers == ["B.xcworkspace", "Z.xcworkspace", "A.xcodeproj"])
    }

    @Test(arguments: ["Package.swift", "Project.swift", "Workspace.swift", "project.yml"])
    func recognisesApplePlatformProjects(marker: String) {
        let project = Project.temporary()
        #expect(!project.isApplePlatformProject)
        project.write("", to: marker)
        #expect(project.isApplePlatformProject)
    }
}
