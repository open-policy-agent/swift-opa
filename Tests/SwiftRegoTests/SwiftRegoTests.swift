import Foundation
import Testing

@testable import SwiftRego

@preconcurrency
struct DecodeIRTestCase {
    var name: String
    var json: String
    var policy: Policy
}
extension DecodeIRTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

@Test(arguments: [
    DecodeIRTestCase(
        name: "static simple",
        json: #"""
            {
              "static": {
                "strings": [
                  {
                    "value": "result"
                  },
                  {
                    "value": "message"
                  },
                  {
                    "value": "world"
                  }
                ],
                "files": [
                  {
                    "value": "example.rego"
                  }
                ]
              }
            }
            """#,
        policy: Policy(
            staticData: Static(
                strings: [
                    ConstString(value: "result"),
                    ConstString(value: "message"),
                    ConstString(value: "world"),
                ],
                files: [
                    ConstString(value: "example.rego")
                ]
            )
        )
    )
]) func decodeIR(tc: DecodeIRTestCase) async throws {
    let actual = try JSONDecoder().decode(Policy.self, from: tc.json.data(using: .utf8)!)
    #expect(actual == tc.policy)
}

@Test("decodeIR Statements")
func decodeIRStatements() throws {
    for tc in [
        DecodeIRTestCase(
            name: "simple",
            json: #"""
                {"plans":{"plans":[{"name":"policy/hello","blocks":[{"stmts":[{"type":"CallStmt","stmt":{"func":"g0.data.policy.hello","args":[{"type":"local","value":0},{"type":"local","value":1}],"result":2,"file":9,"col":8,"row":0}},{"type":"AssignVarStmt","stmt":{"source":{"type":"local","value":2},"target":3,"file":0,"col":0,"row":0}},{"type":"MakeObjectStmt","stmt":{"target":4,"file":0,"col":0,"row":0}},{"type":"ObjectInsertStmt","stmt":{"key":{"type":"string_index","value":0},"value":{"type":"local","value":3},"object":4,"file":0,"col":0,"row":0}},{"type":"ResultSetAddStmt","stmt":{"value":4,"file":0,"col":0,"row":0}}]}]}]}}
                """#,
            policy: Policy()
        )
    ] {
        let actual = try JSONDecoder().decode(Policy.self, from: tc.json.data(using: .utf8)!)
        #expect(actual == tc.policy)
    }
}

enum ResultExpectation<Success, Failure> {
    case success(Success)
    case failure(Failure)
}

@Test("decodeIR Operands")
func decodeIROperands() throws {
    struct TestCase {
        var name: String?
        var json: String
        var expected: ResultExpectation<Operand, any (Error.Type)>
    }

    for tc in [
        TestCase(
            name: "simple local",
            json: #"""
                {
                    "type": "local",
                    "value": 7
                }
                """#,
            expected: .success(Operand(type: .local, value: .number(7)))
        ),
        TestCase(
            name: "simple bool",
            json: #"""
                {
                    "type": "bool",
                    "value": true
                }
                """#,
            expected: .success(Operand(type: .bool, value: .bool(true)))
        ),
        TestCase(
            name: "simple string_index",
            json: #"""
                {
                    "type": "string_index",
                    "value": 123
                }
                """#,
            expected: .success(Operand(type: .stringIndex, value: .stringIndex(123)))
        ),
        TestCase(
            name: "invalid type",
            json: #"""
                {
                    "type": "invalid!",
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        TestCase(
            name: "missing type",
            json: #"""
                {
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        TestCase(
            name: "missing value field",
            json: #"""
                {
                    "type": "local",
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
    ] {
        let result: Result<Operand, Error> = Result {
            try JSONDecoder()
                .decode(Operand.self, from: tc.json.data(using: .utf8)!)
        }

        switch tc.expected {
        case .success(let expectedValue):
            #expect(throws: Never.self, commentFor(tc.name)) {
                // Check for unexpected exceptions separately (otherwise we can't customize the comment)
                try result.get()
            }
            // TODO! Check with the Xcode folks - we don't seem to get the fancy comparison stuff
            // for failures when we do #expect(try result.get() == expectedValue)
            guard let actual = try? result.get() else {
                return
            }
            #expect(actual == expectedValue, commentFor(tc.name))
        case .failure(let expectedErr):
            #expect(commentFor(tc.name)) { try result.get() } throws: { error in
                let mirror = Mirror(reflecting: error)
                let b: Bool = mirror.subjectType == expectedErr
                return b
            }
        }
    }
}

func commentFor(_ name: String?) -> Comment {
    guard let name else {
        return Comment("[failed testcase: unnamed]")
    }
    return Comment(rawValue: "[failed testcase: \(name)]")
}
