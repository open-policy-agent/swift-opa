import AST
import Foundation
import Testing

@testable import IR

// Plans decode through custom decoders on Darwin and JSONDecoder elsewhere. Both paths need to reject duplicate
// keys, so we run each check through the platform's default path and through the JSONDecoder path.
enum PolicyDecodePath: String, CaseIterable, Sendable {
    case platformDefault, jsonDecoder

    func decode(_ data: Data) throws -> Policy {
        switch self {
        case .platformDefault: return try Policy(jsonData: data)
        case .jsonDecoder: return try RegoValue.decodeRejectingDuplicateKeys(Policy.self, json: data)
        }
    }
}

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
        _ = try RegoValue(jsonData: Self.fixture("policy-happy-path.json"))
    }

    @Test(arguments: [#""funcs":{"funcs":[]}"#, #""plans":{"plans":[]}"#], PolicyDecodePath.allCases)
    func rejectsDuplicateTopLevelKey(member: String, decodePath: PolicyDecodePath) throws {
        let data = try Self.injectingTopLevelMember(member, into: Self.fixture("policy-happy-path.json"))
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try decodePath.decode(data)
        }
    }

    // Malformed JSON still reports a DecodingError, since duplicates are reported only after parsing succeeds.
    @Test(arguments: PolicyDecodePath.allCases)
    func malformedPlanKeepsDecodingError(decodePath: PolicyDecodePath) throws {
        let text = String(decoding: try Self.fixture("policy-happy-path.json"), as: UTF8.self)
        #expect(throws: DecodingError.self) {
            try decodePath.decode(Data(text.dropLast(2).utf8))
        }
    }

    @Test(arguments: PolicyDecodePath.allCases)
    func rejectsNestedDuplicateKey(decodePath: PolicyDecodePath) throws {
        let text = String(decoding: try Self.fixture("policy-happy-path.json"), as: UTF8.self)
        // Duplicate the first statement's "row" field.
        let row = try #require(text.range(of: #""row": "#))
        let data = Data((String(text[..<row.lowerBound]) + #""row": 1, "# + String(text[row.lowerBound...])).utf8)
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try decodePath.decode(data)
        }
    }
}
