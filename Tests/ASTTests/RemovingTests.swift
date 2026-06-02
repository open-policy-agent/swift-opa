import Foundation
import Testing

@testable import AST

@Suite
struct RemovingTests {
    struct TestCase {
        var description: String
        var data: AST.RegoValue
        var path: [String]
        var expected: AST.RegoValue
    }

    static var allTests: [TestCase] {
        return [
            TestCase(
                description: "remove leaf",
                data: .object([
                    .string("foo"): .number(1),
                    .string("bar"): .number(2),
                ]),
                path: ["foo"],
                expected: .object([
                    .string("bar"): .number(2)
                ])
            ),
            TestCase(
                description: "remove nested leaf, parent preserved even when emptied",
                data: .object([
                    .string("foo"): .object([
                        .string("bar"): .number(1)
                    ]),
                    .string("baz"): .number(2),
                ]),
                path: ["foo", "bar"],
                expected: .object([
                    .string("foo"): .object([:]),
                    .string("baz"): .number(2),
                ])
            ),
            TestCase(
                description: "remove non-existent leaf is no-op",
                data: .object([
                    .string("foo"): .number(1)
                ]),
                path: ["nope"],
                expected: .object([
                    .string("foo"): .number(1)
                ])
            ),
            TestCase(
                description: "remove through non-existent intermediate is no-op",
                data: .object([
                    .string("foo"): .number(1)
                ]),
                path: ["nope", "still", "missing"],
                expected: .object([
                    .string("foo"): .number(1)
                ])
            ),
            TestCase(
                description: "remove through non-object intermediate is no-op",
                data: .object([
                    .string("foo"): .number(1)
                ]),
                path: ["foo", "bar"],
                expected: .object([
                    .string("foo"): .number(1)
                ])
            ),
            TestCase(
                description: "empty path resets to empty object",
                data: .object([
                    .string("foo"): .number(1)
                ]),
                path: [],
                expected: .object([:])
            ),
            TestCase(
                description: "remove on non-object root is no-op",
                data: .number(42),
                path: ["foo"],
                expected: .number(42)
            ),
            // Array element removal compacts the array (matches Store.applyRemove).
            TestCase(
                description: "remove array element by index compacts",
                data: .array([.number(10), .number(20), .number(30)]),
                path: ["1"],
                expected: .array([.number(10), .number(30)])
            ),
            // Recurse through an array index into a nested object.
            TestCase(
                description: "remove object key reached through array index",
                data: .object([
                    .string("items"): .array([
                        .object([.string("a"): .number(1), .string("b"): .number(2)])
                    ])
                ]),
                path: ["items", "0", "a"],
                expected: .object([
                    .string("items"): .array([
                        .object([.string("b"): .number(2)])
                    ])
                ])
            ),
            // Array no-op guards: non-integer, out-of-bounds, and negative index.
            TestCase(
                description: "array non-integer index is no-op",
                data: .array([.number(1), .number(2)]),
                path: ["foo"],
                expected: .array([.number(1), .number(2)])
            ),
            TestCase(
                description: "array out-of-bounds index is no-op",
                data: .array([.number(1), .number(2)]),
                path: ["5"],
                expected: .array([.number(1), .number(2)])
            ),
            TestCase(
                description: "array negative index is no-op",
                data: .array([.number(1), .number(2)]),
                path: ["-1"],
                expected: .array([.number(1), .number(2)])
            ),
        ]
    }

    @Test(arguments: allTests)
    func testRemoving(tc: TestCase) throws {
        let original = tc.data
        let result = tc.data.removing(at: tc.path)
        #expect(result == tc.expected)

        // Original should be unmodified.
        #expect(tc.data == original)
    }

    @Test
    func testRemovingDeepLeafLeavesAncestorsIntact() throws {
        let v = AST.RegoValue.object([
            .string("a"): .object([
                .string("b"): .object([
                    .string("c"): .number(1),
                    .string("d"): .number(2),
                ])
            ])
        ])
        let result = v.removing(at: ["a", "b", "c"])
        let expected = AST.RegoValue.object([
            .string("a"): .object([
                .string("b"): .object([
                    .string("d"): .number(2)
                ])
            ])
        ])
        #expect(result == expected)
    }
}

extension RemovingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
