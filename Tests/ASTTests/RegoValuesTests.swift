import Foundation
import Testing

@testable import AST

@Test
func testJsonToRegoValues() throws {
    let input = #"""
          {
            "pets": [
              {
                "name": "Mr. Meowgi",
                "age": 4,
                "sibling": null,
                "weight": 12.5,
                "hasChildren": true,
                "hasBlueEyes": false,
                "children": [
                  "Wax On",
                  "Wax Off"
                ],
                "zero": 0,
                "one": 1
              },
              {
                "name": "Shadow",
                "age": 4,
                "sibling": "Light",
                "weight": 6.5,
                "hasChildren": false,
                "hasBlueEyes": true,
                "children": []
              }
            ]
          }
        """#

    let d = try JSONSerialization.jsonObject(with: input.data(using: .utf8)!)
    let val = try AST.RegoValue(from: d)

    let expected = AST.RegoValue([
        "pets": .array([
            RegoValue([
                "name": .string("Mr. Meowgi"),
                "age": .number(4),
                "sibling": .null,
                "weight": .number(12.5),
                "hasChildren": .boolean(true),
                "hasBlueEyes": .boolean(false),
                "children": .array([
                    .string("Wax On"),
                    .string("Wax Off"),
                ]),
                "zero": .number(0),
                "one": .number(1),
            ]),
            RegoValue([
                "name": .string("Shadow"),
                "age": .number(4),
                "sibling": .string("Light"),
                "weight": .number(6.5),
                "hasChildren": .boolean(false),
                "hasBlueEyes": .boolean(true),
                "children": .array([]),
            ]),
        ])
    ])
    #expect(expected == val)
}

@Test
func testNumberIsInteger() throws {
    // Integers
    #expect(AST.RegoValue.number(0).integerValue == 0)
    #expect(AST.RegoValue.number(123).integerValue == 123)
    #expect(AST.RegoValue.number(-123).integerValue == -123)
    #expect(AST.RegoValue.number(NSNumber(value: UInt8(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: Int8(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: UInt16(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: Int16(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: UInt32(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: Int32(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: UInt64(123))).integerValue == 123)
    #expect(AST.RegoValue.number(NSNumber(value: Double(0.0))).integerValue == 0)
    #expect(AST.RegoValue.number(NSNumber(value: 0.0)).integerValue == 0)
    #expect(AST.RegoValue.number(NSNumber(value: Float(0.0))).integerValue == 0)
    #expect(AST.RegoValue.number(NSNumber(value: Float(0))).integerValue == 0)
    #expect(AST.RegoValue.number(NSNumber(value: Bool(false))).integerValue == 0)
    #expect(AST.RegoValue.number(NSNumber(value: Bool(true))).integerValue == 1)

    // Not integers
    #expect(AST.RegoValue.number(NSNumber(value: Double(1.234567890))).integerValue == nil)
    #expect(AST.RegoValue.number(NSNumber(value: Float(1.23))).integerValue == nil)
    #expect(AST.RegoValue.string("").integerValue == nil)
    #expect(AST.RegoValue.string("foo").integerValue == nil)
    #expect(AST.RegoValue.string("123").integerValue == nil)
    #expect(AST.RegoValue.string("1.23").integerValue == nil)
    #expect(AST.RegoValue.boolean(false).integerValue == nil)
    #expect(AST.RegoValue.boolean(true).integerValue == nil)
    #expect(AST.RegoValue.array([]).integerValue == nil)
    #expect(AST.RegoValue.array([.number(1)]).integerValue == nil)
    #expect(AST.RegoValue.object([:]).integerValue == nil)
    #expect(AST.RegoValue.object([.string("foo"): .number(1)]).integerValue == nil)
    #expect(AST.RegoValue.set([]).integerValue == nil)
    #expect(AST.RegoValue.set([.number(1)]).integerValue == nil)
    #expect(AST.RegoValue.null.integerValue == nil)
    #expect(AST.RegoValue.undefined.integerValue == nil)
}

@Suite
struct SortingTests {
    struct TestCase {
        var description: String
        var input: [AST.RegoValue]
        var expected: [AST.RegoValue]
    }

    static let testCases: [TestCase] = [
        TestCase(
            description: "object: sort by keys, equal length",
            input: [
                .object([
                    .string("apple"): .string("pie"),
                    .string("orange"): .string("juice"),
                    .string("strawberry"): .string("shortcake"),
                ]),
                .object([
                    .string("apple"): .string("pie"),
                    .string("orange"): .string("juice"),
                    .string("plum"): .string("wine"),
                ]),
            ],
            expected: [
                // plum < strawberry
                .object([
                    .string("apple"): .string("pie"),
                    .string("orange"): .string("juice"),
                    .string("plum"): .string("wine"),
                ]),
                .object([
                    .string("apple"): .string("pie"),
                    .string("orange"): .string("juice"),
                    .string("strawberry"): .string("shortcake"),
                ]),
            ]
        ),
        TestCase(
            description: "object: equal keys, equal length, sort by values",
            input: [
                .object([
                    .string("id"): .string("s2"),
                    .string("stuff"): .object([:]),
                ]),
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .object([:]),
                ]),
            ],
            expected: [
                // s1 < s2
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .object([:]),
                ]),
                .object([
                    .string("id"): .string("s2"),
                    .string("stuff"): .object([:]),
                ]),
            ]
        ),
        TestCase(
            description: "object: sort by values, equal length",
            input: [
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(2),
                ]),
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
            ],
            expected: [
                // 1 < 2
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(2),
                ]),
            ]
        ),
        TestCase(
            description: "object: equal prefix, different lengths",
            input: [
                .object([
                    .string("zextra"): .string("value"),
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
            ],
            expected: [
                // less keys < more keys
                .object([
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
                .object([
                    .string("zextra"): .string("value"),
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
            ]
        ),
        TestCase(
            description: "object: unequal prefix, different lengths",
            input: [
                .object([
                    .string("zextra"): .string("value"),
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
                .object([
                    .string("id"): .string("s2"),
                    .string("stuff"): .number(1),
                ]),
            ],
            expected: [
                // s1 < s2
                .object([
                    .string("zextra"): .string("value"),
                    .string("id"): .string("s1"),
                    .string("stuff"): .number(1),
                ]),
                .object([
                    .string("id"): .string("s2"),
                    .string("stuff"): .number(1),
                ]),
            ]
        ),
        TestCase(
            description: "set: elements are sorted and compared like an array",
            input: [
                .set([
                    .number(6),
                    .number(1),
                    .number(5),
                ]),
                .set([
                    .number(3),
                    .number(1),
                    .number(2),
                ]),
            ],
            expected: [
                // 2 < 5
                .set([
                    .number(1),
                    .number(2),
                    .number(3),
                ]),
                .set([
                    .number(1),
                    .number(5),
                    .number(6),
                ]),
            ]
        ),
        TestCase(
            description: "set: otherwise equal, shorter before longer",
            input: [
                .set([
                    .number(1),
                    .number(2),
                    .number(3),
                    .number(4),
                ]),
                .set([
                    .number(1),
                    .number(2),
                    .number(3),
                ]),
            ],
            expected: [
                // shorter < longer
                .set([
                    .number(1),
                    .number(2),
                    .number(3),
                ]),
                .set([
                    .number(1),
                    .number(2),
                    .number(3),
                    .number(4),
                ]),
            ]
        ),
        TestCase(
            description: "array: in-order comparison",
            input: [
                .array([
                    .number(1),
                    .number(3),
                    .number(6),
                ]),
                .array([
                    .number(1),
                    .number(2),
                    .number(5),
                ]),
            ],
            expected: [
                // 2 < 3
                .array([
                    .number(1),
                    .number(2),
                    .number(5),
                ]),
                .array([
                    .number(1),
                    .number(3),
                    .number(6),
                ]),
            ]
        ),
        TestCase(
            description: "array: otherwise equal, shorter before longer",
            input: [
                .array([
                    .number(1),
                    .number(2),
                    .number(3),
                    .number(4),
                ]),
                .array([
                    .number(1),
                    .number(2),
                    .number(3),
                ]),
            ],
            expected: [
                // shorter < longer
                .array([
                    .number(1),
                    .number(2),
                    .number(3),
                ]),
                .array([
                    .number(1),
                    .number(2),
                    .number(3),
                    .number(4),
                ]),
            ]
        ),
    ]

    @Test(arguments: testCases)
    func testSorting(tc: TestCase) {
        let sorted = tc.input.sorted()
        #expect(sorted == tc.expected)
    }
}

extension SortingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
