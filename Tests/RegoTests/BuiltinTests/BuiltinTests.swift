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

    static var allTests: [TestCase] {
        [
            ArrayTests.arrayConcatTests,
            BitsTests.bitsShiftLeftTests,
            CollectionsTests.isMemberOfTests,
        ].flatMap { $0 }
    }

    func successEquals<T, E>(_ lhs: Result<T, E>, _ rhs: Result<T, E>) -> Bool where T: Equatable {
        guard case .success(let lhsValue) = lhs else {
            return false
        }
        guard case .success(let rhsValue) = rhs else {
            return false
        }
        return lhsValue == rhsValue
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: TestCase) async throws {
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
