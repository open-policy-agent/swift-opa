import Foundation
import Testing

@testable import SwiftRego

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
    let val = try RegoValue(from: d)

    let expected = RegoValue.object([
        "pets": .array([
            .object([
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
            .object([
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
