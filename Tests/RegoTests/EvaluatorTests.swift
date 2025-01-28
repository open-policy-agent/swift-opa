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
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some value")]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some other value")]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some value")]),
                ],
                expectedResults: [
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some value")]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some other value")]),
                ]
            ),
            TestCase(
                description: "more depdup",
                evalResults: [
                    AST.RegoValue([
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue([
                            "key": AST.RegoValue(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some other value")]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some value")]),
                    AST.RegoValue([
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue([
                            "key": AST.RegoValue(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ]),
                ],
                expectedResults: [
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some value")]),
                    AST.RegoValue(["some.query.path": AST.RegoValue.string("some other value")]),
                    AST.RegoValue([
                        "some.query.path": AST.RegoValue.string("some value"),
                        "some.other.query": AST.RegoValue([
                            "key": AST.RegoValue(
                                ["nested.key": AST.RegoValue.string("nested value")]
                            )
                        ]),
                    ]),
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
