import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Encoding", .tags(.builtins))
    struct EncodingTests {}
}

extension BuiltinTests.EncodingTests {

    // MARK: - base64.encode Tests
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

    // MARK: - base64.decode Tests
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
            expected: .failure(BuiltinError.evalError(msg: "invalid base64 string"))
        ),
    ]

    // MARK: - base64.is_valid Tests
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

    // MARK: - hex.encode Tests
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

    // MARK: - hex.decode Tests
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
            description: "invalid hex string",
            name: "hex.decode",
            args: ["fghijkl"],
            expected: .failure(BuiltinError.evalError(msg: "invalid hex string"))
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for an odd-sized hex string",
            name: "hex.decode",
            args: ["4c6f726"],
            expected: .failure(BuiltinError.evalError(msg: "invalid hex string"))
        ),
    ]

    // MARK: - base64url.encode Tests
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
            // Note - character - it is NOT in base64 alphabet, base64 would produce a + there
            expected: .success(.string("77-9fg=="))
        ),
    ]

    // MARK: - base64url.encode_no_pad Tests
    static let base64UrlEncodeNoPadTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "encodes empty string",
            name: "base64url.encode_no_pad",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string",
            name: "base64url.encode_no_pad",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ"))
        ),
        BuiltinTests.TestCase(
            description: "encodes a string which should produce diffrent base64 and base64url encodings",
            name: "base64url.encode_no_pad",
            args: ["\u{FFFD}~"],
            // Note - character - it is NOT in base64 alphabet, base64 would produce a + there
            expected: .success(.string("77-9fg"))
        ),
    ]

    // MARK: - base64url.decode Tests
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
            description: "decodes an unpadded valid base64 string",
            name: "base64url.decode",
            args: ["TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ"],
            expected: .success(.string("Lorem ipsum dolor sit amet"))
        ),
        BuiltinTests.TestCase(
            description: "decodes a valid base64url string which is not a valid base64 string",
            name: "base64url.decode",
            args: ["77-9fg=="],
            expected: .success(.string("\u{FFFD}~"))
        ),
        BuiltinTests.TestCase(
            description: "decodes an unpadded valid base64url string which is not a valid base64 string",
            name: "base64url.decode",
            args: ["77-9fg"],
            expected: .success(.string("\u{FFFD}~"))
        ),
        BuiltinTests.TestCase(
            description: "invalid base64 string",
            name: "base64url.decode",
            args: ["this is not a valid base64 input"],
            expected: .failure(BuiltinError.evalError(msg: "invalid base64 string"))
        ),
    ]

    // MARK: - json.is_valid Tests
    static let jsonIsValidTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "invalid - empty string",
            name: "json.is_valid",
            args: ["plainstring"],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "invalid - unquoted string",
            name: "json.is_valid",
            args: ["plainstring"],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "invalid - unclosed brace",
            name: "json.is_valid",
            args: ["{"],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "valid - simple object",
            name: "json.is_valid",
            args: ["{\"json\": \"ok\"}"],
            expected: .success(.boolean(true))
        ),
    ]

    // MARK: - json.marshal Tests
    static let jsonMarshalTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "marshal aggregate rego types",
            name: "json.marshal",
            args: [
                [["foo": .set([1, 2, 3, true, nil])]]
            ],
            expected: .success(.string("[{\"foo\":[null,true,1,2,3]}]"))
        ),
        BuiltinTests.TestCase(
            description: "marshal large integers",
            name: "json.marshal",
            args: [
                .array([.number(1_234_500_000 + 67890), .number(1e6 * 2), .number(1e109 / 1e100)])
            ],
            expected: .success(.string("[1234567890,2000000,1000000000]"))
        ),
    ]

    // MARK: - json.marshal_with_options Tests
    // static let jsonMarshalWithOptionsTests: [BuiltinTests.TestCase] = [
    //     BuiltinTests.TestCase(
    //         description: "marshal large integers",
    //         name: "json.marshal_with_options",
    //         args: [
    //             .array([.number(1_234_500_000 + 67890), .number(1e6 * 2), .number(1e109 / 1e100)]),
    //             ["indent": "  "],
    //         ],
    //         expected: .success(
    //             .string(
    //                 """
    //                 [
    //                   1234567890,
    //                   2000000,
    //                   1000000000
    //                 ]
    //                 """))
    //     )
    //     // TODO: Add other cases from: v1/test/cases/testdata/v0/jsonbuiltins/test-json-marshal-with-options.yaml
    // ]

    // MARK: - json.unmarshal Tests
    static let jsonUnmarshalTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "nested object",
            name: "json.unmarshal",
            args: ["[{\"foo\":[1,2,3]}]"],
            expected: .success([["foo": [1, 2, 3]]])
        ),
        BuiltinTests.TestCase(
            description: "escaped quoted string",
            name: "json.unmarshal",
            args: ["\"string\""],
            expected: .success(.string("string"))
        ),
        BuiltinTests.TestCase(
            description: "boolean",
            name: "json.unmarshal",
            args: ["true"],
            expected: .success(.boolean(true))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "base64.encode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64EncodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "base64.decode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64DecodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "base64.is_valid", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64IsValidTests,

            BuiltinTests.generateFailureTests(
                builtinName: "base64url.encode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64UrlEncodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "base64url.encode_no_pad", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64UrlEncodeNoPadTests,

            BuiltinTests.generateFailureTests(
                builtinName: "base64url.decode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            base64UrlDecodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "hex.encode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            hexEncodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "hex.decode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            hexDecodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.is_valid", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            jsonIsValidTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.marshal", sampleArgs: [""],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                generateNumberOfArgsTest: true),
            jsonMarshalTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.unmarshal", sampleArgs: [""],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            jsonUnmarshalTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
