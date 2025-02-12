import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Encoding")
struct EncodingTests {
    static let base64EncodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "encodes empty string",
            name: "base64.encode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string",
            name: "base64.encode",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="))
        ),
    ]

    static let base64DecodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "decodes empty string",
            name: "base64.decode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "decodes a valid base64 string",
            name: "base64.decode",
            args: ["TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="],
            expected: .success(.string("Lorem ipsum dolor sit amet"))
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for an invalid base64 string",
            name: "base64.decode",
            args: ["this is not a valid base64 input"],
            expected: .success(.undefined)
        ),
    ]

    static let base64IsValidTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "returns true for empty string",
            name: "base64.is_valid",
            args: [""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "returns true for a valid base64 string",
            name: "base64.is_valid",
            args: ["TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "returns false for an invalid base64 string",
            name: "base64.is_valid",
            args: ["this is not a valid base64 input"],
            expected: .success(false)
        ),
    ]

    static let hexEncodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "encodes empty string",
            name: "hex.encode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string",
            name: "hex.encode",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("4c6f72656d20697073756d20646f6c6f722073697420616d6574"))
        ),
    ]

    static let hexDecodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "decodes empty string",
            name: "hex.decode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "decodes a string",
            name: "hex.decode",
            args: ["4c6f72656d20697073756d20646f6c6f722073697420616d6574"],
            expected: .success(.string("Lorem ipsum dolor sit amet"))
        ),
        BuiltinTests.TestCase(
            description: "decodes a string from uppercase hex",
            name: "hex.decode",
            args: ["4C6F72656D20697073756D20646F6C6F722073697420616D6574"],
            expected: .success(.string("Lorem ipsum dolor sit amet"))
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for an invalid hex string",
            name: "hex.decode",
            args: ["fghijkl"],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for an odd-sized hex string",
            name: "hex.decode",
            args: ["4c6f726"],
            expected: .success(.undefined)
        ),
    ]

    static let base64UrlEncodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "encodes empty string",
            name: "base64url.encode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string",
            name: "base64url.encode",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string which should produce diffrent base64 and base64url encodings",
            name: "base64url.encode",
            args: ["\u{FFFD}~"],
            expected: .success(.string("77-9fg==")) // Note - character - it is NOT in base64 alphabet, base64 would produce a + there
        ),
    ]

    static let base64UrlDecodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "decodes empty string",
            name: "base64url.decode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "decodes a valid base64 string",
            name: "base64url.decode",
            args: ["TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="],
            expected: .success(.string("Lorem ipsum dolor sit amet"))
        ),
        BuiltinTests.TestCase(
            description: "decodes a valid base64url string which is not a valid base64 string",
            name: "base64url.decode",
            args: ["77-9fg=="],
            expected: .success(.string("\u{FFFD}~"))
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for an invalid base64 string",
            name: "base64url.decode",
            args: ["this is not a valid base64 input"],
            expected: .success(.undefined)
        ),
    ]

    
    static var allTests: [BuiltinTests.TestCase] {
        [
            generateFailureTests(name: "base64.encode"),
            base64EncodeTests,
            generateFailureTests(name: "base64.decode"),
            base64DecodeTests,
            generateFailureTests(name: "base64.is_valid"),
            base64IsValidTests,
            generateFailureTests(name: "base64url.encode"),
            base64UrlEncodeTests,
            generateFailureTests(name: "base64url.decode"),
            base64UrlDecodeTests,
            generateFailureTests(name: "hex.encode"),
            hexEncodeTests,
            generateFailureTests(name: "hex.decode"),
            hexDecodeTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    // For Base64 tests, we will generate standard list of expected failures,
    // covering arguments size checks and inputs of invalid type.
    // Name argument is expected to match the builtin's name.
    static func generateFailureTests(name: String) -> [BuiltinTests.TestCase] {
        return [
            BuiltinTests.TestCase(
                description: "wrong number of arguments (too few)",
                name: name,
                args: [],
                expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
            ),
            BuiltinTests.TestCase(
                description: "wrong number of arguments (too many)",
                name: name,
                args: [1, 2, 3],
                expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 1))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - array",
                name: name,
                args: [[1, 2, 3]],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "array", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - boolean",
                name: name,
                args: [true],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "boolean", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - null",
                name: name,
                args: [.null],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "null", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - number",
                name: name,
                args: [123],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "number", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - object",
                name: name,
                args: [["a": 1]],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "object", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - set",
                name: name,
                args: [.set([0])],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "set", want: "string"))
            ),
            BuiltinTests.TestCase(
                description: "incorrect argument type - undefined",
                name: name,
                args: [.undefined],
                expected: .failure(
                    BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x", got: "undefined", want: "string"))
            ),
        ]
    }
}
