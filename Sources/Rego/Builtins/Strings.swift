import AST
import Foundation

extension BuiltinFuncs {
    // can't use CharacterSet.whitespacesAndNewlines because it does not contain
    // \v (0x0B - vertical tab) and \f (0x0C - form feed)
    // Golang implementation has: '\t', '\n', '\v', '\f', '\r', ' ', 0x85, 0xA0
    fileprivate static let customWhitespace = CharacterSet(charactersIn: "\t\n\r ").union(
        [UnicodeScalar(0x0B), UnicodeScalar(0x0C), UnicodeScalar(0x85), UnicodeScalar(0xA0)]
    )

    static func concat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let delimiter) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter", got: args[0].typeName, want: "string")
        }

        switch args[1] {
        case .array(let a):
            return try .string(
                a.map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(
                            arg: "collection element: \($0)", got: $0.typeName, want: "string")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        case .set(let s):
            return try .string(
                s.sorted().map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(
                            arg: "collection element: \($0)", got: $0.typeName, want: "string")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "collection", got: args[1].typeName, want: "array|set")
        }
    }

    static func contains(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack", got: args[0].typeName, want: "string")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle", got: args[1].typeName, want: "string")
        }

        // Special logic to mimic the Go strings.Contains() behavior for empty strings..
        if needle.isEmpty {
            return .boolean(true)
        }
        return .boolean(haystack.contains(needle))
    }

    static func endsWith(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let search) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "search", got: args[0].typeName, want: "string")
        }

        guard case .string(let base) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "base", got: args[1].typeName, want: "string")
        }

        return .boolean(search.hasSuffix(base))
    }

    static func formatInt(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .number(let num) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "number", got: args[0].typeName, want: "number")
        }

        guard case .number(_) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "base", got: args[1].typeName, want: "number")
        }

        guard !args[1].isFloat, let radix = args[1].integerValue else {
            throw BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}")
        }
        guard radix == 2 || radix == 8 || radix == 10 || radix == 16 else {
            throw BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}")
        }

        let flooredValue = _floor(num.doubleValue)

        // Prevent overflow when converting to Int64
        let roundedNum: Int64
        if flooredValue > Double(Int64.max) {
            roundedNum = Int64.max
        } else if flooredValue < Double(Int64.min) {
            roundedNum = Int64.min
        } else {
            roundedNum = Int64(flooredValue)
        }
        return .string(String(roundedNum, radix: Int(radix)))
    }

    static func indexOf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack", got: args[0].typeName, want: "string")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle", got: args[1].typeName, want: "string")
        }

        // Special case to behave like the Go version does
        guard !needle.isEmpty else {
            throw BuiltinError.evalError(msg: "empty search character")  // matching go error
        }

        let range = haystack.range(of: needle)
        guard let range = range else {
            return .number(-1)
        }
        return .number(NSNumber(value: haystack.distance(from: haystack.startIndex, to: range.lowerBound)))
    }

    static func indexOfN(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack", got: args[0].typeName, want: "string")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle", got: args[1].typeName, want: "string")
        }

        // Special case to behave like the Go version does
        guard !needle.isEmpty else {
            throw BuiltinError.evalError(msg: "empty search character")  // matching go error
        }

        let ranges = haystack.allRanges(of: needle)
        return .array(
            ranges.map({ .number(NSNumber(value: haystack.distance(from: haystack.startIndex, to: $0.lowerBound))) }))
    }

    static func lower(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(x.lowercased())
    }

    // split returns an array containing elements of the input string split on a delimiter
    static func split(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard case .string(let delimiter) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter", got: args[1].typeName, want: "string")
        }

        // If sep is empty, Split splits after each UTF-8 sequence
        if delimiter.isEmpty {
            let chars: [AST.RegoValue] = x.map { .string(String($0)) }
            return .array(chars)
        }

        // Note String.split(separator:) behaves completely different and not how we need
        let parts = x.components(separatedBy: delimiter)
        return .array(parts.map { .string(String($0)) })
    }

    static func replace(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard case .string(let old) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "old", got: args[1].typeName, want: "string")
        }

        guard case .string(let new) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "new", got: args[2].typeName, want: "string")
        }

        return .string(x.replacingOccurrences(of: old, with: new))
    }

    static func reverse(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        return .string(String(String.UnicodeScalarView(value.unicodeScalars.reversed())))
    }

    static func sprintf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let format) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "format", got: args[0].typeName, want: "string")
        }

        guard case .array(let values) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "values", got: args[1].typeName, want: "array")
        }

        return .string(sprintfRegoValuesMostlyLikeHowGoDoes(format, values))
    }

    static func startsWith(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let search) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "search", got: args[0].typeName, want: "string")
        }

        guard case .string(let base) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "base", got: args[1].typeName, want: "string")
        }

        return .boolean(search.hasPrefix(base))
    }

    static func substring(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .number(_) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "offset", got: args[1].typeName, want: "number")
        }

        guard case .number(_) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "length", got: args[2].typeName, want: "number")
        }

        guard !args[1].isFloat, let offset = args[1].integerValue else {
            throw BuiltinError.evalError(msg: "operand 2 must be integer number but got floating-point number")
        }

        guard offset >= 0 else {
            throw BuiltinError.evalError(msg: "negative offset")
        }

        guard !args[2].isFloat, let length = args[2].integerValue else {
            throw BuiltinError.evalError(msg: "operand 3 must be integer number but got floating-point number")
        }

        if offset >= value.count || length == 0 {
            return .string("")
        }
        let startIdx = value.index(value.startIndex, offsetBy: Int(offset))

        if length < 0 || offset + length > value.count {
            return .string(String(value[startIdx...]))
        }
        let endIdx = value.index(startIdx, offsetBy: Int(length))

        return .string(String(value[startIdx..<endIdx]))
    }

    // trim returns value with all leading or trailing instances of the cutset characters removed.
    static func trim(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let cutset) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "cutset", got: args[1].typeName, want: "string")
        }

        let trimmedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: cutset))
        return .string(trimmedValue)
    }

    static func trimLeft(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let cutset) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "cutset", got: args[1].typeName, want: "string")
        }

        guard !value.isEmpty else {
            return .string("")
        }

        let characterSet = Set(cutset)
        let trimmedValue = value.drop(while: { characterSet.contains($0) })
        return .string(String(trimmedValue))
    }

    static func trimPrefix(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let prefix) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "prefix", got: args[1].typeName, want: "string")
        }

        guard value.hasPrefix(prefix) else {
            return .string(value)
        }
        return .string(String(value.dropFirst(prefix.count)))
    }

    static func trimRight(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let cutset) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "cutset", got: args[1].typeName, want: "string")
        }

        guard !value.isEmpty else {
            return .string("")
        }

        let characterSet = Set(cutset)
        // Start from the end of the string and check each character
        var idx = value.endIndex
        while idx > value.startIndex && characterSet.contains(value[value.index(before: idx)]) {
            idx = value.index(before: idx)
        }

        // Return the substring up to the last index found to NOT match the characters
        return .string(String(value[..<idx]))
    }

    static func trimSpace(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        let trimmedValue = value.trimmingCharacters(in: customWhitespace)
        return .string(trimmedValue)
    }

    static func trimSuffix(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let suffix) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "suffix", got: args[1].typeName, want: "string")
        }

        guard value.hasSuffix(suffix) else {
            return .string(value)
        }
        return .string(String(value.dropLast(suffix.count)))
    }

    static func upper(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(x.uppercased())
    }

    static func templateString(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .array(let parts) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "parts", got: args[0].typeName, want: "array")
        }

        return try .string(
            parts.map {
                switch $0 {
                case .string, .number, .boolean, .null:
                    return try stringifyRegoValue($0)
                case .set(let s):
                    if s.isEmpty {
                        return "<undefined>"
                    }

                    if s.count > 1 {
                        throw BuiltinError.halt(reason: "template-strings must not produce multiple outputs")
                    }

                    return try stringifyRegoValue(s.first!)
                default:
                    throw BuiltinError.halt(reason: "illegal argument type: " + $0.typeName)
                }
            }.joined())
    }
}

// stringifyRegoValue returns a string representation of a RegoValue as expected by OPA string-interpolation
// FIXME: Should this replace RegoValue+Codable stringification?
func stringifyRegoValue(_ v: RegoValue) throws -> String {
    if case .string(let s) = v {
        return s
    }

    return try stringifyValue(v)
}

func stringifyValue(_ v: RegoValue) throws -> String {
    if case .array(let a) = v {
        return try stringifyArray(a)
    }

    if case .set(let s) = v {
        return try stringifySet(s)
    }

    if case .object(let o) = v {
        return try stringifyObject(o)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.nonConformingFloatEncodingStrategy = .throw
    guard let output = String(data: try encoder.encode(v), encoding: .utf8) else {
        throw RegoValue.RegoEncodingError.invalidUTF8
    }
    return output
}

func stringifyArray(_ a: [RegoValue]) throws -> String {
    if a.isEmpty {
        return "[]"
    }

    var result: String = "["

    result.append(
        try a.map {
            return try stringifyValue($0)
        }.joined(separator: ", "))

    result.append("]")

    return result
}

func stringifySet(_ s: Set<RegoValue>) throws -> String {
    if s.isEmpty {
        return "set()"
    }

    var result: String = "{"

    result.append(
        try s.sorted().map {
            return try stringifyValue($0)
        }.joined(separator: ", "))

    result.append("}")

    return result
}

func stringifyObject(_ o: [RegoValue: RegoValue]) throws -> String {
    if o.isEmpty {
        return "{}"
    }

    var result: String = "{"

    result.append(
        try o.sorted {
            return $0.key < $1.key
        }.map {
            return try stringifyValue($0.key) + ": " + stringifyValue($0.value)
        }.joined(separator: ", "))

    result.append("}")

    return result
}

extension String {
    /// Returns all non-overlapping ranges in this string that match another string
    fileprivate func allRanges(
        of aString: String,
        options: String.CompareOptions = [],
        locale: Locale? = nil
    ) -> [Range<Index>] {
        var results: [Range<Index>] = []
        // We start from startIndex of the string OR,
        // if we have already detected matches, from an upper bound of the last match
        // to detect the next range of a substring in this string.
        // As we discover matching ranges, we add them to the list
        // and so the next crank of the loop always starts from the latest found range.
        // The loop halts when the range is no longer discovered over the remainder of
        // this string.
        while let r = self.range(
            of: aString,
            options: options,
            range: (results.last?.upperBound ?? startIndex)..<endIndex,
            locale: locale)
        {
            results.append(r)
        }

        return results
    }
}

private func sprintfRegoValuesMostlyLikeHowGoDoes(_ format: String, _ args: [AST.RegoValue]) -> String {
    var printer = SimilarToGoFmtPrinter(format, args)
    return printer.print()
}

private struct SimilarToGoFmtPrinter {
    // The spec: https://pkg.go.dev/fmt
    // The reference implemenation we're trying to imitate behavior of:
    //    https://cs.opensource.google/go/go/+/refs/tags/go1.23.5:src/fmt/print.go;l=1019
    //
    // This does a bunch of side-effect-y and somewhat hard to follow loops/conditions
    // but attempts to faithfully follow the go implementation to achieve not only the
    // same formatting output but also the same errors and edge case behaviors.
    //
    // Note that we take a few liberties with the implementation to only support the
    // subset of types that OPA's sprintf() builtin can process, additionally the
    // arguments are _always_ AST.RegoValues which puts additional constraints on the
    // complexity in the "real" fmt.Sprintf() implementation.

    struct FmtFlags {
        var plus: Bool = false
        var minus: Bool = false
        var sharp: Bool = false
        var space: Bool = false
        var zero: Bool = false
        var width: Int? = nil
        var precision: Int? = nil

        var sharpV: Bool = false
        var plusV: Bool = false

        var reorderedArgs: Bool = false
        var afterArgIndex: Bool = false
        var invalidArgIndex: Bool = false
    }

    struct StringConsts {
        static let nilAngle = "<nil>"
        static let percentBang = "%!"
        static let missing = "(MISSING)"
        static let badIndex = "(BADINDEX)"
        static let extra = "%!(EXTRA"
        static let badWidth = "%!(BADWIDTH)"
        static let badPrecision = "%!(BADPREC)"
        static let noVerb = "%!(NOVERB)"
    }

    var format: String
    var args: [AST.RegoValue] = []

    var result: String = ""

    var argIdx: Int = 0
    var fmtIdx: String.Index
    var startedFormat: Bool = false
    var flags: FmtFlags = FmtFlags()

    init(_ format: String, _ args: [AST.RegoValue]) {
        self.format = format
        self.args = args
        self.fmtIdx = format.startIndex
        self.currentChar = format[format.startIndex]
    }

    var currentChar: Character?

    mutating func setFormatIndex(_ idx: String.Index) {
        self.fmtIdx = idx
        if self.fmtIdx >= self.format.startIndex && self.fmtIdx < self.format.endIndex {
            self.currentChar = self.format[self.fmtIdx]
        } else {
            self.currentChar = nil
        }
    }

    mutating func next() -> Character? {
        guard self.fmtIdx < self.format.endIndex else {
            self.currentChar = nil
            return self.currentChar
        }
        self.fmtIdx = self.format.index(after: self.fmtIdx)
        if self.fmtIdx >= self.format.startIndex && self.fmtIdx < self.format.endIndex {
            self.currentChar = self.format[self.fmtIdx]
        } else {
            self.currentChar = nil
        }
        return self.currentChar
    }

    var currentArg: AST.RegoValue? {
        guard self.argIdx >= 0, self.argIdx < self.args.count else {
            return nil
        }
        return self.args[self.argIdx]
    }

    mutating func nextArg() -> AST.RegoValue? {
        self.argIdx += 1
        return self.currentArg
    }

    mutating func resetFlags() {
        self.flags = FmtFlags()
    }

    mutating func print() -> String {
        if self.format.isEmpty {
            return ""
        }
        var firstIteration = true
        while self.fmtIdx < self.format.endIndex {

            // TODO: *sigh* surely there is a better way to arrange this?
            // The issue being that next pattern works better with the rest of the flow logic,
            // but on the very first iteration we don't want to burn it. The ergonomics don't work
            // well with repeat-while either.
            guard let c = firstIteration ? self.currentChar : self.next() else {
                return self.result
            }
            if firstIteration {
                firstIteration = false
            }

            if c != "%" {
                self.result.append(c)
                continue
            }

            // Process the optional flags and verb following the % sign
            self.resetFlags()

            flagLoop: while self.fmtIdx < self.format.endIndex, let c = self.next() {
                switch c {
                case "#":
                    self.flags.sharp = true
                case "0":
                    self.flags.zero = true
                case "+":
                    self.flags.plus = true
                case "-":
                    self.flags.minus = true
                case " ":
                    self.flags.space = true
                default:
                    break flagLoop
                }
            }

            // We _might_ have a specific arg index (eg, "%[3]s"), process it now
            self.tryParseArgIndex()

            guard let c = self.currentChar else {
                self.result.append(StringConsts.noVerb)
                continue
            }

            // Check for a width field next, either "*" for an arg or explicit number
            if c == "*" {
                if let width = self.currentArg?.integerValue ?? nil {
                    self.flags.width = Int(width)

                    if self.flags.width! < 0 {
                        self.flags.width = abs(self.flags.width!)
                        self.flags.minus = true
                        self.flags.zero = false
                    }
                } else {
                    self.result.append(StringConsts.badWidth)
                }
                _ = self.nextArg()

                self.flags.afterArgIndex = false

                // increment past the "*"
                guard self.next() != nil else {
                    self.result.append(StringConsts.noVerb)
                    continue
                }
            } else {
                if let width = self.tryParseInt() {
                    self.flags.width = width

                    if self.flags.afterArgIndex {
                        // eg "%[3]2d" not allowed
                        self.flags.invalidArgIndex = true
                    }
                }
            }

            guard let c = self.currentChar else {
                self.result.append(StringConsts.noVerb)
                continue
            }

            // Next up is, potentially, a precision specifier
            if c == "." {
                if self.flags.afterArgIndex {
                    // eg "%[3].2d" not allowed
                    self.flags.invalidArgIndex = true
                }

                // Iterate past the "."
                guard self.next() != nil else {
                    self.result.append(StringConsts.noVerb)
                    continue
                }

                // We _might_ have a specific arg index (eg, "%3.[2]*f"), process it now
                self.tryParseArgIndex()

                guard let c = self.currentChar else {
                    self.result.append(StringConsts.noVerb)
                    continue
                }

                // See if there is an explict number or another * for an arg value
                if c == "*" {
                    if let prec = self.currentArg?.integerValue ?? nil {
                        self.flags.precision = Int(prec)

                        if self.flags.precision! < 0 {
                            // not valid
                            self.flags.precision = nil
                        }
                    } else {
                        self.result.append(StringConsts.badPrecision)
                    }
                    _ = self.nextArg()

                    // increment past the "*"
                    guard self.next() != nil else {
                        self.result.append(StringConsts.noVerb)
                        continue
                    }

                    self.flags.afterArgIndex = false
                } else {
                    self.flags.precision = self.tryParseInt() ?? 0
                }
            }

            guard let c = self.currentChar else {
                self.result.append(StringConsts.noVerb)
                continue
            }

            if !self.flags.afterArgIndex {
                // Check one more time for an argument index specifier
                self.tryParseArgIndex()
            }

            guard let verb = self.currentChar else {
                self.result.append(StringConsts.noVerb)
                continue
            }

            switch verb {
            case "%":
                result.append("%")
            case _ where self.flags.invalidArgIndex:
                self.result.append(StringConsts.percentBang)
                self.result.append(verb)
                self.result.append(StringConsts.badIndex)
            case _ where self.argIdx >= self.args.count:
                self.result.append(StringConsts.percentBang)
                self.result.append(verb)
                self.result.append(StringConsts.missing)
            case "w", "v":
                self.flags.sharpV = self.flags.sharp
                self.flags.sharp = false
                self.flags.plusV = self.flags.plus
                self.flags.plus = false
                fallthrough
            default:
                self.printCurrentArg(verb: c)
            }
        }

        // Matching the go fmt, we only complain about leftover args if
        // the format flags didn't call for a specific index.
        if !self.flags.reorderedArgs && (self.argIdx < self.args.count - 1) {
            self.resetFlags()
            self.result.append(StringConsts.extra)
            var first = true
            while let arg = self.currentArg {
                if first {
                    first = false
                } else {
                    self.result.append(", ")
                }
                self.result.append("\(type(of:arg))=")
                self.printCurrentArg(verb: "v")
                _ = self.nextArg()
            }
            self.result.append(")")
        }

        return self.result
    }

    mutating func tryParseArgIndex() {
        guard let c = self.currentChar, c == "[" else {
            return
        }

        // Note: On errors the go implementation only swallows the "[" character, we'll do the same
        // by incrementing a single time and preserving that index to reset our state to as needed.
        _ = self.next()
        let errIdx = self.fmtIdx

        // we need at least 3 characters, "[", x, "]", we've already processed one of them "["
        guard self.format.distance(from: self.fmtIdx, to: self.format.endIndex) > 2 else {
            self.setFormatIndex(errIdx)
            return
        }

        guard let argIdx = tryParseIntArg() else {
            self.setFormatIndex(errIdx)
            return
        }

        let nextArgIdx = argIdx - 1  // the format string arguments are 1-indexed

        guard nextArgIdx >= 0 && nextArgIdx < self.args.count else {
            self.flags.invalidArgIndex = true
            return
        }

        self.argIdx = nextArgIdx
        self.flags.reorderedArgs = true
    }

    mutating func tryParseIntArg() -> Int? {
        var n = 0
        repeat {
            guard let c = self.currentChar else {
                return nil
            }
            // expect only numbers and then a closing bracket "]"
            switch c {
            case "]":
                // consume the bracket and get out
                _ = self.next()
                return n
            case let c where c < "0" || c > "9":
                return nil

            default:
                break
            }
            guard !tooLarge(n) else {
                return nil
            }
            guard let cNum = Int(String(c)) else {
                return nil
            }
            n *= 10
            n += cNum
            _ = self.next()
        } while self.fmtIdx < self.format.endIndex
        return nil
    }

    mutating func tryParseInt() -> Int? {
        var n = 0
        var foundNum = false
        repeat {
            guard let c = self.currentChar else {
                return nil
            }
            if c < "0" || c > "9" {
                break
            }
            foundNum = true
            guard !tooLarge(n) else {
                return nil
            }
            guard let cNum = Int(String(c)) else {
                return nil
            }
            n *= 10
            n += cNum
            _ = self.next()
        } while self.fmtIdx < self.format.endIndex
        guard foundNum else {
            return nil
        }
        return n
    }

    func tooLarge(_ x: Int) -> Bool {
        // matching the go implementations limit on width/precision values
        return x > 100000
    }

    mutating func printCurrentArg(verb: Character) {
        guard let arg = self.currentArg else {
            switch verb {
            case "T", "v":
                self.result.append(StringConsts.nilAngle)
            default:
                self.printBadVerb(verb, nil)
            }
            return
        }
        defer { _ = self.nextArg() }

        switch verb {
        case "T":
            self.result.append("\(type(of: arg))")
            return
        case "p":
            // We don't support this for our use case, it appears OPA won't let it happen either
            self.printBadVerb(verb, arg)
            return
        default:
            break
        }

        // Fun fact, with OPA as the reference implementation, everything
        // except for number types is a string! Coerce them here and we'll
        // format those values as faithfully to the go fmt reference as
        // as we can.
        switch arg {
        case .number(let n):
            if let intVal = arg.integerValue {
                self.fmtInt(Int(intVal), verb)
            } else {
                self.fmtFloat(n, verb)
            }
        case .string(let s):
            self.fmtString(s, verb)
        default:
            do {
                let str = try String(arg)  // Stringify the RegoValue
                self.fmtString(str, verb)
            } catch {
                // Making this up.. it shouldn't happen but we need to put something in here on an error
                self.result.append("!%(JSON)")
            }
        }
    }

    mutating func printBadVerb(_ verb: Character, _ arg: AST.RegoValue?) {
        self.result.append("\(StringConsts.percentBang)\(String(verb))(")
        guard let arg = arg else {
            self.result.append(StringConsts.nilAngle)
            self.result.append(")")
            return
        }
        self.result.append("\(regoValueTypeNameToGoTypeName(arg.typeName))=")
        self.printCurrentArg(verb: "v")
        self.result.append(")")
    }

    func regoValueTypeNameToGoTypeName(_ name: String) -> String {
        switch name {
        case "number":
            return "int"
        default:
            return name
        }
    }

    mutating func fmtInt(_ n: Int, _ verb: Character) {
        switch verb {
        case "v":
            self.fmtInt(n, 10, verb, false)
        case "d":
            self.fmtInt(n, 10, verb, false)
        case "b":
            self.fmtInt(n, 2, verb, false)
        case "o", "O":
            self.fmtInt(n, 8, verb, false)
        case "x":
            self.fmtInt(n, 16, verb, false)
        case "X":
            self.fmtInt(n, 16, verb, true)
        case "c":
            self.fmtC(n)
        case "q":
            self.fmtQc(n)
        case "U":
            self.fmtUnicode(n)
        default:
            self.printBadVerb(verb, .number(NSNumber(value: n)))
        }
    }

    mutating func fmtInt(_ n: Int, _ base: Int, _ verb: Character, _ upperCase: Bool) {
        let isNegative = n < 0

        var precision = 0
        if let p = self.flags.precision {
            precision = p
            if precision == 0 && n == 0 {
                let oldZero = self.flags.zero
                self.flags.zero = false
                self.printPadding(self.flags.width ?? 0)
                self.flags.zero = oldZero
                return
            }
        } else if self.flags.zero, !self.flags.minus, let width = self.flags.width {
            precision = width
            if isNegative || self.flags.plus || self.flags.space {
                precision -= 1  // accouting for the '-'
            }
        }

        // Diverge a tad from the go implementation by cheating with the slick String initializer...
        let partiallyFormatted = String(n, radix: base)

        if isNegative {
            self.result.append("-")
        } else if self.flags.plus {
            self.result.append("+")
        }

        // Write any prefix that might be needed
        switch base {
        case 2 where self.flags.sharp:
            self.result.append("0b")
        case 8 where self.flags.sharp:
            if !partiallyFormatted.hasPrefix("0") {
                self.result.append("0")
            }
            fallthrough
        case 8 where verb == "O":
            self.result.append("0o")
        case 16 where self.flags.sharp:
            upperCase ? self.result.append("0X") : self.result.append("0x")
        default:
            break  // the go code panics, we'll just leave the string empty i guess?
        }

        let paddingLength = precision - partiallyFormatted.count
        if paddingLength > 0 {
            self.printPadding(paddingLength)
        }

        self.result.append(partiallyFormatted)
    }

    mutating func fmtFloat(_ n: NSNumber, _ verb: Character) {
        switch verb {
        case "v":
            self.fmtFloat(n, "g", -1)
        case "b", "g", "G", "x", "X":
            self.fmtFloat(n, verb, -1)
        case "f", "e", "E":
            self.fmtFloat(n, verb, 6)
        case "F":
            self.fmtFloat(n, "f", 6)
        default:
            self.printBadVerb(verb, .number(n))
        }
    }

    mutating func fmtFloat(_ n: NSNumber, _ verb: Character, _ precision: Int) {
        // Floats aren't going to match... just like.. basic ones should be OK,
        // but anything complicated, binary format, hex, etc are going to be off
        // since the OPA version is using Strings and arbitrary precision numbers
        // that differ too much. At some point if/when we unify the data type for
        // floats we can revisit this. In the meantime just delegate to the swift
        // formater and let it do its thing.
        let precision = self.flags.precision ?? precision
        var widthFlag = ""
        if let width = self.flags.width {
            widthFlag = "\(width)"
        }
        let zeroFlag = self.flags.zero ? "0" : ""
        let spaceFlag = self.flags.space ? " " : ""
        let plusFlag = self.flags.plus ? "+" : ""
        let minusFlag = self.flags.minus ? "-" : ""
        let sharpFlag = self.flags.sharp ? "#" : ""

        self.result.append(
            String(
                format: "%\(zeroFlag)\(spaceFlag)\(plusFlag)\(minusFlag)\(sharpFlag)\(widthFlag).\(precision)\(verb)",
                n.doubleValue))
        // nailed it
    }

    mutating func fmtString(_ string: String, _ verb: Character) {
        switch verb {
        case "v":
            if self.flags.sharpV {
                self.fmtQ(string)
            } else {
                self.fmtS(string)
            }
        case "s":
            self.fmtS(string)
        case "x":
            self.fmtSx(string, uppercase: false)
        case "X":
            self.fmtSx(string, uppercase: true)
        case "q":
            self.fmtQ(string)
        default:
            self.printBadVerb(verb, .string(string))
        }
    }

    mutating func fmtC(_ n: Int) {
        self.printPaddedString(intAsUnicode(n))
    }

    mutating func fmtQc(_ n: Int) {
        self.fmtQ(self.intAsUnicode(n))
    }

    mutating func fmtUnicode(_ n: Int) {
        var str = String(format: "U+%X", n)
        if self.flags.sharp {
            str.append(" '")
            str.append(self.intAsUnicode(n))
            str.append("'")
        }
        self.printPaddedString(str)

    }

    func intAsUnicode(_ n: Int) -> String {
        guard let unicodeScalar = UnicodeScalar(n) else {
            return "\u{FFFD}"
        }
        return String(unicodeScalar)
    }

    mutating func fmtQ(_ string: String) {
        let string = self.truncateString(string)
        if self.flags.sharp && self.canBackquote(string) {
            self.printPaddedString("`" + string + "`")
            return
        }

        var escapedString = ""
        for c in string {
            switch c {
            case "\\":
                escapedString.append("\\\\")
            case "\"":
                escapedString.append("\\\"")
            case _ where !c.isASCII && self.flags.plus:
                escapedString.append(unicodeToAsciiEscapeString(c))
            default:
                escapedString.append(c)
            }
        }
        self.printPaddedString("\"" + escapedString + "\"")
    }

    func canBackquote(_ string: String) -> Bool {
        guard !string.isEmpty else {
            return true
        }
        for c in string {
            if c.isASCII {
                if c < " " || c == "\t" || c == "`" || c == "\u{007F}" {
                    return false
                }
            } else if c == "\u{FEFF}" {
                return false
            }
        }
        return true
    }

    func unicodeToAsciiEscapeString(_ c: Character) -> String {
        guard !c.isASCII, let unicodeScalar = c.unicodeScalars.first else {
            return String(c)
        }
        return unicodeScalar.value <= 127 ? String(c) : String(format: "\\u{%04X}", unicodeScalar.value)
    }

    mutating func fmtS(_ string: String) {
        // Print the string taking in to account any width and precision specified
        self.printPaddedString(self.truncateString(string))
    }

    mutating func fmtSx(_ string: String, uppercase: Bool) {
        // Is it OK to use utf8? This _should_ match up with the go string -> bytes behavior
        guard let data = string.data(using: .utf8) else {
            return
        }

        let length = self.flags.precision ?? string.count
        var encodedWidth = 2 * length

        guard encodedWidth > 0 else {
            // its empty... but we still need to respect the padding
            self.printPaddedString("")
            return
        }

        if self.flags.space {
            if self.flags.sharp {
                encodedWidth *= 2  // account for "0x" prefixes on every byte representation
            }
            // account for space between bytes
            encodedWidth += length - 1
        } else if self.flags.sharp {
            encodedWidth += 2  // only one "0x" prefix for the whole string
        }

        // left padding
        if !self.flags.minus, let width = self.flags.width, width > encodedWidth {
            self.printPadding(width - encodedWidth)
        }

        let hexPrefix = uppercase ? "0X" : "0x"
        let byteFmt = uppercase ? "%02X" : "%02x"

        var firstByte = true
        for byte in data {
            if firstByte {
                if self.flags.sharp {
                    self.result.append(contentsOf: hexPrefix)
                }
                firstByte = false
            } else if self.flags.space {
                self.result.append(" ")
                if self.flags.sharp {
                    self.result.append(hexPrefix)
                }
            }

            self.result.append(String(format: byteFmt, byte))
        }

        // right padding
        if self.flags.minus, let width = self.flags.width, width > encodedWidth {
            self.printPadding(width - encodedWidth)
        }
    }

    func truncateString(_ string: String) -> String {
        guard let length = self.flags.precision, length > 0 else { return string }

        let stringLength = string.count
        guard stringLength <= length else {
            return String(string.prefix(length))
        }
        return string
    }

    mutating func printPaddedString(_ string: String) {
        guard let width = self.flags.width, width > 0 else {
            self.result.append(string)
            return
        }

        let paddingSize = width - string.count
        if !self.flags.minus {
            // left padding
            self.printPadding(paddingSize)
            self.result.append(string)
        } else {
            // right padding
            self.result.append(string)
            self.printPadding(paddingSize)
        }
    }

    mutating func printPadding(_ count: Int) {
        guard count > 0 else { return }

        var padChar = " "
        if self.flags.zero && !self.flags.minus {
            padChar = "0"
        }
        self.result.append(String(repeating: padChar, count: count))
    }

}
