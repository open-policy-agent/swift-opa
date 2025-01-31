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
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .string("b"),
                .string("default_value"),

            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "simple key does not exist",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .string("zz"),
                .string("default_value"),

            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "simple key empty object",
            name: "object.get",
            args: [
                .object([:]),
                .string("zz"),
                .string("default_value"),

            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 0",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .array([]),
                .string("default_value"),
            ],
            expected: .success(
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 1",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .array([.string("b")]),
                .string("default_value"),
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 2",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": AST.RegoValue([
                        "b": .number(2)
                    ])
                ]),
                .array([.string("a"), .string("b")]),
                .string("default_value"),
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key exists level 6",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": AST.RegoValue([
                        "b": AST.RegoValue([
                            "c": AST.RegoValue([
                                "d": AST.RegoValue([
                                    "e": AST.RegoValue([
                                        "f": .number(2)
                                    ])
                                ])
                            ])
                        ])
                    ])
                ]),
                .array([.string("a"), .string("b"), .string("c"), .string("d"), .string("e"), .string("f")]),
                .string("default_value"),
            ],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 1",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .array([.string("zz")]),
                .string("default_value"),
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 2",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": AST.RegoValue([
                        "b": .number(2)
                    ])
                ]),
                .array([.string("a"), .string("zz")]),
                .string("default_value"),
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key does not exist level 6",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": AST.RegoValue([
                        "b": AST.RegoValue([
                            "c": AST.RegoValue([
                                "d": AST.RegoValue([
                                    "e": AST.RegoValue([
                                        "f": .number(2)
                                    ])
                                ])
                            ])
                        ])
                    ])
                ]),
                .array([.string("a"), .string("b"), .string("c"), .string("d"), .string("e"), .string("zz")]),
                .string("default_value"),
            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "array key empty object",
            name: "object.get",
            args: [
                .object([:]),
                .array([.string("zz")]),
                .string("default_value"),

            ],
            expected: .success(.string("default_value"))
        ),
        BuiltinTests.TestCase(
            description: "non object arg 0",
            name: "object.get",
            args: [
                .null,
                .array([.string("c"), .string("d")]),
                .string("default_value"),
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "object"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .array([.string("c"), .string("d")]),
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 3))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "object.get",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                .array([.string("a"), .string("b")]),
                .array([.string("c"), .string("d")]),
                .string("default_value"),
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 4, expected: 3))
        ),
    ]

    static let objectKeysTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple key exists",
            name: "object.keys",
            args: [
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ])
            ],
            expected: .success(.set([.string("a"), .string("b")]))
        ),
        BuiltinTests.TestCase(
            description: "empty object",
            name: "object.keys",
            args: [
                .object([:])
            ],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "non object arg 0",
            name: "object.keys",
            args: [
                .array([.string("c"), .string("d")])
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
                AST.RegoValue([
                    "a": .number(1),
                    "b": .number(2),
                ]),
                AST.RegoValue([
                    "b": .number(1),
                    "c": .number(2),
                ]),
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
