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
            args: [.string("abc")],
            expected: .success(.number(3))
        ),
        BuiltinTests.TestCase(
            description: "string empty",
            name: "count",
            args: [.string("")],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "array count",
            name: "count",
            args: [.array([.number(1), .number(2), .number(3)])],
            expected: .success(.number(3))
        ),
        BuiltinTests.TestCase(
            description: "array empty",
            name: "count",
            args: [.array([])],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "set count",
            name: "count",
            args: [.set([.number(1), .number(2), .number(3)])],
            expected: .success(.number(3))
        ),
        BuiltinTests.TestCase(
            description: "set empty",
            name: "count",
            args: [.set([])],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "object count",
            name: "count",
            args: [.object([.string("a"): .number(1), .string("b"): .number(2), .string("c"): .number(3)])],
            expected: .success(.number(3))
        ),
        BuiltinTests.TestCase(
            description: "object empty",
            name: "count",
            args: [.object([:])],
            expected: .success(.number(0))
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
            args: [.string("abc"), .array([.number(1), .number(2), .number(3)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "count",
            args: [.number(1)],
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
