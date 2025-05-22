import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Time", .tags(.builtins))
    struct TimeTests {}
}

extension BuiltinTests.TimeTests {
    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.now_ns", sampleArgs: [])
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
            #expect(actual.uint64Value >= expected)
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
            #expect(actual.uint64Value == UInt64(expected.timeIntervalSince1970 * 1_000_000_000))
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
