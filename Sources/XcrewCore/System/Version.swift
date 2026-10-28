import Foundation

/// A dotted version number, compared part by part; missing parts count as zero.
struct Version: Comparable, CustomStringConvertible {
    let parts: [Int]

    init(_ text: String) {
        parts = text.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    var description: String { parts.map(String.init).joined(separator: ".") }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        let left = lhs.parts + Array(repeating: 0, count: count - lhs.parts.count)
        let right = rhs.parts + Array(repeating: 0, count: count - rhs.parts.count)
        return left.lexicographicallyPrecedes(right)
    }

    static func == (lhs: Version, rhs: Version) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
