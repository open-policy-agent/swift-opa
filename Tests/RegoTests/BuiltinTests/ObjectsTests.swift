import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Objects", .tags(.builtins))
    struct ObjectTests {}
}

extension BuiltinTests.ObjectTests {
    static let objectGetTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple key exists",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                "b",
                "default_value",
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "simple key does not exist",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                "zz",
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "simple key empty object",
            name: "object.get",
            args: [
                [:],
                "zz",
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 0",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                .array([]),
                "default_value",
            ],
            expected: .success(
                [
                    "a": 1,
                    "b": 2,
                ])
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 1",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                ["b"],
                "default_value",
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 2",
            name: "object.get",
            args: [
                [
                    "a": [
                        "b": 2
                    ]
                ],
                ["a", "b"],
                "default_value",
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 6",
            name: "object.get",
            args: [
                [
                    "a": [
                        "b": [
                            "c": [
                                "d": [
                                    "e": [
                                        "f": 2
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                ["a", "b", "c", "d", "e", "f"],
                "default_value",
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 1",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                ["zz"],
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 2",
            name: "object.get",
            args: [
                [
                    "a": [
                        "b": 2
                    ]
                ],
                ["a", "zz"],
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 6",
            name: "object.get",
            args: [
                [
                    "a": [
                        "b": [
                            "c": [
                                "d": [
                                    "e": [
                                        "f": 2
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                ["a", "b", "c", "d", "e", "zz"],
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key empty object",
            name: "object.get",
            args: [
                [:],
                ["zz"],
                "default_value",
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "non object arg 0",
            name: "object.get",
            args: [
                .null,
                ["c", "d"],
                "default_value",
            ],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "object", got: "null", want: "object"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                ["c", "d"],
            ],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 3))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "object.get",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                ["a", "b"],
                ["c", "d"],
                "default_value",
            ],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 4, want: 3))
        ),
        BuiltinTests.TestCase(
            description: "string->array found",
            name: "object.get",
            args: [
                [
                    "a": [
                        "first",
                        "second",
                    ]
                ],
                ["a", 1],
                "default_value",
            ],
            expected: .success("second")
        ),
        BuiltinTests.TestCase(
            description: "string->array (out of bounds)",
            name: "object.get",
            args: [
                [
                    "a": [
                        "first",
                        "second",
                    ]
                ],
                ["a", 2],
                "default_value",
            ],
            expected: .success("default_value")
        ),
        BuiltinTests.TestCase(
            description: "string->array (negative out of bounds)",
            name: "object.get",
            args: [
                [
                    "a": [
                        "first",
                        "second",
                    ]
                ],
                ["a", -1],
                "default_value",
            ],
            expected: .success("default_value")
        ),
        BuiltinTests.TestCase(
            description: "string->array->array-string",
            name: "object.get",
            args: [
                [
                    "a": [
                        "first",
                        [
                            "needle"
                        ],
                        "third",
                    ]
                ],
                ["a", 1, 0],
                "default_value",
            ],
            expected: .success("needle")
        ),
        BuiltinTests.TestCase(
            description: "string->set",
            name: "object.get",
            args: [
                [
                    "a": .set([
                        "X",
                        "Y",
                        "Z",
                    ]),
                    "b": "bee",
                ],
                ["a", "Y"],
                "default_value",
            ],
            expected: .success("Y")
        ),
        BuiltinTests.TestCase(
            description: "string->set (not found)",
            name: "object.get",
            args: [
                [
                    "a": .set([
                        "X",
                        "Y",
                        "Z",
                    ]),
                    "b": "bee",
                ],
                ["a", "C"],
                "default_value",
            ],
            expected: .success("default_value")
        ),
        BuiltinTests.TestCase(
            description: "string->set->set->string",
            name: "object.get",
            args: [
                [
                    "a": .set([
                        "X",
                        .set([
                            ["not": "this one"],
                            ["this": "one"],
                        ]),
                        "Z",
                    ]),
                    "b": "bee",
                ],
                // Path:
                [
                    "a",
                    // Select the full set
                    .set([
                        ["not": "this one"],
                        ["this": "one"],
                    ]),
                    // Select the object within that set
                    ["this": "one"],
                    // Select the key within that object
                    "this",
                ],
                "default_value",
            ],
            expected: .success("one")
        ),
        BuiltinTests.TestCase(
            description: "array as key in path",
            name: "object.get",
            args: [
                .object([
                    .array([0, 1]): "found it",
                    "b": "bee",
                ]),
                [[0, 1]],
                "default value",
            ],
            expected: .success("found it")
        ),
        // object.get({"a": ["b", "found it"]}, ["a", 1.0], "nope") == "nope" :-/
        BuiltinTests.TestCase(
            description: "numeric key equivalency as array index",
            name: "object.get",
            args: [
                [
                    "a": [
                        "b",
                        "found it",
                    ]
                ],
                ["a", 1.0],
                "default value",
            ],
            expected: .success("default value")
        ),
    ]

    static let objectKeysTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple key exists",
            name: "object.keys",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ]
            ],
            expected: .success(.set(["a", "b"]))
        ),
        BuiltinTests.TestCase(
            description: "empty object",
            name: "object.keys",
            args: [
                [:]
            ],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "non object arg 0",
            name: "object.keys",
            args: [
                ["c", "d"]
            ],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "object", got: "array", want: "object"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "object.keys",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "object.keys",
            args: [
                [
                    "a": 1,
                    "b": 2,
                ],
                [
                    "b": 1,
                    "c": 2,
                ],
            ],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            objectGetTests,
            objectKeysTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
