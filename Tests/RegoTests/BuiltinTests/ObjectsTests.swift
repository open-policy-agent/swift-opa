import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Objects")
struct ObjectTests {
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "object"))
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 3))
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 4, expected: 3))
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "object"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "object.keys",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
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
