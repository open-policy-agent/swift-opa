import AST
import Foundation
import Testing

@testable import Rego

@Suite("ResultSetTests")
struct ResultSetTests {
    struct TestCase: Sendable {
        let description: String
        let evalResults: [EvalResult]
        let expectedResults: [EvalResult]
    }

    static var testCases: [TestCase] {
        return [
            TestCase(
                description: "simple depdup",
                evalResults: [
                    ["some.query.path": AST.RegoValue.string("some value")],
                    ["some.query.path": AST.RegoValue.string("some other value")],
                    ["some.query.path": AST.RegoValue.string("some value")],
                ],
                expectedResults: [
                    ["some.query.path": AST.RegoValue.string("some value")],
                    ["some.query.path": AST.RegoValue.string("some other value")],
                ]
            ),
            TestCase(
                description: "more depdup",
                evalResults: [
                    [
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue.object([
                            "key": AST.RegoValue.object(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ],
                    ["some.query.path": AST.RegoValue.string("some other value")],
                    ["some.query.path": AST.RegoValue.string("some value")],
                    [
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue.object([
                            "key": AST.RegoValue.object(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ],
                ],
                expectedResults: [
                    ["some.query.path": AST.RegoValue.string("some value")],
                    ["some.query.path": AST.RegoValue.string("some other value")],
                    [
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue.object([
                            "key": AST.RegoValue.object(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ],
                ]
            ),
        ]
    }

    // Verify ResultSet dedup with EvalResult hashing / equality generated conformance
    @Test(arguments: testCases)
    func testResultSet(tc: TestCase) throws {
        let s = ResultSet(tc.evalResults)
        let expectedSet = ResultSet(tc.expectedResults)
        #expect(s == expectedSet)
    }
}

extension ResultSetTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
