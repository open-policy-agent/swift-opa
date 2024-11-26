import Foundation
import Testing

@testable import SwiftRego

@preconcurrency
struct decodeIRTestCase {
    var name: String
    var json: String
    var policy: Policy
}

@Test(arguments: [
    decodeIRTestCase(
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
]) func decodeIR(tc: decodeIRTestCase) async throws {
    let actual = try JSONDecoder().decode(Policy.self, from: tc.json.data(using: .utf8)!)
    #expect(actual == tc.policy)
}

@Test("decodeIR Statements")
func decodeIRStatements() throws {
    for tc in [
        decodeIRTestCase(
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
    struct testCase {
        var name: String?
        var json: String
        var expected: ResultExpectation<Operand, Error.Type>
    }

    for tc in [
        testCase(
            name: "simple local",
            json: #"""
                {
                    "type": "local",
                    "value": 7
                }
                """#,
            expected: .success(Operand(type: .local, value: .number(7)))
        ),
        testCase(
            name: "simple bool",
            json: #"""
                {
                    "type": "bool",
                    "value": true
                }
                """#,
            expected: .success(Operand(type: .bool, value: .bool(true)))
        ),
        testCase(
            name: "simple string_index",
            json: #"""
                {
                    "type": "string_index",
                    "value": 123
                }
                """#,
            expected: .success(Operand(type: .string_index, value: .string_index(123)))
        ),
        testCase(
            name: "invalid type",
            json: #"""
                {
                    "type": "invalid!",
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        testCase(
            name: "missing type",
            json: #"""
                {
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        testCase(
            name: "missing value",
            json: #"""
                {
                    "type": "local",
                }
                """#,
            //expected: .success(Operand(type: .local, value: .number(7)))  //.failure(DecodingError.self)
            expected: .failure(DecodingError.self)
        )
    ] {
        let result: Result<Operand, Error> = Result{
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
        case .failure(_):
            // TODO check the exact error!!
            #expect(throws: (any Error).self, commentFor(tc.name)) { try result.get() }
//            #expect{try actual.get()} throws: { error in
//                error is errType
//            }
//            do {
//                try actual.get()
//            }
//            catch let err {
//                #expect(err is errType.self)
//            }
//            #expect(error: errType) { try actual.get() }
        }
    }
}

func commentFor(_ name: String?) -> Comment {
    guard let name else {
        return Comment("[failed testcase: unnamed]")
    }
    return Comment(rawValue: "[failed testcase: \(name)]")
}
