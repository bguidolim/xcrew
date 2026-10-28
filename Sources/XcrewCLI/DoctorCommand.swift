import Foundation

import XcrewCore

struct DoctorCommand: Command {
    let name = "doctor"
    let valuedOptions: Set<String> = ["check"]
    let usage = [
        "doctor [--check ID]   run the health checks (exit: 0 ok, 1 failed, 2 warned, 3 skipped)",
        "doctor --list         list the check ids",
    ]

    func run(_ invocation: Invocation) async throws -> Int32 {
        if invocation.arguments.has("list") {
            Doctor.checks.forEach { invocation.print("\($0.id)\t\($0.title)") }
            return 0
        }
        if let id = invocation.arguments["check"] {
            guard let check = Doctor.check(id: id) else { throw UsageError(description: "unknown check '\(id)' (doctor --list)") }
            let result = await check.run(invocation.context)
            invocation.print(result.message)
            return result.status.rawValue
        }
        let entries = await Doctor.run(in: invocation.context)
        let width = entries.map(\.check.id.count).max() ?? 0
        for entry in entries {
            let tag = entry.result.status.tag.padding(toLength: 4, withPad: " ", startingAt: 0)
            let id = entry.check.id.padding(toLength: width, withPad: " ", startingAt: 0)
            invocation.print("\(tag)  \(id)  \(entry.result.message)")
        }
        return Doctor.worst(entries).rawValue
    }
}
