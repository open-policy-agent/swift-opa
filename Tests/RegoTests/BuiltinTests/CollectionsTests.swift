import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Collections")
struct CollectionsTests {
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

    static var allTests: [BuiltinTests.TestCase] {
        [
            isMemberOfTests
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
