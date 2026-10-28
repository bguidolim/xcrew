import Foundation
import Testing
@testable import XcrewCore

@Suite struct SystemCommandRunnerTests {
    let runner = SystemCommandRunner(path: "/usr/bin:/bin")

    @Test func passesStandardInputAndCapturesBothStreams() async {
        let result = await runner.run("/bin/sh", "-c", "cat; echo oops >&2; exit 3", stdin: Data("hello".utf8))
        #expect(result == CommandResult(status: 3, stdout: "hello", stderr: "oops\n"))
    }

    @Test func aMissingProgramReadsAsNotFound() async {
        #expect(await runner.run("no-such-program-xcrew").status == 127)
        #expect(runner.which("no-such-program-xcrew") == nil)
        #expect(runner.which("sh") == "/bin/sh")
    }

    @Test func aProgramThatOutlivesItsTimeoutIsStopped() async {
        let clock = ContinuousClock()
        let started = clock.now
        let result = await runner.run(["/bin/sleep", "5"], stdin: nil, timeout: .milliseconds(200))
        #expect(result.status == 124)
        #expect(clock.now - started < .seconds(2))
    }

    @Test func largeOutputDoesNotDeadlock() async {
        // More than a pipe buffer holds, on both streams at once.
        let result = await runner.run("/bin/sh", "-c", "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b >&2")
        #expect(result.stdout.count == 300_000)
        #expect(result.stderr.count == 300_000)
    }
}
