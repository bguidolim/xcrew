import Foundation

/// The answers that shape `.mobilebuildmcp/config.yaml`: the container to build and the
/// session-defaults profiles Claude switches between (`unit` always, `ui` and `app` when asked).
public struct ProfileAnswers: Sendable, Equatable {
    public var container: String
    public var testSimulator: String
    public var appSimulator: String
    public var appScheme: String?
    public var bundleID: String?
    public var uiTestScheme: String?

    public init(
        container: String,
        testSimulator: String,
        appSimulator: String? = nil,
        appScheme: String? = nil,
        bundleID: String? = nil,
        uiTestScheme: String? = nil
    ) {
        self.container = container.hasPrefix("./") ? String(container.dropFirst(2)) : container
        self.testSimulator = testSimulator
        self.appSimulator = appSimulator.nonEmpty ?? testSimulator
        self.appScheme = appScheme.nonEmpty
        self.bundleID = bundleID.nonEmpty
        self.uiTestScheme = uiTestScheme.nonEmpty
    }
}

extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
