import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct XcodeSkillsTests {
    /// A stand-in for Xcode's plugin folder: two skills and a folder that isn't one.
    func xcodePlugin() -> Project {
        let plugin = Project.temporary()
        plugin.write("# A", to: "skills/swiftui-specialist/SKILL.md")
        plugin.write("# B", to: "skills/device-interaction/SKILL.md")
        plugin.write("", to: "skills/notes/readme.txt")
        return plugin
    }

    func runner(for plugin: Project) -> FakeRunner {
        FakeRunner(responses: ["xcrun mcpbridge run-agent plugin path --plugin-format claude": .init(status: 0, stdout: "note\n\(plugin.root.path)\n")])
    }

    @Test func findsTheSkillsTheInstalledXcodeShips() async throws {
        let plugin = xcodePlugin()
        let skills = try #require(await XcodeSkills.locate(using: runner(for: plugin)))
        #expect(skills.available == ["device-interaction", "swiftui-specialist"])
    }

    @Test func noPluginBeforeXcode27() async {
        #expect(await XcodeSkills.locate(using: FakeRunner()) == nil)
    }

    @Test func copiesAllOrTheNamedOnesReplacingEarlierCopies() async throws {
        let skills = try #require(await XcodeSkills.locate(using: runner(for: xcodePlugin())))
        let project = Project.temporary()
        project.write("stale", to: ".claude/skills/swiftui-specialist/SKILL.md")

        #expect(try skills.copy(["swiftui-specialist", "not-shipped"], to: project.skillsFolder) == ["swiftui-specialist"])
        #expect(try String(contentsOf: project.skillsFolder.appending(path: "swiftui-specialist/SKILL.md"), encoding: .utf8) == "# A")
        #expect(try skills.copy(to: project.skillsFolder) == ["device-interaction", "swiftui-specialist"])
    }
}
