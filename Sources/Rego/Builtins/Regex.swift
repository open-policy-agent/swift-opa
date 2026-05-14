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
    private var patterns: [String: Regex<AnyRegexOutput>] = [:]
    private var templates: [String: Regex<AnyRegexOutput>] = [:]
    private let lock = NSLock()
    private let maxSize = 100

    func compile(_ pattern: String) throws -> Regex<AnyRegexOutput> {
        if let cached = lock.withLock({ patterns[pattern] }) { return cached }
        do {
            let regex = try Regex(pattern)
            lock.withLock {
                if patterns.count >= maxSize {
                    if let key = patterns.keys.randomElement() {
                        patterns.removeValue(forKey: key)
                    }
                }
                patterns[pattern] = regex
            }
            return regex
        } catch {
            throw BuiltinError.evalError(msg: "invalid regex pattern: \(pattern)")
        }
    }

    /// Compile a template pattern, caching by the original template string.
    /// Matches Go's `getRegexpTemplate` which caches `pat` → compiled regex,
    /// so `compileRegexTemplate` only runs on cache miss.
    ///
    /// Templates and raw patterns are stored in separate dictionaries to avoid
    /// key collisions — the same string can produce different compiled regexes
    /// depending on whether it's treated as a raw pattern or a template.
    func compileTemplate(
        _ template: String,
        build: (String) throws -> String
    ) throws -> Regex<AnyRegexOutput> {
        if let cached = lock.withLock({ templates[template] }) { return cached }
        do {
            let regexPattern = try build(template)
            let regex = try Regex(regexPattern)
            lock.withLock {
                if templates.count >= maxSize {
                    if let key = templates.keys.randomElement() {
                        templates.removeValue(forKey: key)
                    }
                }
                templates[template] = regex
            }
            return regex
        } catch let error as RegoError {
            throw error
        } catch {
            throw BuiltinError.evalError(msg: "invalid regex in template: \(template)")
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

    // MARK: - regex.find_n

    static func regexFindN(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }
        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }
        guard case .number(let num) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "number", got: args[2].typeName, want: "number")
        }
        let n = num.intValue

        guard n != 0 else {
            return .array([])
        }

        let regex = try regexCache.compile(pattern)
        let allMatches = value.matches(of: regex)
        let limited = n < 0 ? allMatches : Array(allMatches.prefix(n))

        return .array(
            limited.map { match in
                .string(String(value[match.range]))
            })
    }

    // MARK: - regex.find_all_string_submatch_n

    static func regexFindAllStringSubmatchN(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }
        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }
        guard case .number(let num) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "number", got: args[2].typeName, want: "number")
        }
        let n = num.intValue

        guard n != 0 else {
            return .array([])
        }

        let regex = try regexCache.compile(pattern)
        let allMatches = value.matches(of: regex)
        let limited = n < 0 ? allMatches : Array(allMatches.prefix(n))

        return .array(
            limited.map { match in
                var groups: [AST.RegoValue] = []
                for i in 0..<match.output.count {
                    if let sub = match.output[i].substring {
                        groups.append(.string(String(sub)))
                    } else {
                        groups.append(.string(""))
                    }
                }
                return .array(groups)
            })
    }

    // MARK: - regex.template_match

    static func regexTemplateMatch(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 4 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 4)
        }
        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }
        guard case .string(let delimStart) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(
                arg: "delimiter_start", got: args[2].typeName, want: "string")
        }
        guard case .string(let delimEnd) = args[3] else {
            throw BuiltinError.argumentTypeMismatch(
                arg: "delimiter_end", got: args[3].typeName, want: "string")
        }

        guard delimStart.count == 1 else {
            throw BuiltinError.evalError(
                msg: "start delimiter must be exactly one character, got \(delimStart.count)")
        }
        guard delimEnd.count == 1 else {
            throw BuiltinError.evalError(
                msg: "end delimiter must be exactly one character, got \(delimEnd.count)")
        }

        let regex = try regexCache.compileTemplate(pattern) { template in
            try compileTemplatePattern(
                template, delimStart: Character(delimStart), delimEnd: Character(delimEnd))
        }
        return .boolean(value.wholeMatch(of: regex) != nil)
    }

    // MARK: - Private helpers

    /// Build an anchored regex from a template pattern with configurable delimiters.
    ///
    /// Text outside delimiters is escaped as literal. Text inside delimiters
    /// becomes a capture group. The result is anchored with `^...$`.
    ///
    /// Ported from Go OPA's `compileRegexTemplate` (originally from Gorilla Mux).
    ///
    ///     compileTemplatePattern("urn:foo:{.*}", delimStart: "{", delimEnd: "}")
    ///     // → "^urn\\:foo\\:(.*)$"
    ///
    /// ## Performance
    ///
    /// Uses `NSRegularExpression.escapedPattern(for:)` for escaping literal segments,
    /// which bridges through NSString. Also uses `+=` to assemble the pattern string.
    /// Both are acceptable here because this runs once per unique template — the
    /// compiled regex is cached in `RegexCache`, so subsequent calls with the same
    /// template skip this entirely.
    private static func compileTemplatePattern(
        _ template: String, delimStart: Character, delimEnd: Character
    ) throws -> String {
        let indices = try delimiterIndices(template, start: delimStart, end: delimEnd)

        var pattern = "^"
        var pos = template.startIndex

        for i in stride(from: 0, to: indices.count, by: 2) {
            let openIdx = indices[i]
            let closeIdx = indices[i + 1]

            let literal = template[pos..<openIdx]
            let inner = template[template.index(after: openIdx)..<template.index(before: closeIdx)]

            pattern += NSRegularExpression.escapedPattern(for: String(literal))
            pattern += "(\(inner))"
            pos = closeIdx
        }

        pattern += NSRegularExpression.escapedPattern(for: String(template[pos...]))
        pattern += "$"

        return pattern
    }

    /// Find balanced delimiter pairs in a template string.
    ///
    /// Returns indices as alternating `[open, close, open, close, ...]` pairs,
    /// where `open` is the index of the start delimiter and `close` is one past
    /// the end delimiter. Only top-level pairs are returned; nested delimiters
    /// are consumed but not emitted.
    ///
    /// Example with `{` and `}`:
    ///
    ///     "urn:{.*}:end"
    ///      ^   ^   ^
    ///      |   |   └── close (index of character after "}")
    ///      |   └────── open  (index of "{")
    ///      └────────── not a delimiter, skipped
    ///
    ///     Returns: [index of "{", index after "}"]
    ///
    /// Nested delimiters increment/decrement a depth counter. Only when depth
    /// returns to zero is a pair recorded. Throws on unbalanced delimiters
    /// (e.g. `"urn:{foo"` or `"urn:}foo"`).
    private static func delimiterIndices(
        _ s: String, start: Character, end: Character
    ) throws -> [String.Index] {
        var level = 0
        var idx = s.startIndex
        var indices: [String.Index] = []

        for i in s.indices {
            if s[i] == start {
                level += 1
                if level == 1 { idx = i }
            } else if s[i] == end {
                level -= 1
                if level == 0 {
                    indices.append(idx)
                    indices.append(s.index(after: i))
                } else if level < 0 {
                    throw BuiltinError.evalError(msg: "unbalanced delimiters in \"\(s)\"")
                }
            }
        }

        if level != 0 {
            throw BuiltinError.evalError(msg: "unbalanced delimiters in \"\(s)\"")
        }

        return indices
    }

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
