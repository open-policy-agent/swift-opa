import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Comparison")
struct ComparisonTests {

    static let greaterThanTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "gt",
            args: [[1], [1, 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "gt",
            args: [[1], []],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "gt",
            args: [[1], [1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "gt",
            args: [false, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "gt",
            args: [true, false],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "gt",
            args: [true, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "gt",
            args: [.null, .null],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "gt",
            args: [0, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "gt",
            args: [1, 0],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "gt",
            args: [1, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "gt",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "gt",
            args: [["a": 1], [:]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "gt",
            args: [["a": 1], ["a": 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "gt",
            args: [.set([1]), .set([1, 2])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "gt",
            args: [.set([1]), .set([])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "gt",
            args: [.set([1]), .set([1])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "gt",
            args: ["abc", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "gt",
            args: ["zzz", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "gt",
            args: ["zzz", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "gt",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "gt",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let greaterThanEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "gte",
            args: [[1], [1, 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "gte",
            args: [[1], []],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "gte",
            args: [[1], [1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "gte",
            args: [false, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "gte",
            args: [true, false],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "gte",
            args: [true, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "gte",
            args: [.null, .null],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "gte",
            args: [0, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "gte",
            args: [1, 0],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "gte",
            args: [1, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "gte",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "gte",
            args: [["a": 1], [:]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "gte",
            args: [["a": 1], ["a": 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "gte",
            args: [.set([1]), .set([1, 2])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "gte",
            args: [.set([1]), .set([])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "gte",
            args: [.set([1]), .set([1])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "gte",
            args: ["abc", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "gte",
            args: ["zzz", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "gte",
            args: ["zzz", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "gte",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "gte",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let lessThanTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "lt",
            args: [[1], [1, 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "lt",
            args: [[1], []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "lt",
            args: [[1], [1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "lt",
            args: [false, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "lt",
            args: [true, false],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "lt",
            args: [true, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "lt",
            args: [.null, .null],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "lt",
            args: [0, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "lt",
            args: [1, 0],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "lt",
            args: [1, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "lt",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "lt",
            args: [["a": 1], [:]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "lt",
            args: [["a": 1], ["a": 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "lt",
            args: [.set([1]), .set([1, 2])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "lt",
            args: [.set([1]), .set([])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "lt",
            args: [.set([1]), .set([1])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "lt",
            args: ["abc", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "lt",
            args: ["zzz", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "lt",
            args: ["zzz", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lt",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lt",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let lessThanEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "lte",
            args: [[1], [1, 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "lte",
            args: [[1], []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "lte",
            args: [[1], [1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "lte",
            args: [false, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "lte",
            args: [true, false],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "lte",
            args: [true, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "lte",
            args: [.null, .null],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "lte",
            args: [0, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "lte",
            args: [1, 0],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "lte",
            args: [1, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "lte",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "lte",
            args: [["a": 1], [:]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "lte",
            args: [["a": 1], ["a": 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "lte",
            args: [.set([1]), .set([1, 2])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "lte",
            args: [.set([1]), []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "lte",
            args: [.set([1]), .set([1])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "lte",
            args: ["abc", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "lte",
            args: ["zzz", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "lte",
            args: ["zzz", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lte",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lte",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let notEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true lt",
            name: "neq",
            args: [[1], [1, 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array true gt",
            name: "neq",
            args: [[1], []],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "neq",
            args: [[1], [1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true lt",
            name: "neq",
            args: [false, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true gt",
            name: "neq",
            args: [true, false],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "neq",
            args: [true, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "neq",
            args: [.null, .null],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number true lt",
            name: "neq",
            args: [0, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number true gt",
            name: "neq",
            args: [1, 0],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "neq",
            args: [1, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object true lt",
            name: "neq",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object true gt",
            name: "neq",
            args: [["a": 1], [:]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "neq",
            args: [["a": 1], ["a": 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set true lt",
            name: "neq",
            args: [.set([1]), .set([1, 2])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set true gt",
            name: "neq",
            args: [.set([1]), .set([])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "neq",
            args: [.set([1]), .set([1])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string true lt",
            name: "neq",
            args: ["abc", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string true gt",
            name: "neq",
            args: ["zzz", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "neq",
            args: ["zzz", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "neq",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "neq",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let equalTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false lt",
            name: "equal",
            args: [[1], [1, 1]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array false gt",
            name: "equal",
            args: [[1], []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "equal",
            args: [[1], [1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false lt",
            name: "equal",
            args: [false, true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false gt",
            name: "equal",
            args: [true, false],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "equal",
            args: [true, true],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "equal",
            args: [.null, .null],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type number false lt",
            name: "equal",
            args: [0, 1],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number false gt",
            name: "equal",
            args: [1, 0],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "equal",
            args: [1, 1],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type object false lt",
            name: "equal",
            args: [
                ["a": 1], ["a": 1, "b": 1],
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object false gt",
            name: "equal",
            args: [["a": 1], [:]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "equal",
            args: [["a": 1], ["a": 1]],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type set false lt",
            name: "equal",
            args: [.set([1]), .set([1, 2])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set false gt",
            name: "equal",
            args: [.set([1]), .set([])],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "equal",
            args: [.set([1]), .set([1])],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "same type string false lt",
            name: "equal",
            args: ["abc", "zzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string false gt",
            name: "equal",
            args: ["zzz", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "equal",
            args: ["zzz", "zzz"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "equal",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "equal",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            greaterThanTests,
            greaterThanEqTests,
            lessThanTests,
            lessThanEqTests,
            notEqTests,
            equalTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
