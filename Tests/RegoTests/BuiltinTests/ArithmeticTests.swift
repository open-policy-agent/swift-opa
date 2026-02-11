import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Arithmetic", .tags(.builtins))
    struct ArithmeticTests {}
}

extension BuiltinTests.ArithmeticTests {
    static let plusTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1 + 1",
            name: "plus",
            args: [1, 1],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "1 + 1.234567890",
            name: "plus",
            args: [1, 1.234567890],
            expected: .success(2.23456789)
        ),
        BuiltinTests.TestCase(
            description: "1.33333 + 1.33333",
            name: "plus",
            args: [1.33333, 1.33333],
            expected: .success(2.66666)
        ),
        BuiltinTests.TestCase(
            description: "overflow",
            name: "plus",
            args: [999_999_999_999_999_999, 999_999_999_999_999_999],
            expected: .success(1_999_999_999_999_999_998)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "plus",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "plus",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "plus",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "plus",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number"))
        ),
    ]

    static let minusNumberTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "2 - 1",
            name: "minus",
            args: [2, 1],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "2 - 1.234567890",
            name: "minus",
            args: [2, 1.234567890],
            expected: .success(0.76543211)
        ),
        BuiltinTests.TestCase(
            description: "2.33333 - 1.33333",
            name: "minus",
            args: [2.33333, 1.33333],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "minus",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "minus",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "minus",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number|set"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "minus",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number"))
        ),
    ]

    static let minusSetTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "set diff simple",
            name: "minus",
            args: [.set([1, 2, 3]), .set([2, 5])],
            expected: .success(.set([1, 3]))
        ),
        BuiltinTests.TestCase(
            description: "set diff empty lhs",
            name: "minus",
            args: [.set([]), .set([2, 5])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "set diff empty rhs",
            name: "minus",
            args: [.set([1, 2, 3]), .set([])],
            expected: .success(.set([1, 2, 3]))
        ),
        BuiltinTests.TestCase(
            description: "set diff empty",
            name: "minus",
            args: [.set([]), .set([])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "mixed set and number lhs",
            name: "minus",
            args: [1, .set([1])],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "set", want: "number"))
        ),
        BuiltinTests.TestCase(
            description: "mixed set and number rhs",
            name: "minus",
            args: [.set([1]), 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "number", want: "set"))
        ),
    ]

    static let mulTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "2 * 2",
            name: "mul",
            args: [2, 2],
            expected: .success(4)
        ),
        BuiltinTests.TestCase(
            description: "2 * 1.5",
            name: "mul",
            args: [2, 1.5],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "3 * 0.33333",
            name: "mul",
            args: [3, 0.33333],
            expected: .success(0.99999)
        ),
        BuiltinTests.TestCase(
            description: "overflow",
            name: "mul",
            args: [999_999_999_999_999_999, 10000],
            // We're cheating on this a little bit, but it seems this is the only way
            // to construct the answer, main goal here is to make sure nothing blows
            // up when we go to values larger than Int can hold
            expected: .success(.number(RegoNumber(Decimal(999_999_999_999_999_999) * Decimal(10000))))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "mul",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "mul",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "mul",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "mul",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number"))
        ),
    ]

    static let divTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "10 / 2",
            name: "div",
            args: [10, 2],
            expected: .success(5)
        ),
        BuiltinTests.TestCase(
            description: "3 / 2",
            name: "div",
            args: [3, 2],
            expected: .success(1.5)
        ),
        BuiltinTests.TestCase(
            description: "1 / 3",
            name: "div",
            args: [1, 3],
            // Cheating a little bit, just want to make sure they're resulting in high precision
            // RegoNumbers from the Decimal division.
            expected: .success(.number(RegoNumber(Decimal(1) / Decimal(3))))
        ),
        BuiltinTests.TestCase(
            description: "divide by 0",
            name: "div",
            args: [3, 0],
            expected: .failure(BuiltinError.evalError(msg: "division by zero"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "div",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "div",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "div",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "div",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number"))
        ),
    ]

    static let roundTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "round",
            args: [1],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "round",
            args: [1.111111],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "round",
            args: [1.5],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "round",
            args: [1.9999],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "round",
            args: [-1.5],
            expected: .success(-2)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "round",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "round",
            args: [1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "round",
            args: ["1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
    ]

    static let ceilTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "ceil",
            args: [1],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "ceil",
            args: [1.111111],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "ceil",
            args: [1.5],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "ceil",
            args: [1.9999],
            expected: .success(2)
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "ceil",
            args: [-1.5],
            expected: .success(-1)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "ceil",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "ceil",
            args: [1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "ceil",
            args: ["1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
    ]

    static let floorTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "floor",
            args: [1],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "floor",
            args: [1.111111],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "floor",
            args: [1.5],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "floor",
            args: [1.9999],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "floor",
            args: [-1.5],
            expected: .success(-2)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "floor",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "floor",
            args: [1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "floor",
            args: ["1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
    ]

    static let remTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "10 % 3",
            name: "rem",
            args: [10, 3],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "10 % 10",
            name: "rem",
            args: [10, 10],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "divide by 0",
            name: "rem",
            args: [3, 0],
            expected: .failure(BuiltinError.evalError(msg: "modulo by zero"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "rem",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "rem",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "float arg lhs",
            name: "rem",
            args: [1.2345, 1],
            expected: .failure(BuiltinError.evalError(msg: "modulo on floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "float arg rhs",
            name: "rem",
            args: [10, 1.2345],
            expected: .failure(BuiltinError.evalError(msg: "modulo on floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "rem",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "rem",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            plusTests,
            minusNumberTests,
            minusSetTests,
            mulTests,
            divTests,
            roundTests,
            ceilTests,
            floorTests,
            remTests,
        ].flatMap { $0 }
    }

    static let knownIssues: Set<String> = [
        "plus: 1 + 1.234567890",
        "minus: 2 - 1.234567890",
        "minus: 2.33333 - 1.33333",
        "mul: overflow",
    ]

    private var isLinux: Bool {
        #if os(Linux)
            true
        #else
            false
        #endif
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await withKnownIssue(isIntermittent: true) {
            try await BuiltinTests.testBuiltin(tc: tc)
        } when: {
            isLinux
        } matching: { _ in
            BuiltinTests.ArithmeticTests.knownIssues.contains(tc.testDescription)
        }
    }
}
