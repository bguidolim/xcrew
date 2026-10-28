import Foundation

/// A Swift macro plugin binary in a DerivedData products folder.
public struct MacroPlugin: Sendable, Equatable {
    public let path: URL

    /// `<configuration folder>/<binary>`, as reports show it; the indexer's copy says so, since
    /// both builds have folders of the same name.
    public var label: String {
        let label = "\(path.deletingLastPathComponent().lastPathComponent)/\(path.lastPathComponent)"
        return path.path.contains("/Index.noindex/") ? label + " (index build)" : label
    }
}
