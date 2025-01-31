import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Sets")
struct SetsTests {
    static let andTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case",
            name: "and",
            args: [.set([.number(2)]), .set([.number(1), .number(2)])],
            expected: .success(.set([.number(2)]))
        ),
        BuiltinTests.TestCase(
            description: "empty lhs",
            name: "and",
            args: [.set([]), .set([.number(2)])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "empty rhs",
            name: "and",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "and",
            args: [.set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "and",
            args: [.set([.number(1)]), .set([.number(1)]), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "and",
            args: [.string("1"), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "and",
            args: [.set([.number(1)]), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static let intersectionTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "single set",
            name: "intersection",
            args: [
                .set([
                    .set([.number(2)])
                ])
            ],
            expected: .success(.set([.number(2)]))
        ),
        BuiltinTests.TestCase(
            description: "multiple sets",
            name: "intersection",
            args: [
                .set([
                    .set([.number(2), .number(3)]),
                    .set([.number(1), .number(2), .number(3)]),
                    .set([.number(2), .number(3)]),
                    .set([.number(2), .number(3), .number(7), .number(8)]),
                ])
            ],
            expected: .success(.set([.number(2), .number(3)]))
        ),
        BuiltinTests.TestCase(
            description: "empty set element",
            name: "intersection",
            args: [
                .set([
                    .set([.number(2), .number(3)]),
                    .set([.number(1), .number(2), .number(3)]),
                    .set([.number(2), .number(3)]),
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "intersection",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "intersection",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "xs"))
        ),
        BuiltinTests.TestCase(
            description: "wrong element arg type",
            name: "intersection",
            args: [.set([.number(1)]), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static let orTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case",
            name: "or",
            args: [.set([.number(2)]), .set([.number(1), .number(2)])],
            expected: .success(.set([.number(1), .number(2)]))
        ),
        BuiltinTests.TestCase(
            description: "empty lhs",
            name: "or",
            args: [.set([]), .set([.number(2)])],
            expected: .success(.set([.number(2)]))
        ),
        BuiltinTests.TestCase(
            description: "empty rhs",
            name: "or",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.set([.number(1)]))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "or",
            args: [.set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "or",
            args: [.set([.number(1)]), .set([.number(1)]), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "or",
            args: [.string("1"), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "or",
            args: [.set([.number(1)]), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static let unionTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "single set",
            name: "union",
            args: [
                .set([
                    .set([.number(2)])
                ])
            ],
            expected: .success(.set([.number(2)]))
        ),
        BuiltinTests.TestCase(
            description: "multiple sets",
            name: "union",
            args: [
                .set([
                    .set([.number(2), .number(3)]),
                    .set([.number(1), .number(2), .number(3)]),
                    .set([.number(2), .number(3)]),
                    .set([.number(2), .number(3), .number(7), .number(8)]),
                ])
            ],
            expected: .success(.set([.number(1), .number(2), .number(3), .number(7), .number(8)]))
        ),
        BuiltinTests.TestCase(
            description: "empty set element",
            name: "union",
            args: [
                .set([
                    .set([.number(2), .number(3)]),
                    .set([.number(1), .number(2), .number(3)]),
                    .set([.number(2), .number(3)]),
                    .set([]),
                ])
            ],
            expected: .success(.set([.number(1), .number(2), .number(3)]))
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
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "union",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "union",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "xs"))
        ),
        BuiltinTests.TestCase(
            description: "wrong element arg type",
            name: "union",
            args: [.set([.number(1)]), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
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
