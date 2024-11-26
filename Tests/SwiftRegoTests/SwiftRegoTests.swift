import Testing

@testable import SwiftRego

struct decodeIRTestCase {
    var json: String
    var policy: Policy
}

@Test(arguments: [
    [
        decodeIRTestCase(json: #"""
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
                                   ConstString(value: "world")
                                ],
                                files: [
                                    ConstString(value: "example.rego")
                                ]
                         )
                     )
                        ),
    ]



]) func decodeIR(tc: decodeIRTestCase) async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}
