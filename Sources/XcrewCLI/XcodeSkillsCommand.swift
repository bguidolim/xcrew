import Foundation

import XcrewCore

struct XcodeSkillsCommand: Command {
    let name = "xcode-skills"
    let usage = [
        "xcode-skills [--list] [NAME...]   copy the agent skills this Xcode ships into .claude/skills",
        "                                  (all unless names are given; run again after an Xcode update)",
    ]

    func run(_ invocation: Invocation) async throws -> Int32 {
        guard let skills = await XcodeSkills.locate(using: invocation.context.runner) else {
            throw UsageError(description: "Xcode's agent plugin not found (needs Xcode 27 or later)")
        }
        if invocation.arguments.has("list") {
            skills.available.forEach(invocation.print)
            return 0
        }
        let copied = try skills.copy(invocation.arguments.positional, to: invocation.context.project.skillsFolder)
        invocation.print("xcrew: copied \(copied.count) Xcode skills into .claude/skills: \(copied.joined(separator: ", "))")
        return 0
    }
}
