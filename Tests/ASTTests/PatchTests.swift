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
                expected: .object(["foo": .number(42)])
            ),
            TestCase(
                description: "simple replace",
                data: .object(["foo": .string("fr fr")]),
                with: .number(42),
                path: ["foo"],
                expected: .object(["foo": .number(42)])
            ),
            TestCase(
                description: "deeper, no conflicts",
                data: .object(["foo": .string("fr fr")]),
                with: .object(["answer": .number(42)]),
                path: ["sibling", "nested"],
                expected: .object([
                    "foo": .string("fr fr"),
                    "sibling": .object([
                        "nested": .object([
                            "answer": .number(42)
                        ])
                    ]),
                ])
            ),
            TestCase(
                description: "intermediate node which is not an object is overwritten",
                data: .object([
                    "foo": .object([
                        "other": .string("stuff"),
                        "bar": .number(1),
                    ])
                ]),
                with: .object(["answer": .number(42)]),
                path: ["foo", "bar", "baz", "buz"],
                expected: .object([
                    "foo": .object([
                        "other": .string("stuff"),
                        "bar": .object([
                            "baz": .object([
                                "buz": .object([
                                    "answer": .number(42)
                                ])
                            ])
                        ]),
                    ])
                ])
            ),
            TestCase(
                description: "empty path will overwrite the whole document",
                data: .object([
                    "foo": .string("bar")
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
