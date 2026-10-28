import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct HookTests {
    @Test func readsTheEventItNeeds() async {
        let event = HookEvent(json: Data(#"{"hook_event_name":"PostToolUseFailure","cwd":"/work/App","tool_name":"x"}"#.utf8))
        #expect(event == HookEvent(name: "PostToolUseFailure", cwd: "/work/App"))
        #expect(HookEvent(json: Data("not json".utf8)).name == "PostToolUse")
    }

    @Test func replyShape() async throws {
        let json = HookReply(event: HookEvent(name: "SessionStart"), context: "rules", systemMessage: "hi").json
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let specific = try #require(object["hookSpecificOutput"] as? [String: String])
        #expect(specific == ["hookEventName": "SessionStart", "additionalContext": "rules"])
        #expect(object["systemMessage"] as? String == "hi")
    }

    @Test func macroRepairIsSilentWhenNothingWasDead() async {
        #expect(HookReply.macroRepair(.init(), event: HookEvent(name: "PostToolUseFailure")) == nil)
        let reply = HookReply.macroRepair(.init(repaired: ["Debug/AMacros"]), event: HookEvent(name: "PostToolUseFailure"))
        #expect(reply?.context.contains("Retry") == true)
    }

    @Test func briefingOnlyInAppleProjects() async {
        let elsewhere = SessionBriefing(project: .temporary(), machine: CheckContext.fake().machine)
        #expect(elsewhere.text(routing: "rules") == nil)

        let project = Project.temporary(containing: ["App.xcodeproj"])
        let text = SessionBriefing(project: project, machine: CheckContext.fake(project: project).machine).text(routing: "rules\n")
        #expect(text?.hasPrefix("rules\n- **xcrew:** MobileBuildMCP isn't installed") == true)
        #expect(text?.contains("/xcrew:setup") == true)
    }

    @Test func generatedProjectsCountBeforeTheirWorkspaceExists() async {
        let project = Project.temporary()
        project.write("", to: "Project.swift")
        #expect(project.isApplePlatformProject)
    }
}
