import AST
import Foundation

// MARK: - Supported regex syntax: RE2 only
//
// Only Go RE2 syntax is supported. `validateRE2Compatible` rejects ICU-only
// features (backreferences, lookaround, atomic groups) before patterns reach
// `NSRegularExpression`. See README "Known differences from OPA" for details.

/// Per-pattern cache of compiled `NSRegularExpression` instances, mirroring
/// Go OPA's package-level `regexpCache`. `NSLock` guards both maps; the lock
/// is only held for the dictionary read/write. Upgrade to `Mutex` once the
/// deployment target reaches macOS 15+ / iOS 18+.
final class RegexCache: @unchecked Sendable {
    private var patterns: [String: NSRegularExpression] = [:]
    private var templates: [String: NSRegularExpression] = [:]
    private let lock = NSLock()
    private let maxSize = 100

    func compile(_ pattern: String) throws -> NSRegularExpression {
        if let cached = lock.withLock({ patterns[pattern] }) { return cached }
        do {
            try validateRE2Compatible(pattern)

            // NSRegularExpression rejects ""; substitute `(?:)`, which has the
            // same match semantics and is accepted by ICU. Cache under the
            // original key so the substitution is invisible to callers.
            let effectivePattern = pattern.isEmpty ? "(?:)" : pattern
            let regex = try NSRegularExpression(pattern: effectivePattern)
            lock.withLock {
                if patterns.count >= maxSize {
                    if let key = patterns.keys.randomElement() {
                        patterns.removeValue(forKey: key)
                    }
                }
                patterns[pattern] = regex
            }
            return regex
        } catch let error as RegoError {
            throw error
        } catch {
            throw BuiltinError.evalError(msg: "invalid regex pattern: \(pattern)")
        }
    }

    /// Compile a template, caching by template string. Templates use a
    /// separate dictionary from raw patterns: the same string can produce
    /// different compiled regexes depending on which one it is.
    func compileTemplate(
        _ template: String,
        build: (String) throws -> String
    ) throws -> NSRegularExpression {
        if let cached = lock.withLock({ templates[template] }) { return cached }
        do {
            let regexPattern = try build(template)
            // Validate the assembled pattern: inner-delimiter content lands in
            // the regex verbatim, while literal segments are escaped.
            try validateRE2Compatible(regexPattern)
            let regex = try NSRegularExpression(pattern: regexPattern)
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

/// Reject ICU constructs that RE2 doesn't accept. Currently flagged:
///
/// - Backreferences (`\1`–`\9`)
/// - Lookahead and negative lookahead (`(?=...)`, `(?!...)`)
/// - Lookbehind and negative lookbehind (`(?<=...)`, `(?<!...)`)
/// - Atomic groups (`(?>...)`)
///
/// Inside character classes, `\1` is a literal byte and `(` is not a group
/// opener, so `[\1]` and `[(?=]` are not flagged. Some ICU-only constructs,
/// like named groups `(?<name>...)`, are not flagged today.
private func validateRE2Compatible(_ pattern: String) throws {
    let chars = Array(pattern)
    var i = 0
    var inCharClass = false

    while i < chars.count {
        let c = chars[i]

        if c == "\\" {
            // Skip the escaped char. `\1` is a backreference outside char
            // classes (RE2 forbids it) but a literal byte inside.
            guard i + 1 < chars.count else { return }
            let next = chars[i + 1]
            if !inCharClass, next.isASCII,
                let digit = next.wholeNumberValue, digit >= 1, digit <= 9
            {
                throw BuiltinError.evalError(
                    msg: "RE2-incompatible regex pattern: backreference \\\(next) is not supported")
            }
            i += 2
            continue
        }

        if inCharClass {
            if c == "]" { inCharClass = false }
            i += 1
            continue
        }

        if c == "[" {
            inCharClass = true
            i += 1
            continue
        }

        if c == "(", i + 2 < chars.count, chars[i + 1] == "?" {
            switch chars[i + 2] {
            case "=":
                throw BuiltinError.evalError(
                    msg: "RE2-incompatible regex pattern: lookahead (?=...) is not supported")
            case "!":
                throw BuiltinError.evalError(
                    msg: "RE2-incompatible regex pattern: negative lookahead (?!...) is not supported")
            case ">":
                throw BuiltinError.evalError(
                    msg: "RE2-incompatible regex pattern: atomic group (?>...) is not supported")
            case "<":
                if i + 3 < chars.count {
                    let c3 = chars[i + 3]
                    if c3 == "=" {
                        throw BuiltinError.evalError(
                            msg: "RE2-incompatible regex pattern: lookbehind (?<=...) is not supported")
                    }
                    if c3 == "!" {
                        throw BuiltinError.evalError(
                            msg: "RE2-incompatible regex pattern: negative lookbehind (?<!...) is not supported")
                    }
                }
            default:
                break
            }
        }

        i += 1
    }
}

extension BuiltinFuncs {

    private static let regexCache = RegexCache()

    // MARK: - regex.is_valid

    /// `regex.is_valid(pattern)` — `true` iff `pattern` is valid RE2 syntax.
    /// Patterns using ICU-only features return `false`.
    static func regexIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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

    /// `regex.match(pattern, value)` — `true` iff `pattern` matches anywhere
    /// in `value`. Throws if `pattern` is not valid RE2 syntax.
    static func regexMatch(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        let range = NSRange(value.startIndex..., in: value)
        return .boolean(regex.firstMatch(in: value, range: range) != nil)
    }

    // MARK: - regex.replace

    /// `regex.replace(s, pattern, value)` — replace every match of `pattern`
    /// in `s` with `value`. `value` supports `$0` (whole match), `$N`
    /// (capture group N), and `$$` (literal `$`), matching Go's
    /// `regexp.ReplaceAllString`.
    static func regexReplace(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        let nsRange = NSRange(base.startIndex..., in: base)
        let matches = regex.matches(in: base, range: nsRange)

        guard !matches.isEmpty else {
            return .string(base)
        }

        // Pass 1: compute expansions and total size, so pass 2 can reserve
        // capacity once. `$N` is expanded manually to preserve Go's `$$` → `$`
        // semantics; NSRegularExpression's built-in template uses `\$`.
        var expansions: [String] = []
        expansions.reserveCapacity(matches.count)
        var totalSize = 0
        var lastEnd = base.startIndex

        for match in matches {
            guard let r = Range(match.range, in: base) else { continue }
            totalSize += base.utf8.distance(from: lastEnd, to: r.lowerBound)
            let expanded = expandTemplate(replacement, match: match, in: base)
            totalSize += expanded.utf8.count
            expansions.append(expanded)
            lastEnd = r.upperBound
        }
        totalSize += base.utf8.distance(from: lastEnd, to: base.endIndex)

        // Pass 2: assemble with reserved capacity.
        var result = ""
        result.reserveCapacity(totalSize)
        lastEnd = base.startIndex

        for (i, match) in matches.enumerated() {
            guard let r = Range(match.range, in: base) else { continue }
            result += base[lastEnd..<r.lowerBound]
            result += expansions[i]
            lastEnd = r.upperBound
        }
        result += base[lastEnd...]

        return .string(result)
    }

    // MARK: - regex.split

    /// `regex.split(pattern, value)` — split `value` at each match. Returns
    /// `[value]` if there are no matches.
    static func regexSplit(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        let nsRange = NSRange(value.startIndex..., in: value)
        let matches = regex.matches(in: value, range: nsRange)

        guard !matches.isEmpty else {
            return .array([.string(value)])
        }

        var parts: [AST.RegoValue] = []
        var lastEnd = value.startIndex

        for match in matches {
            guard let r = Range(match.range, in: value) else { continue }
            parts.append(.string(String(value[lastEnd..<r.lowerBound])))
            lastEnd = r.upperBound
        }
        parts.append(.string(String(value[lastEnd...])))

        return .array(parts)
    }

    // MARK: - regex.find_n

    /// `regex.find_n(pattern, value, n)` — return up to `n` non-overlapping
    /// matches. `n < 0` returns all matches.
    static func regexFindN(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        let nsRange = NSRange(value.startIndex..., in: value)
        let allMatches = regex.matches(in: value, range: nsRange)
        let limited = n < 0 ? allMatches : Array(allMatches.prefix(n))

        return .array(
            limited.compactMap { match in
                guard let r = Range(match.range, in: value) else { return nil }
                return .string(String(value[r]))
            })
    }

    // MARK: - regex.find_all_string_submatch_n

    /// `regex.find_all_string_submatch_n(pattern, value, n)` — return up to
    /// `n` non-overlapping matches with their capture groups. Each match is
    /// `[whole_match, group_1, group_2, ...]`. `n < 0` returns all matches.
    static func regexFindAllStringSubmatchN(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        let nsRange = NSRange(value.startIndex..., in: value)
        let allMatches = regex.matches(in: value, range: nsRange)
        let limited = n < 0 ? allMatches : Array(allMatches.prefix(n))

        return .array(
            limited.map { match in
                var groups: [AST.RegoValue] = []
                for i in 0..<match.numberOfRanges {
                    let groupRange = match.range(at: i)
                    if groupRange.location != NSNotFound, let r = Range(groupRange, in: value) {
                        groups.append(.string(String(value[r])))
                    } else {
                        groups.append(.string(""))
                    }
                }
                return .array(groups)
            })
    }

    // MARK: - regex.template_match

    /// `regex.template_match(pattern, value, delim_start, delim_end)` —
    /// match `value` against a templated `pattern`. Regex segments appear
    /// between single-character delimiter pairs; other text is literal.
    static func regexTemplateMatch(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
        // Anchored with `^...$`, so a non-nil firstMatch means the whole
        // string matched.
        let range = NSRange(value.startIndex..., in: value)
        return .boolean(regex.firstMatch(in: value, range: range) != nil)
    }

    // MARK: - Private helpers

    /// Build an anchored regex from a template with configurable delimiters.
    /// Text outside delimiters is escaped as a literal; text inside becomes
    /// a capture group. Result is anchored with `^...$`. Ported from Go OPA's
    /// `compileRegexTemplate` (originally from Gorilla Mux).
    ///
    ///     compileTemplatePattern("urn:foo:{.*}", delimStart: "{", delimEnd: "}")
    ///     // → "^urn\\:foo\\:(.*)$"
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

    /// Find balanced delimiter pairs. Returns alternating `[open, close, ...]`
    /// indices: `open` at the start delimiter, `close` one past the end.
    /// Nested delimiters are tracked by depth and consumed but not emitted.
    /// Throws on unbalanced delimiters (e.g. `"urn:{foo"` or `"urn:}foo"`).
    ///
    ///     "urn:{.*}:end"
    ///      ^   ^   ^
    ///      |   |   └── close (one past `}`)
    ///      |   └────── open (`{`)
    ///      └────────── literal, skipped
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

    /// Expand `$N` capture references and `$$` (literal `$`) in a replacement
    /// template, matching Go's `regexp.ReplaceAllString`. NSRegularExpression's
    /// built-in template uses `\$` for a literal `$`, so we expand manually.
    ///
    ///     expandTemplate("$1$1", match-of-`(foo)`-on-"foo", in: "foo") → "foofoo"
    private static func expandTemplate(
        _ template: String, match: NSTextCheckingResult, in source: String
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
                    if digit < match.numberOfRanges {
                        let groupRange = match.range(at: digit)
                        if groupRange.location != NSNotFound,
                            let r = Range(groupRange, in: source)
                        {
                            result.append(contentsOf: source[r])
                        }
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
