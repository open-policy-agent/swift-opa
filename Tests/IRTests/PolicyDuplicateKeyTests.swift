import AST
import Foundation
import Testing

@testable import IR

@Suite
struct PolicyDuplicateKeyTests {
    // Reads an existing IR test fixture from Tests/IRTests/Fixtures (bundled as a test resource).
    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(name)"))
    }

    // Prepends a member to the top-level object, duplicating a key the fixture already has.
    static func injectingTopLevelMember(_ member: String, into data: Data) throws -> Data {
        let text = String(decoding: data, as: UTF8.self)
        let brace = try #require(text.firstIndex(of: "{"))
        return Data((String(text[...brace]) + member + "," + String(text[text.index(after: brace)...])).utf8)
    }

    // The unmodified fixture has no duplicate keys, so failures below come from the injected ones.
    @Test
    func fixturePassesDuplicateCheck() throws {
        try RegoValue.checkForDuplicateKeys(json: Self.fixture("policy-happy-path.json"))
    }

    @Test(arguments: [#""funcs":{"funcs":[]}"#, #""plans":{"plans":[]}"#])
    func rejectsDuplicateTopLevelKey(member: String) throws {
        let data = try Self.injectingTopLevelMember(member, into: Self.fixture("policy-happy-path.json"))
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try Policy(jsonData: data)
        }
    }

    // Malformed JSON still reports JSONDecoder's error, since decoding runs before the duplicate check.
    @Test
    func malformedPlanKeepsDecodingError() throws {
        let text = String(decoding: try Self.fixture("policy-happy-path.json"), as: UTF8.self)
        #expect(throws: DecodingError.self) {
            try Policy(jsonData: Data(text.dropLast(2).utf8))
        }
    }

    @Test
    func rejectsNestedDuplicateKey() throws {
        let text = String(decoding: try Self.fixture("policy-happy-path.json"), as: UTF8.self)
        // Duplicate the first statement's "row" field.
        let row = try #require(text.range(of: #""row": "#))
        let data = Data((String(text[..<row.lowerBound]) + #""row": 1, "# + String(text[row.lowerBound...])).utf8)
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try Policy(jsonData: data)
        }
    }
}
