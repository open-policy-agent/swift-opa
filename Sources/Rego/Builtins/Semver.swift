import AST
import Foundation

extension BuiltinFuncs {
    // MARK: - semver.is_valid
    static func semverIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let vsn) = args[0] else {
            return .boolean(false)
        }
        return .boolean(SemVer.parse(String(vsn)) != nil)
    }

    // MARK: - semver.compare
    static func semverCompare(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        guard case .string(let a) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "string")
        }
        guard case .string(let b) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "string")
        }
        guard let vA = SemVer.parse(String(a)) else {
            throw BuiltinError.evalError(msg: "operand 1: string \(a) is not a valid SemVer")
        }
        guard let vB = SemVer.parse(String(b)) else {
            throw BuiltinError.evalError(msg: "operand 2: string \(b) is not a valid SemVer")
        }
        return .number(RegoNumber(int: Int64(vA.compare(vB))))
    }
}

// MARK: - SemVer parser and comparator

/// Parsed representation of a semantic version (https://semver.org).
/// Mirrors Golang OPA internal/semver package behaviour.
private struct SemVer {
    let major: Int64
    let minor: Int64
    let patch: Int64
    let preRelease: String
    // Metadata is ignored for comparison per the semver spec.

    /// Parses a semver string, accepting an optional leading `v`.
    /// Returns nil if the string is not a valid semver.
    static func parse(_ input: String) -> SemVer? {
        var s = input
        if s.hasPrefix("v") {
            s = String(s.dropFirst())
        }

        // Split off build metadata (+)
        let metadata: String
        if let plusIdx = s.firstIndex(of: "+") {
            metadata = String(s[s.index(after: plusIdx)...])
            s = String(s[..<plusIdx])
            guard isValidIdentifier(metadata) else { return nil }
        } else {
            metadata = ""
        }

        // Split off pre-release (-)
        let preRelease: String
        if let dashIdx = s.firstIndex(of: "-") {
            preRelease = String(s[s.index(after: dashIdx)...])
            s = String(s[..<dashIdx])
            guard isValidIdentifier(preRelease) else { return nil }
        } else {
            preRelease = ""
        }

        // Core version must be exactly major.minor.patch
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
            let major = Int64(parts[0]),
            let minor = Int64(parts[1]),
            let patch = Int64(parts[2])
        else { return nil }

        return SemVer(major: major, minor: minor, patch: patch, preRelease: preRelease)
    }

    /// Compares self to other, returning -1, 0, or 1.
    func compare(_ other: SemVer) -> Int {
        for (a, b) in [(major, other.major), (minor, other.minor), (patch, other.patch)] {
            if a != b { return a < b ? -1 : 1 }
        }

        // Equal core version: no pre-release > has pre-release
        if preRelease == other.preRelease { return 0 }
        if preRelease.isEmpty { return 1 }
        if other.preRelease.isEmpty { return -1 }

        // Compare pre-release identifiers dot by dot
        var aPreReleaseParts = preRelease.split(separator: ".", omittingEmptySubsequences: false).map(String.init)[...]
        var bPreReleaseParts = other.preRelease.split(separator: ".", omittingEmptySubsequences: false).map(
            String.init)[...]

        while !aPreReleaseParts.isEmpty || !bPreReleaseParts.isEmpty {
            let a = aPreReleaseParts.first ?? ""
            let b = bPreReleaseParts.first ?? ""
            // Advance
            if !aPreReleaseParts.isEmpty { aPreReleaseParts = aPreReleaseParts.dropFirst() }
            if !bPreReleaseParts.isEmpty { bPreReleaseParts = bPreReleaseParts.dropFirst() }

            if a.isEmpty { return -1 }
            if b.isEmpty { return 1 }

            let aIsInt = SemVer.isAllDigits(a)
            let bIsInt = SemVer.isAllDigits(b)

            if aIsInt && !bIsInt { return -1 }
            if !aIsInt && bIsInt { return 1 }

            if aIsInt, let aInt = Int64(a), let bInt = Int64(b) {
                if aInt != bInt { return aInt < bInt ? -1 : 1 }
            } else {
                if a != b { return a < b ? -1 : 1 }
            }
        }
        return 0
    }

    // MARK: - Helpers

    private static func isValidIdentifier(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { component in
            !component.isEmpty && component.allSatisfy(isAlphanumericOrHyphen)
        }
    }

    private static func isAlphanumericOrHyphen(_ c: Character) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "-"
    }

    private static func isAllDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy(\.isNumber)
    }
}
