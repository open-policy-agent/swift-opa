import AST
import Foundation

extension BuiltinFuncs {
    static func base64Encode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).base64EncodedString())
    }

    static func base64Decode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard
            let base64Decoded = Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0))
                .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            return .undefined
        }

        return .string(base64Decoded)
    }

    static func base64IsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard
            Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0))
                .flatMap({ String(data: $0, encoding: .utf8) }) != nil
        else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func base64UrlEncode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
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

    static func base64UrlDecode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(var x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        x = x.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")

        guard
            let base64Decoded = Data(base64Encoded: x, options: Data.Base64DecodingOptions(rawValue: 0))
                .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            return .undefined
        }

        return .string(base64Decoded)
    }

    static func hexEncode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(Data(x.utf8).map { String(format: "%02x", $0) }.joined())
    }

    static func hexDecode(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard
            let hexDecoded = Data(hex: x)
                .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            return .undefined
        }

        return .string(hexDecoded)
    }
}

// Helper extension to the Data to decode hex strings
extension Data {
    fileprivate init?(hex: String) {
        // Ensure that input string has even length
        // Note that empty string of length 0 is okay - it produces an empty loop below and resylts
        guard hex.count % 2 == 0 else {
            return nil
        }
        // Each character is represented by TWO characters in the input hex string
        self.init(capacity: hex.count / 2)

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
            self.append(byte)
        }
    }
}
