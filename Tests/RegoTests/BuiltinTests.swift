import AST
import Foundation
import Testing

@testable import Rego

@Suite
struct BuiltinTests {
    struct TestCase {
        let description: String
        let name: String
        let args: [AST.RegoValue]
        var expected: Result<AST.RegoValue, Error>
    }

    static let arrayConcatTests: [TestCase] = [
        TestCase(
            description: "simple concat",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([.string("c"), .string("d")]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"), .string("c"), .string("d"),
                ]))
        ),
        TestCase(
            description: "lhs empty",
            name: "array.concat",
            args: [
                .array([]),
                .array([.string("c"), .string("d")]),
            ],
            expected: .success(
                .array([
                    .string("c"), .string("d"),
                ]))
        ),
        TestCase(
            description: "rhs empty",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"),
                ]))
        ),
        TestCase(
            description: "both empty",
            name: "array.concat",
            args: [
                .array([]),
                .array([]),
            ],
            expected: .success(.array([]))
        ),
        TestCase(
            description: "mixed types",
            name: "array.concat",
            args: [
                .array([.string("a"), .string("b")]),
                .array([.number(1), .number(2)]),
            ],
            expected: .success(
                .array([
                    .string("a"), .string("b"),
                    .number(1), .number(2),
                ]))
        ),
        TestCase(
            description: "lhs null (fail)",
            name: "array.concat",
            args: [
                .null,
                .array([.string("c"), .string("d")]),
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static var allTests: [TestCase] {
        [arrayConcatTests].flatMap { $0 }
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
        let result = await Result { try await reg.invoke(name: tc.name, args: tc.args) }
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
