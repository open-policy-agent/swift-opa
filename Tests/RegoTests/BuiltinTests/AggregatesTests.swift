import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Aggregates")
struct AggregatesTests {
    static let countTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "string count",
            name: "count",
            args: ["abc"],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "string empty",
            name: "count",
            args: [""],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "array count",
            name: "count",
            args: [[1, 2, 3]],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "array empty",
            name: "count",
            args: [[]],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "set count",
            name: "count",
            args: [.set([1, 2, 3])],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "set empty",
            name: "count",
            args: [.set([])],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "object count",
            name: "count",
            args: [
                ["a": 1, "b": 2, "c": 3]
            ],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "object empty",
            name: "count",
            args: [
                [:]
            ],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "count",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "count",
            args: ["abc", [1, 2, 3]],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "count",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            countTests
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
