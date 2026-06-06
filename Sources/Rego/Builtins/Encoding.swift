import AST
import Foundation

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
    public static func jsonMarshalWithOptions(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue
    {
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
