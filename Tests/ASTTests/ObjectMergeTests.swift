import Foundation
import Testing

@testable import AST

@Suite
struct ObjectMergeTests {
    struct TestCase {
        var description: String
        var a: [AST.RegoValue: AST.RegoValue]
        var b: [AST.RegoValue: AST.RegoValue]
        var expected: [AST.RegoValue: AST.RegoValue]
    }

    static var allTests: [TestCase] {
        return [
            TestCase(
                description: "single depth with no conflicting keys",
                a: [
                    .string("a"): .string("a")
                ],
                b: [
                    .string("b"): .string("b")
                ],
                expected: [
                    .string("a"): .string("a"),
                    .string("b"): .string("b"),
                ]
            ),
            TestCase(
                description: "single depth with all conflicting keys",
                a: [
                    .string("a"): .string("a")
                ],
                b: [
                    .string("a"): .string("b")
                ],
                expected: [
                    .string("a"): .string("b")
                ]
            ),
            TestCase(
                description: "single depth with some conflicting keys in a",
                a: [
                    .string("a"): .string("a"),
                    .string("a2"): .string("a2"),
                ],
                b: [
                    .string("a"): .string("b")
                ],
                expected: [
                    .string("a"): .string("b"),
                    .string("a2"): .string("a2"),
                ]
            ),
            TestCase(
                description: "single depth with some conflicting keys in b",
                a: [
                    .string("a"): .string("a")
                ],
                b: [
                    .string("a"): .string("b"),
                    .string("b2"): .string("b2"),
                ],
                expected: [
                    .string("a"): .string("b"),
                    .string("b2"): .string("b2"),
                ]
            ),
            TestCase(
                description: "single depth with multiple conflicting keys in both",
                a: [
                    .string("a"): .string("a"),
                    .string("b"): .string("b"),
                ],
                b: [
                    .string("a"): .string("b"),
                    .string("b"): .string("b"),
                    .string("b2"): .string("b2"),
                ],
                expected: [
                    .string("a"): .string("b"),
                    .string("b"): .string("b"),
                    .string("b2"): .string("b2"),
                ]
            ),
            TestCase(
                description: "multi depth on a with no conflicting keys",
                a: [
                    .string("a"): .object([
                        .string("a1"): .object([
                            .string("a2"): .string("v1")
                        ])
                    ])
                ],
                b: [
                    .string("b"): .string("b")
                ],
                expected: [
                    .string("a"): .object([
                        .string("a1"): .object([
                            .string("a2"): .string("v1")
                        ])
                    ]),
                    .string("b"): .string("b"),
                ]
            ),
            TestCase(
                description: "multi depth on a with conflicting keys",
                a: [
                    .string("a"): .object([
                        .string("a1"): .object([
                            .string("a2"): .string("v1")
                        ])
                    ])
                ],
                b: [
                    .string("a"): .string("b")
                ],
                expected: [
                    .string("a"): .string("b")
                ]
            ),
            TestCase(
                description: "multi depth on b with conflicting keys",
                a: [
                    .string("a"): .string("a")
                ],
                b: [
                    .string("a"): .object([
                        .string("b1"): .object([
                            .string("b2"): .string("v1")
                        ])
                    ])
                ],
                expected: [
                    .string("a"): .object([
                        .string("b1"): .object([
                            .string("b2"): .string("v1")
                        ])
                    ])
                ]
            ),
            TestCase(
                description: "multi depth merge on sub tree",
                a: [
                    .string("x"): .object([
                        .string("y"): .object([
                            .string("z"): .object([
                                .string("a"): .string("a")
                            ])
                        ])
                    ])
                ],
                b: [
                    .string("x"): .object([
                        .string("y"): .object([
                            .string("z2"): .string("v2"),
                            .string("z3"): .object([
                                .string("z4"): .string("v4")
                            ]),
                        ])
                    ])
                ],
                expected: [
                    .string("x"): .object([
                        .string("y"): .object([
                            .string("z"): .object([
                                .string("a"): .string("a")
                            ]),
                            .string("z2"): .string("v2"),
                            .string("z3"): .object([
                                .string("z4"): .string("v4")
                            ]),
                        ])
                    ])
                ]
            ),
        ]
    }

    @Test(arguments: allTests)
    func testPatch(tc: TestCase) throws {
        let originalA = tc.a
        let originalB = tc.b
        let merged = tc.a.merge(with: tc.b)
        #expect(merged == tc.expected)

        // Original should be unmodified
        #expect(tc.a == originalA)
        #expect(tc.b == originalB)
    }
}

extension ObjectMergeTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
