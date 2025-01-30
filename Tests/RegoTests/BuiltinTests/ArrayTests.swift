import AST
import Foundation
import Testing

@testable import Rego

@Suite
struct ArrayTests {
    static let arrayConcatTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple concat",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([.string("c"), .string("d")]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"), .string("c"), .string("d"),
                ]))
        ),
        BuiltinTests.TestCase(
            description: "lhs empty",
            name: "array.concat",
            args: [
                .array([]),
                .array([.string("c"), .string("d")]),
            ],
            expected: .success(
                .array([
                    .string("c"), .string("d"),
                ]))
        ),
        BuiltinTests.TestCase(
            description: "rhs empty",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"),
                ]))
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "array.concat",
            args: [
                .array([]),
                .array([]),
            ],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "mixed types",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([.number(1), .number(2)]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"),
                    .number(1), .number(2),
                ]))
        ),
        BuiltinTests.TestCase(
            description: "lhs null (fail)",
            name: "array.concat",
            args: [
                .null,
                .array([.string("c"), .string("d")]),
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]
}
