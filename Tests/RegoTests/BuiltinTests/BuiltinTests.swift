import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests")
struct BuiltinTests {
    struct TestCase {
        let description: String
        let name: String
        let args: [AST.RegoValue]
        var expected: Result<AST.RegoValue, Error>

        func withPrefix(_ prefix: String) -> TestCase {
            return TestCase(
                description: "\(prefix): \(description)",
                name: name,
                args: args,
                expected: expected
            )
        }
    }

    static func testBuiltin(tc: TestCase) async throws {
        let reg = defaultBuiltinRegistry
        let bctx = BuiltinContext()
        let result = await Result { try await reg.invoke(withCtx: bctx, name: tc.name, args: tc.args) }
        switch tc.expected {
        case .success:
            #expect(successEquals(result, tc.expected))
        case .failure:
            #expect(throws: (any Error).self) {
                try result.get()
            }
        }
    }

    static func successEquals<T, E>(_ lhs: Result<T, E>, _ rhs: Result<T, E>) -> Bool where T: Equatable {
        guard case .success(let lhsValue) = lhs else {
            return false
        }
        guard case .success(let rhsValue) = rhs else {
            return false
        }
        return lhsValue == rhsValue
    }

    /// For covering argument type checks and arguments count checks,
    /// this method generates a series of tests for a *given* argument to only be accepted with correct type,
    /// as well as (optionally) for correct number of arguments being passed into a builtin.
    /// The latter should only be used once per builtin, but the former can be repeated for each arg.
    /// Returns a list of test cases.
    /// - Parameters:
    ///   - builtinName: The name of the builtin function being tested.
    ///   - sampleArgs: The sample arguments to use. Use correct arguments for the builtin you are testing.
    ///     They will be copied and mutated for each test to inject an expected failure.
    ///   - argIndex: The index of the argument to check.
    ///   - argName: The name of the argument to expect.
    ///   - allowedArgTypes: The list of allowed argument types for the argument (could be more than one).
    static func generateFailureTests(
        builtinName: String,
        sampleArgs: [RegoValue], argIndex: Int, argName: String,
        allowedArgTypes: [String], generateNumberOfArgsTest: Bool = false
    ) -> [BuiltinTests.TestCase] {
        let argValues: [String: RegoValue] = [
            "array": [1, 2, 3], "boolean": false, "null": .null, "number": 123, "object": ["a": 1], "set": .set([0]),
            "string": "hello", "undefined": .undefined,
        ]
        var tests: [BuiltinTests.TestCase] = []
        if generateNumberOfArgsTest {
            // Only generate "too few" test case when expected number of arguments is > 0
            if sampleArgs.count > 0 {
                tests.append(
                    BuiltinTests.TestCase(
                        description: "wrong number of arguments (too few)",
                        name: builtinName,
                        args: [],
                        expected: .failure(
                            BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: sampleArgs.count))
                    )
                )
            }
            // too many agrs case
            var tooManyArgs = sampleArgs  // copy
            tooManyArgs.append(.null)
            tests.append(
                BuiltinTests.TestCase(
                    description: "wrong number of arguments (too many) with " + String(tooManyArgs.count)
                        + " arguments",
                    name: builtinName,
                    args: tooManyArgs,
                    expected: .failure(
                        BuiltinFuncs.BuiltinError.argumentCountMismatch(
                            got: tooManyArgs.count, expected: sampleArgs.count))
                )
            )
        }
        var want = allowedArgTypes.joined(separator: "|")
        if allowedArgTypes.count == 1 {
            want = allowedArgTypes[0]
        }
        // for all the WRONG types, generate a specific test case
        for testType in argValues.keys.filter({ !allowedArgTypes.contains($0) }) {
            var wrongArgs = sampleArgs  // copy
            wrongArgs[argIndex] = argValues[testType]!  // insert the wrong argument at the expected index
            tests.append(
                BuiltinTests.TestCase(
                    description: argName + " argument has incorrect type - " + testType,
                    name: builtinName,
                    args: wrongArgs,
                    expected: .failure(
                        BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: argName, got: testType, want: want))
                )
            )
        }

        return tests
    }

}

extension BuiltinTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { "\(name): \(description)" }
}

extension Result {
    // There's a synchronous version of this built-in, let's
    // add an asynchronous variant!
    public init(_ body: () async throws(Failure) -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
