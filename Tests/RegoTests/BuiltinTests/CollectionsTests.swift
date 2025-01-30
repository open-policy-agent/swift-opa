import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests")
struct CollectionsTests {
    // Tests isMemberOf
    static let isMemberOfTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "y in x(array) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .array([.string("c"), .number(42), .string("d")]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "y in x(array) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .array([.string("c"), .number(0), .string("d")]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.string("c"): .number(42), .string("d"): .null]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.string("c"): .number(0), .string("d"): .null]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> false - not keys",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.number(42): .number(0), .string("d"): .null]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "y in x(set) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .set([.string("c"), .number(42), .string("d")]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "y in x(set) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .set([.string("c"), .number(0), .string("d")]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "y in x(null) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .null,
            ],
            expected: .success(.boolean(false))
        ),
    ]
}
