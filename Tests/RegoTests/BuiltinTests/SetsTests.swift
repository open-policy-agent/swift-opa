import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Sets", .tags(.builtins))
    struct SetsTests {}
}

extension BuiltinTests.SetsTests {
    static let andTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case",
            name: "and",
            args: [.set([2]), .set([1, 2])],
            expected: .success(.set([2]))
        ),
        BuiltinTests.TestCase(
            description: "empty lhs",
            name: "and",
            args: [.set([]), .set([2])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "empty rhs",
            name: "and",
            args: [.set([1]), .set([])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "and",
            args: [.set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "and",
            args: [.set([1]), .set([1]), .set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "and",
            args: ["1", .set([1])],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "set"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "and",
            args: [.set([1]), "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "set"))
        ),
    ]

    static let intersectionTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "single set",
            name: "intersection",
            args: [
                .set([
                    .set([2])
                ])
            ],
            expected: .success(.set([2]))
        ),
        BuiltinTests.TestCase(
            description: "multiple sets",
            name: "intersection",
            args: [
                .set([
                    .set([2, 3]),
                    .set([1, 2, 3]),
                    .set([2, 3]),
                    .set([2, 3, 7, 8]),
                ])
            ],
            expected: .success(.set([2, 3]))
        ),
        BuiltinTests.TestCase(
            description: "empty set element",
            name: "intersection",
            args: [
                .set([
                    .set([2, 3]),
                    .set([1, 2, 3]),
                    .set([2, 3]),
                    .set([]),
                ])
            ],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "intersection",
            args: [.set([])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "intersection",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "intersection",
            args: [.set([1]), .set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "intersection",
            args: [1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "xs", got: "number", want: "set"))
        ),
        BuiltinTests.TestCase(
            description: "too many args 2",
            name: "intersection",
            args: [.set([1]), "1"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
    ]

    static let orTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case",
            name: "or",
            args: [.set([2]), .set([1, 2])],
            expected: .success(.set([1, 2]))
        ),
        BuiltinTests.TestCase(
            description: "empty lhs",
            name: "or",
            args: [.set([]), .set([2])],
            expected: .success(.set([2]))
        ),
        BuiltinTests.TestCase(
            description: "empty rhs",
            name: "or",
            args: [.set([1]), .set([])],
            expected: .success(.set([1]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "or",
            args: [.set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "or",
            args: [.set([1]), .set([1]), .set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "or",
            args: ["1", .set([1])],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "set"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "or",
            args: [.set([1]), "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "set"))
        ),
    ]

    static let unionTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "single set",
            name: "union",
            args: [
                .set([
                    .set([2])
                ])
            ],
            expected: .success(.set([2]))
        ),
        BuiltinTests.TestCase(
            description: "multiple sets",
            name: "union",
            args: [
                .set([
                    .set([2, 3]),
                    .set([1, 2, 3]),
                    .set([2, 3]),
                    .set([2, 3, 7, 8]),
                ])
            ],
            expected: .success(.set([1, 2, 3, 7, 8]))
        ),
        BuiltinTests.TestCase(
            description: "empty set element",
            name: "union",
            args: [
                .set([
                    .set([2, 3]),
                    .set([1, 2, 3]),
                    .set([2, 3]),
                    .set([]),
                ])
            ],
            expected: .success(.set([1, 2, 3]))
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "union",
            args: [.set([])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "union",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "union",
            args: [.set([1]), .set([1])],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "union",
            args: [1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "xs", got: "number", want: "set"))
        ),
        BuiltinTests.TestCase(
            description: "too many args 2",
            name: "union",
            args: [.set([1]), "1"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            andTests,
            intersectionTests,
            orTests,
            unionTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
