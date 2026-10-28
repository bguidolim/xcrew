import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct ConfigRendererTests {
    let root = URL(fileURLWithPath: "/work/App")

    @Test func unitProfileOnlyByDefault() async {
        let yaml = ConfigRenderer.render(ProfileAnswers(container: "App.xcworkspace", testSimulator: "iPhone 17"), root: root)
        #expect(yaml.contains("  unit:\n    workspacePath: '/work/App/App.xcworkspace'\n    simulatorName: 'iPhone 17'"))
        #expect(!yaml.contains("  ui:"))
        #expect(!yaml.contains("  app:"))
        #expect(yaml.hasSuffix("activeSessionDefaultsProfile: unit\n"))
    }

    @Test func uiAndAppProfilesWhenSchemesAreGiven() async {
        let answers = ProfileAnswers(
            container: "App.xcworkspace", testSimulator: "iPhone 17", appSimulator: "iPhone 17 Pro",
            appScheme: "App", bundleID: "com.example.app", uiTestScheme: "AppUITests"
        )
        let yaml = ConfigRenderer.render(answers, root: root)
        #expect(yaml.contains("  ui:\n    workspacePath: '/work/App/App.xcworkspace'\n    scheme: 'AppUITests'\n    simulatorName: 'iPhone 17 Pro'"))
        #expect(yaml.contains("    scheme: 'App'\n    simulatorName: 'iPhone 17 Pro'\n    bundleId: 'com.example.app'"))
    }

    @Test func projectsUseProjectPath() async {
        let yaml = ConfigRenderer.render(ProfileAnswers(container: "./App.xcodeproj", testSimulator: "iPhone 17"), root: root)
        #expect(yaml.contains("projectPath: '/work/App/App.xcodeproj'"))
    }

    @Test func emptyAnswersCountAsMissing() async {
        let answers = ProfileAnswers(container: "A.xcworkspace", testSimulator: "iPhone 17", appSimulator: "", appScheme: "", uiTestScheme: "")
        #expect(answers.appSimulator == "iPhone 17")
        #expect(answers.appScheme == nil)
        #expect(answers.uiTestScheme == nil)
    }

    @Test func quotingSurvivesYAMLSpecialCharacters() async {
        let name = "Bob's iPhone: #2"
        let yaml = ConfigRenderer.render(ProfileAnswers(container: "A.xcworkspace", testSimulator: name), root: root)
        #expect(yaml.contains("simulatorName: 'Bob''s iPhone: #2'"))
        #expect(ConfigRenderer.simulatorNames(in: yaml) == [name])
    }
}
