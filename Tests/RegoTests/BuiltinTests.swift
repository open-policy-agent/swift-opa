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

        func withPrefix(_ prefix: String) -> TestCase {
            return TestCase(
                description: "\(prefix): \(description)",
                name: name,
                args: args,
                expected: expected
            )
        }
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

    // Tests isMemberOf
    static let isMemberOfTests: [TestCase] = [
        TestCase(
            description: "y in x(array) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .array([.string("c"), .number(42), .string("d")]),
            ],
            expected: .success(.boolean(true))
        ),
        TestCase(
            description: "y in x(array) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .array([.string("c"), .number(0), .string("d")]),
            ],
            expected: .success(.boolean(false))
        ),
        TestCase(
            description: "y in x(object) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.string("c"): .number(42), .string("d"): .null]),
            ],
            expected: .success(.boolean(true))
        ),
        TestCase(
            description: "y in x(object) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.string("c"): .number(0), .string("d"): .null]),
            ],
            expected: .success(.boolean(false))
        ),
        TestCase(
            description: "y in x(object) -> false - not keys",
            name: "internal.member_2",
            args: [
                .number(42),
                .object([.number(42): .number(0), .string("d"): .null]),
            ],
            expected: .success(.boolean(false))
        ),
        TestCase(
            description: "y in x(set) -> true",
            name: "internal.member_2",
            args: [
                .number(42),
                .set([.string("c"), .number(42), .string("d")]),
            ],
            expected: .success(.boolean(true))
        ),
        TestCase(
            description: "y in x(set) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .set([.string("c"), .number(0), .string("d")]),
            ],
            expected: .success(.boolean(false))
        ),
        TestCase(
            description: "y in x(null) -> false",
            name: "internal.member_2",
            args: [
                .number(42),
                .null,
            ],
            expected: .success(.boolean(false))
        ),
    ]

    static var allTests: [TestCase] {
        [
            arrayConcatTests,
            isMemberOfTests,
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
