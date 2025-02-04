import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Array")
struct ArrayTests {
    static let arrayConcatTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple concat",
            name: "array.concat",
            args: [
                ["a", "b"],
                ["c", "d"],
            ],
            expected: .success(["a", "b", "c", "d"])
        ),
        BuiltinTests.TestCase(
            description: "lhs empty",
            name: "array.concat",
            args: [
                [],
                ["c", "d"],
            ],
            expected: .success(["c", "d"])
        ),
        BuiltinTests.TestCase(
            description: "rhs empty",
            name: "array.concat",
            args: [
                ["a", "b"],
                [],
            ],
            expected: .success(["a", "b"])
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "array.concat",
            args: [
                [],
                [],
            ],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "mixed types",
            name: "array.concat",
            args: [
                ["a", "b"],
                [1, 2],
            ],
            expected: .success(["a", "b", 1, 2])
        ),
        BuiltinTests.TestCase(
            description: "lhs null (fail)",
            name: "array.concat",
            args: [
                .null,
                ["c", "d"],
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            arrayConcatTests
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
