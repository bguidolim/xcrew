import Foundation

/// `--name value` options, bare `--flag`s and positional words.
public struct Arguments: Equatable {
    public private(set) var values: [String: String] = [:]
    public private(set) var flags: Set<String> = []
    public private(set) var positional: [String] = []

    public init(_ arguments: [String], valued: Set<String> = []) throws {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            guard argument.hasPrefix("--") else {
                positional.append(argument)
                continue
            }
            let name = String(argument.dropFirst(2))
            if valued.contains(name) {
                guard let value = rest.popFirst() else { throw UsageError(description: "--\(name) needs a value") }
                values[name] = value
            } else {
                flags.insert(name)
            }
        }
    }

    public subscript(name: String) -> String? { values[name] }
    public func has(_ flag: String) -> Bool { flags.contains(flag) }
}
