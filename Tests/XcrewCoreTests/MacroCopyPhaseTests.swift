import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

/// The phase Tuist generated before 4.203, as it appears in a generated project file.
let oldTuistCopyPhase = ##"shellScript = "#  This build phase serves two purposes:\n#  - Force Xcode build system to compile the macOS executable transitively when compiling for non-macOS destinations\n    cp -f \"$BUILD_DIR/$CONFIGURATION/AMacros\" \"$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/AMacros\"\n";"##

@Suite struct MacroCopyPhaseTests {
    @Test func findsGeneratedProjectsThatCopyPluginsInPlace() {
        let project = Project.temporary()
        project.write(oldTuistCopyPhase, to: "Packages/Macros/Macros.xcodeproj/project.pbxproj")
        project.write(oldTuistCopyPhase, to: "Tuist/.build/tuist-derived/Projects/SomeMacros/SomeMacros.xcodeproj/project.pbxproj")
        project.write("HEADER_SEARCH_PATHS = \"$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME\";", to: "App.xcodeproj/project.pbxproj")
        #expect(MacroCopyPhase.projects(in: project) == ["Macros", "SomeMacros"])
    }

    @Test func ignoresBuildOutputAndDependencies() {
        let project = Project.temporary()
        project.write(oldTuistCopyPhase, to: ".build/checkouts/x/X.xcodeproj/project.pbxproj")
        project.write(oldTuistCopyPhase, to: "node_modules/y/Y.xcodeproj/project.pbxproj")
        #expect(MacroCopyPhase.projects(in: project).isEmpty)
    }

    @Test func theDoctorNamesTheProjectsAndTheFix() async {
        let project = Project.temporary(containing: ["App.xcworkspace"])
        project.write(oldTuistCopyPhase, to: "Macros/Macros.xcodeproj/project.pbxproj")
        let result = await MacroCopyPhaseCheck().run(.fake(project: project))
        #expect(result.status == .warn)
        #expect(result.message.contains("Macros") && result.message.contains("4.203"))
    }

    @Test func aProjectWithoutThePhasePasses() async {
        let project = Project.temporary(containing: ["App.xcodeproj"])
        #expect(await MacroCopyPhaseCheck().run(.fake(project: project)).status == .pass)
    }

    @Test func theRepairReplyNamesTheCause() {
        let reply = HookReply.macroRepair(.init(repaired: ["Debug-iphonesimulator/AMacros"]), cause: ["Macros"], event: HookEvent(name: "PostToolUseFailure"))
        #expect(reply?.context.contains("Tuist") == true)
        #expect(reply?.context.contains("4.203") == true)
        #expect(HookReply.macroRepair(.init(repaired: ["D/AMacros"]), cause: [], event: HookEvent(name: "x"))?.context.contains("Tuist") == false)
    }
}
