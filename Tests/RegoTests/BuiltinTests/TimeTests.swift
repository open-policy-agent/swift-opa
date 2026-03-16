import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Time", .tags(.builtins))
    struct TimeTests {}
}

extension BuiltinTests.TimeTests {
    static let addDateTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "ns must be an integer",
            name: "time.add_date",
            args: [42.5, 0, 0, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 0 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "years must be an integer",
            name: "time.add_date",
            args: [12345, 0.75, 0, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 1 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "months must be an integer",
            name: "time.add_date",
            args: [12345, 0, 0.75, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "days must be an integer",
            name: "time.add_date",
            args: [12345, 0, 0, 0.75],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 3 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "adds year month day",
            name: "time.add_date",
            args: [1_585_852_421_593_912_000, 3, 9, 12],
            expected: .success(1_705_257_221_593_912_000)
        ),
        BuiltinTests.TestCase(
            description: "adds negative values",
            name: "time.add_date",
            args: [1_585_852_421_593_912_000, -1, -1, -1],
            expected: .success(1_551_465_221_593_912_000)
        ),
        BuiltinTests.TestCase(
            description: "time outside of valid range: too large",
            name: "time.add_date",
            args: [0, 2262, 1, 1],
            expected: .failure(
                BuiltinError.evalError(msg: "time outside of valid range")
            )
        ),
        BuiltinTests.TestCase(
            description: "time outside of valid range: too small",
            name: "time.add_date",
            args: [-9_223_372_036_854_775_808, 0, 0, -1],
            expected: .failure(
                BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        // February has 28 days
        // 2025-02-01 + 1 year = 2026-02-01, + 2 months = 2026-04-01, + 5 days = 2026-04-06
        BuiltinTests.TestCase(
            description: "adding 1 year 2 months 5 days to 2025-02-01",
            name: "time.add_date",
            args: [1_738_368_000_000_000_000, 1, 2, 5],
            expected: .success(1_775_433_600_000_000_000)
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 0,
                argName: "ns",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 1,
                argName: "years",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 2,
                argName: "months",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 3,
                argName: "days",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.now_ns", sampleArgs: []),
            addDateTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    @Test
    func timeNowNanosReturnsValidTime() async throws {
        let expected = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        // Make sure the output is *actually* an integer that represents time
        switch result {
        case .number(let actual):
            #expect(actual.clampedUint64Value >= expected)
        default:
            Issue.record("time.now_ns should return a number, but got: \(result)")
        }
    }

    @Test
    func timeNowNanosReturnsTimeFromContext() async throws {
        let expected = Date()
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext(timestamp: expected)
        let result = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        // Make sure the output is *actually* an integer that represents current time
        switch result {
        case .number(let actual):
            #expect(actual.clampedUint64Value == UInt64(expected.timeIntervalSince1970 * 1_000_000_000))
        default:
            Issue.record("time.now_ns should return a number, but got: \(result)")
        }
    }

    @Test
    func timeNowNanosReturnsSameValueForSameContext() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        let result2 = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        #expect(result1 == result2)
    }

    @Test
    func timeNowNanosReturnsDifferentValuesForDifferentContexts() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx1 = BuiltinContext()
        let ctx2 = BuiltinContext(timestamp: ctx1.timestamp.addingTimeInterval(2))
        let result1 = try await reg.invoke(withContext: ctx1, name: "time.now_ns", args: [], strict: true)
        let result2 = try await reg.invoke(withContext: ctx2, name: "time.now_ns", args: [], strict: true)
        #expect(result2 > result1)
    }
}
