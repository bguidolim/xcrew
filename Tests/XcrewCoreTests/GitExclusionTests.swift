import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

@Suite struct GitExclusionTests {
    /// A project whose git repository keeps its exclude file at `.git/info/exclude`.
    func repository() -> (Project, FakeRunner) {
        let project = Project.temporary()
        project.write("# git ls-files --exclude-standard\n", to: ".git/info/exclude")
        let runner = FakeRunner(responses: ["git -C \(project.root.path) rev-parse --git-path info/exclude": .init(status: 0, stdout: ".git/info/exclude\n")])
        return (project, runner)
    }

    func exclude(_ project: Project) -> String {
        (try? String(contentsOf: project.root.appending(path: ".git/info/exclude"), encoding: .utf8)) ?? ""
    }

    @Test func keepsTheMachineSpecificConfigOutOfGit() async {
        let (project, runner) = repository()
        #expect(await GitExclusion.exclude(".mobilebuildmcp/", in: project, using: runner) == .added)
        #expect(exclude(project) == "# git ls-files --exclude-standard\n/.mobilebuildmcp/\n")
    }

    @Test func addsTheLineOnce() async {
        let (project, runner) = repository()
        _ = await GitExclusion.exclude(".mobilebuildmcp/", in: project, using: runner)
        #expect(await GitExclusion.exclude(".mobilebuildmcp/", in: project, using: runner) == .alreadyExcluded)
        #expect(exclude(project).components(separatedBy: "/.mobilebuildmcp/").count == 2)
    }

    @Test func doesNothingOutsideARepository() async {
        #expect(await GitExclusion.exclude(".mobilebuildmcp/", in: .temporary(), using: FakeRunner()) == .notARepository)
    }
}
