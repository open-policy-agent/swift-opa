import Foundation
import Testing

@testable import AST

@Suite
struct PatchTests {
    struct TestCase {
        var description: String
        var data: AST.RegoValue
        var with: AST.RegoValue
        var path: [String]
        var expected: AST.RegoValue
    }

    static var allTests: [TestCase] {
        return [
            TestCase(
                description: "null replace",
                data: .null,
                with: .number(42),
                path: ["foo"],
                expected: .object([.string("foo"): .number(42)])
            ),
            TestCase(
                description: "simple replace",
                data: .object([.string("foo"): .string("fr fr")]),
                with: .number(42),
                path: ["foo"],
                expected: .object([.string("foo"): .number(42)])
            ),
            TestCase(
                description: "deeper, no conflicts",
                data: .object([.string("foo"): .string("fr fr")]),
                with: .object([.string("answer"): .number(42)]),
                path: ["sibling", "nested"],
                expected: .object([
                    .string("foo"): .string("fr fr"),
                    .string("sibling"): .object([
                        .string("nested"): .object([
                            .string("answer"): .number(42)
                        ])
                    ]),
                ])
            ),
            TestCase(
                description: "intermediate node which is not an object is overwritten",
                data: .object([
                    .string("foo"): .object([
                        .string("other"): .string("stuff"),
                        .string("bar"): .number(1),
                    ])
                ]),
                with: .object([.string("answer"): .number(42)]),
                path: ["foo", "bar", "baz", "buz"],
                expected: .object([
                    .string("foo"): .object([
                        .string("other"): .string("stuff"),
                        .string("bar"): .object([
                            .string("baz"): .object([
                                .string("buz"): .object([
                                    .string("answer"): .number(42)
                                ])
                            ])
                        ]),
                    ])
                ])
            ),
            TestCase(
                description: "empty path will overwrite the whole document",
                data: .object([
                    .string("foo"): .string("bar")
                ]),
                with: .number(42),
                path: [],
                expected: .number(42)
            ),
        ]
    }

    @Test(arguments: allTests)
    func testPatch(tc: TestCase) throws {
        let original = tc.data
        let patched = tc.data.patch(with: tc.with, at: tc.path)
        #expect(patched == tc.expected)

        // Original should be unmodified
        #expect(tc.data == original)
        #expect(tc.data != patched)
    }
}

extension PatchTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
