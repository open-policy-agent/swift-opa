import AST
import Foundation

/// Used by ``BuiltinFuncs/urlQueryEncodeObject(ctx:args:)`` for any
/// non-conforming input shape.
private let urlEncodeObjectErrMessage =
    "operand 1 values must be string, array[string], or set[string]"

extension BuiltinFuncs {
    // MARK: - base64.encode
    static func base64Encode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).base64EncodedString())
    }

    // MARK: - base64.decode
    static func base64Decode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard let data = Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            throw BuiltinError.evalError(msg: "invalid base64 string")
        }

        return .string(String(decoding: data, as: UTF8.self))
    }

    // MARK: - base64.is_valid
    static func base64IsValid(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .boolean(Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0)) != nil)
    }

    // MARK: - base64url.encode
    static func base64UrlEncode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        // See corresponding Golang implementation differences in encoding/base64/base64.go
        let encoded = Data(x.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        return .string(encoded)
    }

    // MARK: - base64url.encode_no_pad
    static func base64UrlEncodeNoPad(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        // Same as base64URL encoding, without the padding at the end
        let encoded = Data(x.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return .string(encoded)
    }

    // MARK: - base64url.decode
    static func base64UrlDecode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(var x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        // base64url.decode supports decoding both padded and unpadded strings
        let paddingLength = x.count % 4 == 0 ? 0 : 4 - (x.count % 4)

        x = x.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: x.count + paddingLength, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            throw BuiltinError.evalError(msg: "invalid base64 string")
        }

        return .string(String(decoding: data, as: UTF8.self))
    }

    // MARK: - hex.encode
    static func hexEncode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).hexEncoded)
    }

    // MARK: - hex.decode
    static func hexDecode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard
            let hexDecoded = Data.fromHexEncoded(hex: x)
                .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            throw BuiltinError.evalError(msg: "invalid hex string")
        }

        return .string(hexDecoded)
    }

    // MARK: - json.is_valid
    /// Verifies the input string is a valid JSON document.
    public static func jsonIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let rawJSON) = args[0] else {
            return AST.RegoValue(booleanLiteral: false)
        }

        let parsedOK = (try? JSONDecoder().decode(RegoValue.self, from: rawJSON.data(using: .utf8)!)) != nil

        // The result of the JSON parsing should be nil if parsing fails, or we got an empty input.
        return AST.RegoValue(booleanLiteral: parsedOK)
    }

    // MARK: - json.marshal
    /// Serializes the input term to JSON.
    public static func jsonMarshal(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(args[0])
        return .string(htmlEscapeJSON(String(decoding: data, as: UTF8.self)))
    }

    // MARK: - json.marshal_with_options
    /// Serializes the input term to JSON, with additional formatting options.
    ///
    /// Pretty-printed output mimics Go's `json.MarshalIndent` style.
    ///
    /// Known discrepancies (may also apply to `json.marshal`):
    /// - Special line terminator unicode characters are not escaped.
    /// - Floating-point formatting may diverge at the edges (very large
    ///   magnitudes, scientific-notation thresholds, trailing-zero handling)
    ///   between Swift's `JSONEncoder` and Go's `strconv.AppendFloat`.
    public static func jsonMarshalWithOptions(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object(let options) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "opts", got: args[1].typeName, want: "object")
        }

        var indentWith = "\t"
        var prefixWith = ""
        var sawIndentOrPrefix = false
        var explicitPretty: Bool? = nil

        for (key, val) in options {
            guard case .string(let keyStr) = key else {
                throw BuiltinError.argumentTypeMismatch(arg: "opts.key", got: key.typeName, want: "string")
            }

            switch keyStr {
            case "prefix":
                guard case .string(let prefixOpt) = val else {
                    throw BuiltinError.argumentTypeMismatch(arg: "opts.prefix", got: val.typeName, want: "string")
                }
                prefixWith = prefixOpt
                sawIndentOrPrefix = true

            case "indent":
                guard case .string(let indentOpt) = val else {
                    throw BuiltinError.argumentTypeMismatch(arg: "opts.indent", got: val.typeName, want: "string")
                }
                indentWith = indentOpt
                sawIndentOrPrefix = true

            case "pretty":
                guard case .boolean(let b) = val else {
                    throw BuiltinError.argumentTypeMismatch(arg: "opts.pretty", got: val.typeName, want: "boolean")
                }
                explicitPretty = b

            default:
                throw Rego.RegoError(
                    code: .internalError, message: "json.marshal_with_options: unknown key '\(keyStr)'")
            }
        }

        // If the user didn't explicitly set "pretty", infer from whether
        // "prefix" or "indent" was provided (matching Go behavior).
        let shouldPrettyPrint = explicitPretty ?? sawIndentOrPrefix

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(args[0])
        let json = htmlEscapeJSON(String(decoding: data, as: UTF8.self))

        guard shouldPrettyPrint else {
            return .string(json)
        }

        // Reformat compact JSON into Golang's MarshalIndent style.
        return .string(prettyPrintGolangStyle(json: json, indentWith: indentWith, prefixWith: prefixWith))
    }

    // MARK: - json.unmarshal
    /// Deserializes the input JSON string to a term.
    public static func jsonUnmarshal(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let rawJSON) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        // Returns the parsed RegoValue, or throws an error.
        return try JSONDecoder().decode(RegoValue.self, from: rawJSON.data(using: .utf8)!)
    }

    // MARK: - urlquery.encode
    /// URL-encodes a string. Mirrors Go's `net/url.QueryEscape`: spaces become
    /// `+`; all bytes except `A-Z a-z 0-9 - _ . ~` become `%XX`.
    public static func urlQueryEncode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let s) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }
        return .string(queryEscape(s))
    }

    // MARK: - urlquery.decode
    /// URL-decodes a string. Mirrors Go's `net/url.QueryUnescape`: `+` becomes
    /// space, `%XX` becomes the byte, malformed `%` escapes throw.
    public static func urlQueryDecode(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let s) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }
        return .string(try queryUnescape(s))
    }

    // MARK: - urlquery.encode_object
    /// Encodes an object as a URL query string. String values produce one
    /// `k=v` pair; arrays/sets produce one pair per element. Object keys are
    /// emitted in sorted order; arrays preserve element order; sets are sorted
    /// for determinism.
    public static func urlQueryEncodeObject(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .object(let obj) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        // Collect (key, value) pairs with string keys; sort by key for stable output.
        var entries: [(String, AST.RegoValue)] = []
        entries.reserveCapacity(obj.count)
        for (key, val) in obj {
            guard case .string(let k) = key else {
                throw BuiltinError.evalError(msg: urlEncodeObjectErrMessage)
            }
            entries.append((k, val))
        }
        entries.sort { $0.0 < $1.0 }

        var pairs: [String] = []
        for (k, val) in entries {
            let escapedKey = queryEscape(k)
            switch val {
            case .string(let s):
                pairs.append("\(escapedKey)=\(queryEscape(s))")
            case .array(let arr):
                for elem in arr {
                    guard case .string(let s) = elem else {
                        throw BuiltinError.evalError(msg: urlEncodeObjectErrMessage)
                    }
                    pairs.append("\(escapedKey)=\(queryEscape(s))")
                }
            case .set(let set):
                var members: [String] = []
                members.reserveCapacity(set.count)
                for elem in set {
                    guard case .string(let s) = elem else {
                        throw BuiltinError.evalError(msg: urlEncodeObjectErrMessage)
                    }
                    members.append(s)
                }
                members.sort()
                for s in members {
                    pairs.append("\(escapedKey)=\(queryEscape(s))")
                }
            default:
                throw BuiltinError.evalError(msg: urlEncodeObjectErrMessage)
            }
        }

        return .string(pairs.joined(separator: "&"))
    }

    // MARK: - urlquery.decode_object
    /// Parses a URL query string into an object. Each key maps to an array of
    /// values, since the same key may appear multiple times. Parameters with
    /// no `=` decode to an empty-string value (e.g. `b` → `"b": [""]`).
    public static func urlQueryDecodeObject(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let s) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard !s.isEmpty else {
            return .object([:])
        }

        var values: [String: [AST.RegoValue]] = [:]
        // Match Go's `url.ParseQuery`: skip empty `&` pairs (so leading,
        // trailing, and consecutive `&` are all dropped) and skip the lone
        // `=` pair where both key and value are empty.
        for pair in s.split(separator: "&", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = String(parts[0])
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            if rawKey.isEmpty && rawValue.isEmpty { continue }
            let key = try queryUnescape(rawKey)
            let value = try queryUnescape(rawValue)
            values[key, default: []].append(.string(value))
        }

        var result: [AST.RegoValue: AST.RegoValue] = [:]
        result.reserveCapacity(values.count)
        for (k, vs) in values {
            result[.string(k)] = .array(vs)
        }
        return .object(result)
    }
}

/// Helper extension to the Data to encode and decode hex strings
extension Data {
    /// Initialize Data with a Hex-Encoded String
    static func fromHexEncoded(hex: String) -> Data? {
        // Ensure that input string has even length
        // Note that empty string of length 0 is okay - it produces an empty loop below and resylts
        guard hex.count % 2 == 0 else {
            return nil
        }
        // Each character is represented by TWO characters in the input hex string
        var d = Data.init(capacity: hex.count / 2)

        for i in stride(from: 0, to: hex.count, by: 2) {
            // Extract a two-character element starting at index I
            let startIndex = hex.index(hex.startIndex, offsetBy: i)
            let stopIndex = hex.index(startIndex, offsetBy: 2)
            let element = hex[startIndex..<stopIndex]
            // Try to convert extracted element to UInt8 with base 16
            // Exit with nil data if any conversion fails
            guard let byte = UInt8(element, radix: 16) else {
                return nil
            }
            d.append(byte)
        }

        return d
    }

    /// Hex Encoding the Data.
    /// Note that this may need to be optimized based on the perf testing.
    var hexEncoded: String {
        self.map { String(format: "%02x", $0) }.joined()
    }

    /// Hex Encoding the Data with a given separator
    func hexEncodedWithSeparator(separator: String = "") -> String {
        self.map { String(format: "%02x", $0) }.joined(separator: separator)
    }
}

/// Post-processes JSON output to match Go's default HTML escaping.
/// Characters `<`, `>`, `&` are rewritten to their JSON Unicode-escape forms.
private func htmlEscapeJSON(_ json: String) -> String {
    var out = [UInt8]()
    out.reserveCapacity(json.utf8.count)
    for b in json.utf8 {
        switch b {
        case UInt8(ascii: "&"):
            out.append(contentsOf: [0x5c, 0x75, 0x30, 0x30, 0x32, 0x36])  // "&" -> "\u0026"
        case UInt8(ascii: "<"):
            out.append(contentsOf: [0x5c, 0x75, 0x30, 0x30, 0x33, 0x63])  // "<" -> "\u003c"
        case UInt8(ascii: ">"):
            out.append(contentsOf: [0x5c, 0x75, 0x30, 0x30, 0x33, 0x65])  // ">" -> "\u003e"
        default:
            out.append(b)
        }
    }
    return String(decoding: out, as: UTF8.self)
}

/// Single-pass pretty-printer over compact JSON.
/// Emits Go-style indented output, with no extra space before colon,
/// empty collections collapsed, prefix on every line.
///
/// Warning: This function does not validate the structure of the incoming
/// JSON text. It presumes that validation is done beforehand for speed.
private func prettyPrintGolangStyle(json: String, indentWith: String, prefixWith: String) -> String {
    let utf8 = json.utf8
    var out = [UInt8]()
    out.reserveCapacity(utf8.count * 2)  // rough estimate

    let quote = UInt8(ascii: "\"")
    let backslash = UInt8(ascii: "\\")
    let colon = UInt8(ascii: ":")
    let comma = UInt8(ascii: ",")
    let lbrace = UInt8(ascii: "{")
    let rbrace = UInt8(ascii: "}")
    let lbracket = UInt8(ascii: "[")
    let rbracket = UInt8(ascii: "]")
    let newline = UInt8(ascii: "\n")

    let indentBytes = Array(indentWith.utf8)
    let prefixBytes = Array(prefixWith.utf8)

    @inline(__always)
    func writeNewlineAndIndent(depth: Int) {
        out.append(newline)
        out.append(contentsOf: prefixBytes)
        for _ in 0..<depth {
            out.append(contentsOf: indentBytes)
        }
    }

    var depth = 0
    var inString = false
    var i = utf8.startIndex

    // Append prefix before the first line's content.
    out.append(contentsOf: prefixBytes)

    while i < utf8.endIndex {
        let byte = utf8[i]

        // Inside a JSON string: pass through, respecting escapes.
        if inString {
            out.append(byte)
            if byte == backslash {
                // Skip the escaped character verbatim
                let next = utf8.index(after: i)
                if next < utf8.endIndex {
                    out.append(utf8[next])
                    i = utf8.index(after: next)
                    continue
                }
            } else if byte == quote {
                inString = false
            }
            i = utf8.index(after: i)
            continue
        }

        // Outside a string: process lexical elements, tracking depth.
        switch byte {
        case quote:
            inString = true
            out.append(byte)

        case lbrace, lbracket:
            // Peek ahead: if the very next char is the matching close,
            // emit the pair collapsed (e.g. `{}` or `[]`).
            let next = utf8.index(after: i)
            let closeByte = (byte == lbrace) ? rbrace : rbracket
            if next < utf8.endIndex && utf8[next] == closeByte {
                out.append(byte)
                out.append(closeByte)
                i = utf8.index(after: next)
                continue
            }
            depth += 1
            out.append(byte)
            writeNewlineAndIndent(depth: depth)

        case rbrace, rbracket:
            depth -= 1
            writeNewlineAndIndent(depth: depth)
            out.append(byte)

        case comma:
            out.append(byte)
            writeNewlineAndIndent(depth: depth)

        case colon:
            out.append(byte)
            out.append(UInt8(ascii: " "))

        default:
            // digits, true/false/null literals, etc.
            out.append(byte)
        }

        i = utf8.index(after: i)
    }

    return String(decoding: out, as: UTF8.self)
}

// MARK: - URL query escape helpers

/// Go `net/url.QueryEscape`: keep `A-Z a-z 0-9 - _ . ~` literal, encode space
/// as `+`, percent-encode everything else as `%XX` (uppercase hex).
private func queryEscape(_ s: String) -> String {
    var out = [UInt8]()
    out.reserveCapacity(s.utf8.count)
    for byte in s.utf8 {
        switch byte {
        case 0x20:  // space
            out.append(UInt8(ascii: "+"))
        case 0x41...0x5A,  // A-Z
            0x61...0x7A,  // a-z
            0x30...0x39,  // 0-9
            0x2D, 0x2E, 0x5F, 0x7E:  // - . _ ~
            out.append(byte)
        default:
            out.append(UInt8(ascii: "%"))
            out.append(hexNibble(byte >> 4))
            out.append(hexNibble(byte & 0x0F))
        }
    }
    return String(decoding: out, as: UTF8.self)
}

/// Go `net/url.QueryUnescape`: `+` → space, `%XX` → byte, malformed `%`
/// throws `BuiltinError.evalError`. Error text matches Go's `url.EscapeError`
/// format: `invalid URL escape "<bad>"`, where `<bad>` is the offending
/// substring starting at `%` and capped at 3 bytes — same rule Go uses.
private func queryUnescape(_ s: String) throws -> String {
    let bytes = Array(s.utf8)
    var out = [UInt8]()
    out.reserveCapacity(bytes.count)
    var i = 0
    while i < bytes.count {
        let b = bytes[i]
        switch b {
        case UInt8(ascii: "+"):
            out.append(0x20)
            i += 1
        case UInt8(ascii: "%"):
            guard i + 2 < bytes.count,
                let h1 = hexValue(bytes[i + 1]),
                let h2 = hexValue(bytes[i + 2])
            else {
                let end = Swift.min(i + 3, bytes.count)
                let bad = String(decoding: bytes[i..<end], as: UTF8.self)
                throw BuiltinError.evalError(msg: "invalid URL escape \"\(bad)\"")
            }
            out.append(UInt8((h1 << 4) | h2))
            i += 3
        default:
            out.append(b)
            i += 1
        }
    }
    return String(decoding: out, as: UTF8.self)
}

/// Maps a 4-bit nibble (0-15) to its uppercase ASCII hex digit (`'0'`-`'9'`,
/// `'A'`-`'F'`). Used by `queryEscape` to format `%XX` percent-escapes.
private func hexNibble(_ n: UInt8) -> UInt8 {
    return n < 10 ? n &+ UInt8(ascii: "0") : n &- 10 &+ UInt8(ascii: "A")
}

/// Inverse of `hexNibble` (case-insensitive). Returns the integer value of an
/// ASCII hex digit, or `nil` if `b` is not a hex digit. Used by
/// `queryUnescape` to parse `%XX` percent-escapes.
private func hexValue(_ b: UInt8) -> Int? {
    switch b {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(b) - Int(UInt8(ascii: "0"))
    case UInt8(ascii: "A")...UInt8(ascii: "F"): return Int(b) - Int(UInt8(ascii: "A")) + 10
    case UInt8(ascii: "a")...UInt8(ascii: "f"): return Int(b) - Int(UInt8(ascii: "a")) + 10
    default: return nil
    }
}
