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
        // Note: Surprisingly, Swift's JSONDecoder allows trailing commas!
        // BuiltinTests.TestCase(
        //     description: "invalid - trailing comma",
        //     name: "json.is_valid",
        //     args: ["{\"foo\": 1,}"],
        //     expected: .success(.boolean(false))
        // ),
        BuiltinTests.TestCase(
            description: "invalid - non string",
            name: "json.is_valid",
            args: [["foo": 1]],
            expected: .success(.boolean(false))  // Does not throw a builtin error in OPA, surprisingly.
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
        BuiltinTests.TestCase(
            description: "marshal HTML-unsafe characters are unicode-escaped",
            name: "json.marshal",
            args: [
                ["html": "<a&b>"]
            ],
            expected: .success(.string("{\"html\":\"\\u003ca\\u0026b\\u003e\"}"))
        ),
    ]

    // MARK: - json.marshal_with_options Tests
    static let jsonMarshalWithOptionsTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "marshal large integers",
            name: "json.marshal_with_options",
            args: [
                .array([.number(1_234_500_000 + 67890), .number(1e6 * 2), .number(1e109 / 1e100)]),
                ["indent": "  ", "prefix": ">>> "],
            ],
            expected: .success(
                .string(
                    """
                    >>> [
                    >>>   1234567890,
                    >>>   2000000,
                    >>>   1000000000
                    >>> ]
                    """))
        ),
        // TODO: Add other cases from: v1/test/cases/testdata/v1/jsonbuiltins/test-json-marshal-with-options.yaml
        BuiltinTests.TestCase(
            description: "marshal deep array",
            name: "json.marshal_with_options",
            args: [
                [[[[[[[]]]]]]],
                ["indent": "    "],
            ],
            expected: .success(
                .string(
                    "[\n    [\n        [\n            [\n                [\n                    [\n                        []\n                    ]\n                ]\n            ]\n        ]\n    ]\n]"
                ))
        ),
        BuiltinTests.TestCase(
            description: "marshal object",
            name: "json.marshal_with_options",
            args: [
                ["foo": "bar", "bar": "baz"],
                ["prefix": "JSON =\u{003e} "],
            ],
            expected: .success(
                .string(
                    "JSON =\u{003e} {\nJSON =\u{003e} \t\"bar\": \"baz\",\nJSON =\u{003e} \t\"foo\": \"bar\"\nJSON =\u{003e} }"
                ))
        ),
        BuiltinTests.TestCase(
            description: "marshal object with escaped strings",
            name: "json.marshal_with_options",
            args: [
                ["foo\" :and friends": "\"bar\"", "\"bar\"": "baz"],
                ["prefix": ">>> "],
            ],
            expected: .success(
                .string(
                    ">>> {\n>>> \t\"\\\"bar\\\"\": \"baz\",\n>>> \t\"foo\\\" :and friends\": \"\\\"bar\\\"\"\n>>> }"
                ))
        ),
        BuiltinTests.TestCase(
            description: "marshal with pretty=true uses default tab indent and no prefix",
            name: "json.marshal_with_options",
            args: [
                ["a": 1, "b": 2],
                ["pretty": true],
            ],
            expected: .success(
                .string("{\n\t\"a\": 1,\n\t\"b\": 2\n}"))
        ),
        BuiltinTests.TestCase(
            description: "marshal with HTML-unsafe characters escaped inside pretty output",
            name: "json.marshal_with_options",
            args: [
                ["html": "<a&b>"],
                ["pretty": true],
            ],
            expected: .success(
                .string("{\n\t\"html\": \"\\u003ca\\u0026b\\u003e\"\n}"))
        ),
    ]

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

    // MARK: - urlquery.encode Tests
    static let urlQueryEncodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty string",
            name: "urlquery.encode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "compliance: a=b+1",
            name: "urlquery.encode",
            args: ["a=b+1"],
            expected: .success(.string("a%3Db%2B1"))
        ),
        BuiltinTests.TestCase(
            description: "space becomes plus",
            name: "urlquery.encode",
            args: ["hello world"],
            expected: .success(.string("hello+world"))
        ),
        BuiltinTests.TestCase(
            description: "unreserved characters pass through",
            name: "urlquery.encode",
            args: ["abcXYZ-._~"],
            expected: .success(.string("abcXYZ-._~"))
        ),
        BuiltinTests.TestCase(
            description: "unicode is utf-8 percent-encoded",
            name: "urlquery.encode",
            args: ["é"],
            expected: .success(.string("%C3%A9"))
        ),
    ]

    // MARK: - urlquery.decode Tests
    static let urlQueryDecodeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty string",
            name: "urlquery.decode",
            args: [""],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "compliance: a%3Db%2B1",
            name: "urlquery.decode",
            args: ["a%3Db%2B1"],
            expected: .success(.string("a=b+1"))
        ),
        BuiltinTests.TestCase(
            description: "plus decodes to space",
            name: "urlquery.decode",
            args: ["hello+world"],
            expected: .success(.string("hello world"))
        ),
        BuiltinTests.TestCase(
            description: "lowercase hex accepted",
            name: "urlquery.decode",
            args: ["%c3%a9"],
            expected: .success(.string("é"))
        ),
        BuiltinTests.TestCase(
            description: "trailing %",
            name: "urlquery.decode",
            args: ["abc%"],
            expected: .failure(BuiltinError.evalError(msg: "invalid URL escape \"%\""))
        ),
        BuiltinTests.TestCase(
            description: "non-hex after %",
            name: "urlquery.decode",
            args: ["%ZZ"],
            expected: .failure(BuiltinError.evalError(msg: "invalid URL escape \"%ZZ\""))
        ),
        BuiltinTests.TestCase(
            description: "malformed escape mid-string clipped to 3 bytes",
            name: "urlquery.decode",
            args: ["abc%Zhello"],
            expected: .failure(BuiltinError.evalError(msg: "invalid URL escape \"%Zh\""))
        ),
    ]

    // MARK: - urlquery.encode_object Tests
    static let urlQueryEncodeObjectTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty object",
            name: "urlquery.encode_object",
            args: [[:]],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "compliance: strings sorted by key",
            name: "urlquery.encode_object",
            args: [["a": "b", "c": "d"]],
            expected: .success(.string("a=b&c=d"))
        ),
        BuiltinTests.TestCase(
            description: "keys emitted in sorted order regardless of literal order",
            name: "urlquery.encode_object",
            args: [["z": "1", "banana": "2", "apple": "3", "a": "4"]],
            expected: .success(.string("a=4&apple=3&banana=2&z=1"))
        ),
        BuiltinTests.TestCase(
            description: "value is escaped",
            name: "urlquery.encode_object",
            args: [["a": "c=b+1"]],
            expected: .success(.string("a=c%3Db%2B1"))
        ),
        BuiltinTests.TestCase(
            description: "array values produce repeated key",
            name: "urlquery.encode_object",
            args: [["a": ["b+1", "c+2"]]],
            expected: .success(.string("a=b%2B1&a=c%2B2"))
        ),
        BuiltinTests.TestCase(
            description: "set values produce repeated key (sorted)",
            name: "urlquery.encode_object",
            args: [["a": .set([.string("y"), .string("x")])]],
            expected: .success(.string("a=x&a=y"))
        ),
        BuiltinTests.TestCase(
            description: "mixed string and array values",
            name: "urlquery.encode_object",
            args: [["a": "1", "b": ["2", "3"]]],
            expected: .success(.string("a=1&b=2&b=3"))
        ),
        BuiltinTests.TestCase(
            description: "non-string value rejected",
            name: "urlquery.encode_object",
            args: [["a": 1]],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 values must be string, array[string], or set[string]"))
        ),
        BuiltinTests.TestCase(
            description: "non-string array element rejected",
            name: "urlquery.encode_object",
            args: [["a": [1, 2]]],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 values must be string, array[string], or set[string]"))
        ),
        BuiltinTests.TestCase(
            description: "non-string set element rejected",
            name: "urlquery.encode_object",
            args: [["a": .set([.number(1)])]],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 values must be string, array[string], or set[string]"))
        ),
        BuiltinTests.TestCase(
            description: "nested object value rejected",
            name: "urlquery.encode_object",
            args: [["a": ["nested": "value"]]],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 values must be string, array[string], or set[string]"))
        ),
        BuiltinTests.TestCase(
            description: "empty array value emits no pairs",
            name: "urlquery.encode_object",
            args: [["a": []]],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "empty set value emits no pairs",
            name: "urlquery.encode_object",
            args: [["a": .set([])]],
            expected: .success(.string(""))
        ),
    ]

    // MARK: - urlquery.decode_object Tests
    static let urlQueryDecodeObjectTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty string",
            name: "urlquery.decode_object",
            args: [""],
            expected: .success(.object([:]))
        ),
        BuiltinTests.TestCase(
            description: "compliance: multiple values per key",
            name: "urlquery.decode_object",
            args: ["a=value_a1&b=value_b&a=value_a2"],
            expected: .success(["a": ["value_a1", "value_a2"], "b": ["value_b"]])
        ),
        BuiltinTests.TestCase(
            description: "compliance: param without =",
            name: "urlquery.decode_object",
            args: ["a=value_a1&b"],
            expected: .success(["a": ["value_a1"], "b": [""]])
        ),
        BuiltinTests.TestCase(
            description: "percent-decodes both keys and values",
            name: "urlquery.decode_object",
            args: ["a%20b=c%20d"],
            expected: .success(["a b": ["c d"]])
        ),
        BuiltinTests.TestCase(
            description: "plus decodes to space",
            name: "urlquery.decode_object",
            args: ["a=hello+world"],
            expected: .success(["a": ["hello world"]])
        ),
        BuiltinTests.TestCase(
            description: "malformed escape throws",
            name: "urlquery.decode_object",
            args: ["a=%ZZ"],
            expected: .failure(BuiltinError.evalError(msg: "invalid URL escape \"%ZZ\""))
        ),
        // Empty-pair handling — match Go's `url.ParseQuery`, which silently
        // skips empty `&` pairs (leading, trailing, consecutive) and the
        // lone `=` pair where both sides are empty.
        BuiltinTests.TestCase(
            description: "leading separator",
            name: "urlquery.decode_object",
            args: ["&a=1"],
            expected: .success(["a": ["1"]])
        ),
        BuiltinTests.TestCase(
            description: "trailing separator",
            name: "urlquery.decode_object",
            args: ["a=1&"],
            expected: .success(["a": ["1"]])
        ),
        BuiltinTests.TestCase(
            description: "consecutive separators",
            name: "urlquery.decode_object",
            args: ["a=1&&b=2"],
            expected: .success(["a": ["1"], "b": ["2"]])
        ),
        BuiltinTests.TestCase(
            description: "only separators",
            name: "urlquery.decode_object",
            args: ["&&"],
            expected: .success(.object([:]))
        ),
        BuiltinTests.TestCase(
            description: "lone equals is skipped",
            name: "urlquery.decode_object",
            args: ["="],
            expected: .success(.object([:]))
        ),
        BuiltinTests.TestCase(
            description: "empty key with non-empty value retained",
            name: "urlquery.decode_object",
            args: ["=value"],
            expected: .success(["": ["value"]])
        ),
        BuiltinTests.TestCase(
            description: "escaped = in key is decoded after splitting",
            name: "urlquery.decode_object",
            args: ["a%3Db=value"],
            expected: .success(["a=b": ["value"]])
        ),
        BuiltinTests.TestCase(
            description: "literal = in value preserved (maxSplits 1)",
            name: "urlquery.decode_object",
            args: ["a=b=c"],
            expected: .success(["a": ["b=c"]])
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

            // json.is_valid's documentation states it requires a string,
            // but in the OPA implementation, it does not throw a builtin
            // error on a wrong-typed argument. Instead it returns false.
            BuiltinTests.generateFailureTests(
                builtinName: "json.is_valid", sampleArgs: [""],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                generateNumberOfArgsTest: true),
            jsonIsValidTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.marshal", sampleArgs: [""],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                generateNumberOfArgsTest: true),
            jsonMarshalTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.marshal_with_options", sampleArgs: ["", [:]],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "json.marshal_with_options",
                sampleArgs: ["", ["prefix": "", "pretty": false, "indent": "  "]],
                argIndex: 1, argName: "opts",
                allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                generateNumberOfArgsTest: true),
            jsonMarshalWithOptionsTests,

            BuiltinTests.generateFailureTests(
                builtinName: "json.unmarshal", sampleArgs: [""],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            jsonUnmarshalTests,

            BuiltinTests.generateFailureTests(
                builtinName: "urlquery.encode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            urlQueryEncodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "urlquery.decode", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            urlQueryDecodeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "urlquery.encode_object", sampleArgs: [[:]],
                argIndex: 0, argName: "object", allowedArgTypes: ["object"],
                generateNumberOfArgsTest: true),
            urlQueryEncodeObjectTests,

            BuiltinTests.generateFailureTests(
                builtinName: "urlquery.decode_object", sampleArgs: [""],
                argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            urlQueryDecodeObjectTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    /// `decode(encode(s)) == s` for representative inputs covering reserved
    /// chars, spaces, multi-byte UTF-8, and the full unreserved set.
    @Test(
        arguments: [
            "",
            "a=b+1",
            "hello world",
            "é",
            "🚀 emoji",
            "/?:#[]@!$&'()*+,;=",
            "abcXYZ-._~",
            "tab\tnewline\n",
        ])
    func testUrlQueryRoundTrip(input: String) async throws {
        let registry = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let encoded = try await registry.invoke(
            withContext: ctx, name: "urlquery.encode",
            args: [.string(input)], strict: true)
        let decoded = try await registry.invoke(
            withContext: ctx, name: "urlquery.decode",
            args: [encoded], strict: true)
        #expect(decoded == .string(input))
    }
}
