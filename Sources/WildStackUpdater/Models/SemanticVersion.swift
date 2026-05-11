import Foundation

/// Parses and compares x.y.z version strings numerically.
/// String comparison breaks for "1.9.0" vs "1.10.0"; this doesn't.
struct SemanticVersion: Comparable, Hashable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String { "\(major).\(minor).\(patch)" }

    /// Returns nil for empty or unparseable strings.
    init?(_ string: String) {
        let raw = string.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }

        // Strip a leading "v" (e.g. "v1.2.3")
        let stripped = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        let parts = stripped
            .components(separatedBy: ".")
            .prefix(3)
            .map { Int($0.filter(\.isNumber)) ?? 0 }

        major = parts.count > 0 ? parts[0] : 0
        minor = parts.count > 1 ? parts[1] : 0
        patch = parts.count > 2 ? parts[2] : 0
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
