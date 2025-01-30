import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests")
struct BitsTests {
    static let bitsShiftLeftTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "0 << 0",
            name: "bits.lsh",
            args: [.number(0), .number(0)],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "1 << 1",
            name: "bits.lsh",
            args: [.number(1), .number(1)],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1 << 7",
            name: "bits.lsh",
            args: [.number(1), .number(7)],
            expected: .success(.number(NSNumber(value: Int(1 << 7))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 33",
            name: "bits.lsh",
            args: [.number(1), .number(33)],
            expected: .success(.number(NSNumber(value: Int(1 << 33))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 64",
            name: "bits.lsh",
            args: [.number(1), .number(64)],
            expected: .success(.number(NSNumber(value: Int(1 << 64))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 65",
            name: "bits.lsh",
            args: [.number(1), .number(65)],
            expected: .success(.number(NSNumber(value: 0)))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "array.concat",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "array.concat",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "array.concat",
            args: [.string("1"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "array.concat",
            args: [.number(1), .string("1")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]
}
