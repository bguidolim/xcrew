import Foundation
import XcrewCLI
import XcrewCore

let machine = Machine.live
let context = CheckContext(project: .current(machine: machine), machine: machine)
let standardInput = { isatty(STDIN_FILENO) == 1 ? Data() : FileHandle.standardInput.readDataToEndOfFile() }
exit(await CLI.run(Array(CommandLine.arguments.dropFirst()), context: context, standardInput: standardInput))
