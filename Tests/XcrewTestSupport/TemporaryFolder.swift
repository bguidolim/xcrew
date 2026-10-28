import Foundation
import XcrewCore

extension Project {
    /// A fresh empty folder, holding the given empty bundles or folders.
    public static func temporary(containing names: [String] = []) -> Project {
        let root = FileManager.default.temporaryDirectory.appending(path: "xcrew-tests-\(UUID().uuidString)")
        for name in [""] + names {
            try! FileManager.default.createDirectory(at: root.appending(path: name), withIntermediateDirectories: true)
        }
        return Project(root: root)
    }

    public func write(_ text: String, to path: String) {
        let url = root.appending(path: path)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! text.write(to: url, atomically: true, encoding: .utf8)
    }
}
