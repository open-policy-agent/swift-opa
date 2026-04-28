import AST
import Foundation

/// Global cache for compiled regex patterns, surviving across evaluations.
///
/// Regex compilation is expensive relative to matching. This cache ensures each
/// unique pattern string is compiled once for the lifetime of the process,
/// matching the behavior of Go OPA's package-level `regexpCache`.
///
/// This is intentionally a regex-specific cache, not a general-purpose
/// cross-query cache. When a general-purpose inter-query builtin value cache
/// is introduced (analogous to Go's `InterQueryBuiltinValueCache`), this
/// should be reconsidered and potentially subsumed by that mechanism.
///
/// ## Thread safety
///
/// `NSLock` provides exclusive access for both reads and writes. Since compiled
/// `Regex` values are immutable after creation, concurrent reads would be safe
/// if the underlying `Dictionary` structure weren't being mutated by inserts.
/// The lock is held only for dictionary operations (~100ns), so contention is
/// negligible in practice. Upgrade path if this changes:
///
/// - `DispatchQueue(.concurrent)` with barrier writes for true concurrent reads.
/// - `Mutex` (Swift `Synchronization` module) when the deployment target
///   reaches macOS 15+ / iOS 18+.
/// - `pthread_rwlock_t` for shared-reader/exclusive-writer semantics, with
///   `#if os(Windows)` conditional for `SRWLOCK`.
final class RegexCache: @unchecked Sendable {
    private var cache: [String: Regex<AnyRegexOutput>] = [:]
    private let lock = NSLock()
    private let maxSize = 100

    func get(_ pattern: String) -> Regex<AnyRegexOutput>? {
        lock.withLock { cache[pattern] }
    }

    func put(_ pattern: String, _ regex: Regex<AnyRegexOutput>) {
        lock.withLock {
            if cache.count >= maxSize {
                if let key = cache.keys.randomElement() {
                    cache.removeValue(forKey: key)
                }
            }
            cache[pattern] = regex
        }
    }

    func compile(_ pattern: String) throws -> Regex<AnyRegexOutput> {
        if let cached = get(pattern) { return cached }
        do {
            let regex = try Regex(pattern)
            put(pattern, regex)
            return regex
        } catch {
            throw BuiltinError.evalError(msg: "invalid regex pattern: \(pattern)")
        }
    }
}

extension BuiltinFuncs {

    private static let regexCache = RegexCache()

    // MARK: - regex.is_valid

    static func regexIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let pattern) = args[0] else {
            return .boolean(false)
        }
        let valid = (try? regexCache.compile(pattern)) != nil
        return .boolean(valid)
    }

    // MARK: - regex.match

    static func regexMatch(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }

        let regex = try regexCache.compile(pattern)
        return .boolean(value.firstMatch(of: regex) != nil)
    }

    // MARK: - regex.replace

    static func regexReplace(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }
        guard case .string(let base) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "s", got: args[0].typeName, want: "string")
        }
        guard case .string(let pattern) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[1].typeName, want: "string")
        }
        guard case .string(let replacement) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[2].typeName, want: "string")
        }

        let regex = try regexCache.compile(pattern)
        let matches = base.matches(of: regex)

        guard !matches.isEmpty else {
            return .string(base)
        }

        // Pass 1: pre-compute expanded replacements and calculate exact result size.
        // String is a value type in Swift — repeated += without reserveCapacity
        // triggers O(n) reallocations. Two passes avoids all of them.
        var expansions: [String] = []
        expansions.reserveCapacity(matches.count)
        var totalSize = 0
        var lastEnd = base.startIndex

        for match in matches {
            totalSize += base.utf8.distance(from: lastEnd, to: match.range.lowerBound)
            let expanded = expandTemplate(replacement, match: match)
            totalSize += expanded.utf8.count
            expansions.append(expanded)
            lastEnd = match.range.upperBound
        }
        totalSize += base.utf8.distance(from: lastEnd, to: base.endIndex)

        // Pass 2: assemble with exact capacity — zero reallocations.
        var result = ""
        result.reserveCapacity(totalSize)
        lastEnd = base.startIndex

        for (i, match) in matches.enumerated() {
            result += base[lastEnd..<match.range.lowerBound]
            result += expansions[i]
            lastEnd = match.range.upperBound
        }
        result += base[lastEnd...]

        return .string(result)
    }

    // MARK: - regex.split

    static func regexSplit(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }

        let regex = try regexCache.compile(pattern)
        let matches = value.matches(of: regex)

        guard !matches.isEmpty else {
            return .array([.string(value)])
        }

        var parts: [AST.RegoValue] = []
        var lastEnd = value.startIndex

        for match in matches {
            parts.append(.string(String(value[lastEnd..<match.range.lowerBound])))
            lastEnd = match.range.upperBound
        }
        parts.append(.string(String(value[lastEnd...])))

        return .array(parts)
    }

    // MARK: - Private helpers

    /// Expand `$N` capture group references in a replacement template.
    ///
    /// Go's `regexp.ReplaceAllString` supports `$0` (whole match), `$1`, `$2`, etc.
    /// in the replacement string. For example:
    ///
    /// Go: regexp.MustCompile(`(foo)`).ReplaceAllString("foo", "$1$1") → "foofoo"
    ///
    /// Swift's `Regex` only offers closure-based `replacing(_:with:)` with no
    /// template string API, so we implement the expansion manually. Given a match
    /// of `/(foo)/` against `"foo"`:
    ///
    ///     match.output[0].substring  // "foo" — whole match ($0)
    ///     match.output[1].substring  // "foo" — first capture group ($1)
    ///     expandTemplate("$1$1", match) → "foofoo"
    private static func expandTemplate(
        _ template: String, match: Regex<AnyRegexOutput>.Match
    ) -> String {
        var result = ""
        var iter = template.makeIterator()

        while let ch = iter.next() {
            if ch == "$" {
                guard let next = iter.next() else {
                    result.append(ch)
                    break
                }
                if next == "$" {
                    result.append("$")
                } else if next.isWholeNumber, let digit = next.wholeNumberValue {
                    if digit < match.output.count,
                        let substring = match.output[digit].substring
                    {
                        result.append(contentsOf: substring)
                    }
                } else {
                    result.append(ch)
                    result.append(next)
                }
            } else {
                result.append(ch)
            }
        }
        return result
    }
}
