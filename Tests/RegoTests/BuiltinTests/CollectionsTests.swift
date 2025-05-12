import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Collections", .tags(.builtins))
    struct CollectionsTests {}
}

extension BuiltinTests.CollectionsTests {
    // Tests isMemberOf
    static let isMemberOfTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "y in x(array) -> true",
            name: "internal.member_2",
            args: [
                42,
                ["c", 42, "d"],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "y in x(array) -> false",
            name: "internal.member_2",
            args: [
                42,
                ["c", 0, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> true",
            name: "internal.member_2",
            args: [
                42,
                ["c": 42, "d": .null],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> false",
            name: "internal.member_2",
            args: [
                42,
                ["c": 0, "d": .null],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "y in x(object) -> false - not keys",
            name: "internal.member_2",
            args: [
                42,
                .object([42: 0, "d": .null]),
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "y in x(set) -> true",
            name: "internal.member_2",
            args: [
                42,
                .set(["c", 42, "d"]),
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "y in x(set) -> false",
            name: "internal.member_2",
            args: [
                42,
                .set(["c", 0, "d"]),
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "y in x(null) -> false",
            name: "internal.member_2",
            args: [
                42,
                .null,
            ],
            expected: .success(false)
        ),
    ]

    static let isMemberOfWithKeyTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "index, value in array -> true",
            name: "internal.member_3",
            args: [
                1,
                42,
                ["c", 42, "d"],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "index, wrong value in array -> false",
            name: "internal.member_3",
            args: [
                1,
                99,
                ["c", 42, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "index out of bounds, value in array -> false",
            name: "internal.member_3",
            args: [
                999,
                42,
                ["c", 42, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "index float with integer value, value in array -> false",
            name: "internal.member_3",
            args: [
                1.0,
                42,
                ["c", 42, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "index not an integer, value in array -> false",
            name: "internal.member_3",
            args: [
                1.5,
                42,
                ["c", 42, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "index not a number, value in array -> false",
            name: "internal.member_3",
            args: [
                "index should be a number",
                42,
                ["c", 42, "d"],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "property, value in object -> true",
            name: "internal.member_3",
            args: [
                "property",
                42,
                ["property": 42, "other": ["export": true]],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "other, object value in object -> true",
            name: "internal.member_3",
            args: [
                "other",
                .object(["export": true]),
                .object(["property": 42, "other": ["export": true]]),
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "property does not exist, value in object -> false",
            name: "internal.member_3",
            args: [
                "property2",
                42,
                ["property": 42, "other": ["export": true]],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "property, different value in object -> false",
            name: "internal.member_3",
            args: [
                "property",
                0,
                ["property": 42, "other": ["export": true]],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "element, element in set -> true",
            name: "internal.member_3",
            args: [
                10,
                10,
                .set([9, 10, 11]),
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "element, something else in set -> false",
            name: "internal.member_3",
            args: [
                10,
                9,
                .set([9, 10, 11]),
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "element not in set -> false",
            name: "internal.member_3",
            args: [
                100,
                10,
                .set([9, 10, 11]),
            ],
            expected: .success(false)
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            isMemberOfTests,
            isMemberOfWithKeyTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
