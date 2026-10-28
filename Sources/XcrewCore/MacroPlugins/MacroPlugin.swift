import Foundation

/// A Swift macro plugin binary in a DerivedData products folder.
public struct MacroPlugin: Sendable, Equatable {
    public let path: URL

    /// `<configuration folder>/<binary>`, as reports show it.
    public var label: String {
        "\(path.deletingLastPathComponent().lastPathComponent)/\(path.lastPathComponent)"
    }
}
