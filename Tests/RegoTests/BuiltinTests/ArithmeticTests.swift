import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Arithmetic")
struct ArithmeticTests {
    static let plusTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1 + 1",
            name: "plus",
            args: [.number(1), .number(1)],
            expected: .success(.number(2))
        ),
        // TODO: Uh oh, we've got floating point comparison and math problems
        // we might need to do something like what OPA does upstream using strings
        // and "big" number libraries to achieve similar behaviors (and consistency)
        //BuiltinTests.TestCase(
        //    description: "1 + 1.234567890",
        //    name: "plus",
        //    args: [.number(1), .number(1.234567890)],
        //    expected: .success(.number(2.23456789))
        //),
        BuiltinTests.TestCase(
            description: "1.33333 + 1.33333",
            name: "plus",
            args: [.number(1.33333), .number(1.33333)],
            expected: .success(.number(2.66666))
        ),
        BuiltinTests.TestCase(
            description: "overflow",
            name: "plus",
            args: [.number(999_999_999_999_999_999), .number(999_999_999_999_999_999)],
            expected: .success(.number(1_999_999_999_999_999_998))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "plus",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "plus",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "plus",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "plus",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static let minusNumberTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "2 - 1",
            name: "minus",
            args: [.number(2), .number(1)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "2 - 1.234567890",
            name: "minus",
            args: [.number(2), .number(1.234567890)],
            expected: .success(.number(0.76543211))
        ),
        BuiltinTests.TestCase(
            description: "2.33333 + 1.33333",
            name: "minus",
            args: [.number(2.33333), .number(1.33333)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "minus",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "minus",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "minus",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "minus",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static let minusSetTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "set diff simple",
            name: "minus",
            args: [.set([.number(1), .number(2), .number(3)]), .set([.number(2), .number(5)])],
            expected: .success(.set([.number(1), .number(3)]))
        ),
        BuiltinTests.TestCase(
            description: "set diff empty lhs",
            name: "minus",
            args: [.set([]), .set([.number(2), .number(5)])],
            expected: .success(.set([]))
        ),
        BuiltinTests.TestCase(
            description: "set diff empty rhs",
            name: "minus",
            args: [.set([.number(1), .number(2), .number(3)]), .set([])],
            expected: .success(.set([.number(1), .number(2), .number(3)]))
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
            args: [.number(1), .set([.number(1)])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "mixed set and number rhs",
            name: "minus",
            args: [.set([.number(1)]), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static let multTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "2 * 2",
            name: "mult",
            args: [.number(2), .number(2)],
            expected: .success(.number(4))
        ),
        BuiltinTests.TestCase(
            description: "2 * 1.5",
            name: "mult",
            args: [.number(2), .number(1.5)],
            expected: .success(.number(3))
        ),
        BuiltinTests.TestCase(
            description: "3 * 0.33333",
            name: "mult",
            args: [.number(3), .number(0.33333)],
            expected: .success(.number(0.99999))
        ),
        BuiltinTests.TestCase(
            description: "overflow",
            name: "mult",
            args: [.number(999_999_999_999_999_999), .number(10000)],
            // We're cheating on this a little bit, but it seems this is the only way
            // to construct the answer, main goal here is to make sure nothing blows
            // up when we go to values larger than Int can hold
            expected: .success(.number(NSDecimalNumber(decimal: Decimal(999_999_999_999_999_999) * Decimal(10000))))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "mult",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "mult",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "mult",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "mult",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static let divTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "10 / 2",
            name: "div",
            args: [.number(10), .number(2)],
            expected: .success(.number(5))
        ),
        BuiltinTests.TestCase(
            description: "3 / 2",
            name: "div",
            args: [.number(3), .number(2)],
            expected: .success(.number(1.5))
        ),
        BuiltinTests.TestCase(
            description: "1 / 3",
            name: "div",
            args: [.number(1), .number(3)],
            // Cheating a little bit, just want to make sure they're resulting in high precision
            // NSDecimalNumber's from the Decimal division.
            expected: .success(.number(NSDecimalNumber(decimal: Decimal(1) / Decimal(3))))
        ),
        BuiltinTests.TestCase(
            description: "divide by 0",
            name: "div",
            args: [.number(3), .number(0)],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "div",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "div",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "div",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "div",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static let roundTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "round",
            args: [.number(1)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "round",
            args: [.number(1.111111)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "round",
            args: [.number(1.5)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "round",
            args: [.number(1.9999)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "round",
            args: [.number(-1.5)],
            expected: .success(.number(-2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "round",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "round",
            args: [.number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "round",
            args: [.string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let ceilTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "ceil",
            args: [.number(1)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "ceil",
            args: [.number(1.111111)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "ceil",
            args: [.number(1.5)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "ceil",
            args: [.number(1.9999)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "ceil",
            args: [.number(-1.5)],
            expected: .success(.number(-1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "ceil",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "ceil",
            args: [.number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "ceil",
            args: [.string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let floorTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "1",
            name: "floor",
            args: [.number(1)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.111111",
            name: "floor",
            args: [.number(1.111111)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.5",
            name: "floor",
            args: [.number(1.5)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "1.9999",
            name: "floor",
            args: [.number(1.9999)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "-1.5",
            name: "floor",
            args: [.number(-1.5)],
            expected: .success(.number(-2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "floor",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "floor",
            args: [.number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong arg type",
            name: "floor",
            args: [.string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let remTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "10 % 3",
            name: "rem",
            args: [.number(10), .number(3)],
            expected: .success(.number(1))
        ),
        BuiltinTests.TestCase(
            description: "10 % 10",
            name: "rem",
            args: [.number(10), .number(10)],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "rem",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "rem",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "float arg lhs",
            name: "rem",
            args: [.number(1.2345), .number(1)],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "float arg rhs",
            name: "rem",
            args: [.number(10), .number(1.2345)],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "rem",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "rem",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "y"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            plusTests,
            minusNumberTests,
            minusSetTests,
            multTests,
            divTests,
            roundTests,
            ceilTests,
            floorTests,
            remTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
