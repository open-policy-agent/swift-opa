import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Bits", .tags(.builtins))
    struct BitsTests {}
}

extension BuiltinTests.BitsTests {
    static let bitsShiftLeftTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "0 << 0",
            name: "bits.lsh",
            args: [0, 0],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "1 << 1",
            name: "bits.lsh",
            args: [1, 1],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1 << 7",
            name: "bits.lsh",
            args: [1, 7],
            expected: .success(.number(NSNumber(value: Int(1 << 7))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 33",
            name: "bits.lsh",
            args: [1, 33],
            expected: .success(.number(NSNumber(value: Int(1 << 33))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 64",
            name: "bits.lsh",
            args: [1, 64],
            expected: .success(.number(NSNumber(value: Int(1 << 64))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 65",
            name: "bits.lsh",
            args: [1, 65],
            expected: .success(.number(NSNumber(value: 0)))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "bits.lsh",
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "bits.lsh",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong lhs arg type",
            name: "bits.lsh",
            args: ["1", 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a"))
        ),
        BuiltinTests.TestCase(
            description: "wrong rhs arg type",
            name: "bits.lsh",
            args: [1, "1"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            bitsShiftLeftTests
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
