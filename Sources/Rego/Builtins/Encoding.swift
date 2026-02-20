import AST
import Foundation

extension BuiltinFuncs {
    // MARK: - base64.encode
    static func base64Encode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).base64EncodedString())
    }

    // MARK: - base64.decode
    static func base64Decode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
    static func base64IsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .boolean(Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0)) != nil)
    }

    // MARK: - base64url.encode
    static func base64UrlEncode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
    static func base64UrlEncodeNoPad(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
    static func base64UrlDecode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
    static func hexEncode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).hexEncoded)
    }

    // MARK: - hex.decode
    static func hexDecode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
    public static func jsonIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let rawJSON) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        let parsedOK = (try? JSONDecoder().decode(RegoValue.self, from: rawJSON.data(using: .utf8)!)) != nil

        // The result of the JSON parsing should be nil if parsing fails, or we got an empty input.
        return AST.RegoValue(booleanLiteral: parsedOK)
    }

    // MARK: - json.marshal
    /// Serializes the input term to JSON.
    public static func jsonMarshal(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        let data = try JSONEncoder().encode(args[0])
        guard let json = String(data: data, encoding: .utf8) else {
            throw Rego.RegoError(code: .internalError, message: "json.marshal: failed to encode JSON as utf-8")
        }

        return AST.RegoValue(stringLiteral: json)
    }

    // MARK: - json.marshal_with_options
    /// Serializes the input term to JSON, using formatting options.
    public static func jsonMarshalWithOptions(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue
    {
        // guard args.count == 2 else {
        //     throw Rego.BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        // }

        // guard case .object(let options) = args[1] else {
        //     throw BuiltinError.argumentTypeMismatch(arg: "opts", got: args[1].typeName, want: "object")
        // }
        // guard case .boolean(let pretty) = options["pretty"] else {
        //     throw BuiltinError.argumentTypeMismatch(arg: "opts.pretty", got: options["pretty"]?.typeName, want: "boolean")
        // }

        // var encoder = JSONEncoder()
        // if options.pretty {
        //     encoder.outputFormatting = .prettyPrinted
        // }

        // let data = try JSONEncoder().encode(args[0])
        // guard let json = String(data: data, encoding: .utf8) else {
        //     throw Rego.RegoError(code: .internalError, message: "json.marshal: failed to encode JSON as utf-8")
        // }

        // return AST.RegoValue(stringLiteral: json)
        return ""
    }

    // MARK: - json.unmarshal
    /// Deserializes the input JSON string to a term.
    public static func jsonUnmarshal(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
