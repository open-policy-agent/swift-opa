import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Rand", .tags(.builtins))
    struct RandTests {}
}

extension BuiltinTests.RandTests {
    static let randTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "with n=0",
            name: "rand.intn",
            args: ["key", 0],
            expected: .success(0)
        ),

        BuiltinTests.TestCase(
            description: "with n is not an integer",
            name: "rand.intn",
            args: ["key", 100.1],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 must be integer number but got floating-point number"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            randTests,
            BuiltinTests.generateFailureTests(
                builtinName: "rand.intn", sampleArgs: ["key", 10], argIndex: 0,
                argName: "str", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "rand.intn", sampleArgs: ["key", 10], argIndex: 1,
                argName: "n", allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    static let boundaries: [Int64] = [
        Int64(Int32.min) - 10, -5_647_870, -500, 0, 10, Int64(Int32.max), Int64(Int32.max) + 10,
    ]

    @Test("rand.intn returns correct value for n=", arguments: boundaries)
    func randIntNReturnsCorrectValue(n: Int64) async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result = try await reg.invoke(
            withContext: ctx, name: "rand.intn",
            args: ["foo", .number(RegoNumber(value: n))], strict: true)
        switch result {
        case .number(let value):
            #expect(!result.isFloat, "expect result to be an integer")

            let intValue = value.uint64Value

            // Make sure the returned value is within correct bounds.
            if n != 0 {
                #expect(intValue >= 0 && intValue < Swift.abs(n), "expect result to be within bound of \(n)")
            } else {
                #expect(intValue == 0, "expect result to 0 for n=0")
            }
        default:
            Issue.record("rand.intn with n=\(n) should return an integer, but got: \(result)")
        }
    }

    @Test
    func randIntNReturnsSameValueForSameInputs() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "rand.intn", args: ["foo", 1000], strict: true)
        let result2 = try await reg.invoke(withContext: ctx, name: "rand.intn", args: ["foo", 1000], strict: true)
        #expect(result1 == result2)
    }

    @Test
    func randIntNReturnsDifferentValueForDifferentBounds() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "rand.intn", args: ["foo", 1], strict: true)
        // Using large n avoids having two random numbers match in practice via two sequential calls
        // to SystemRandomNumberGenerator which will be used by ctx
        let result2 = try await reg.invoke(
            withContext: ctx, name: "rand.intn", args: ["foo", 10_000_000],
            strict: true)

        #expect(result1 != result2)
    }

    @Test
    func randIntNReturnsDifferentValuesForDifferentKeys() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        // Using large n avoids having two random numbers match in practice via two sequential calls
        // to SystemRandomNumberGenerator which will be used by ctx
        let result1 = try await reg.invoke(
            withContext: ctx, name: "rand.intn", args: ["foo", 10_000_000],
            strict: true)
        let result2 = try await reg.invoke(
            withContext: ctx, name: "rand.intn", args: ["bar", 10_000_000],
            strict: true)
        #expect(result1 != result2)
    }
}
