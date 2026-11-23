import AST
import Foundation
import Testing

@testable import Rego

// Manifests decode through custom decoders on Darwin and JSONDecoder elsewhere. Both paths need to reject duplicate
// keys, so we run each check through both.
enum ManifestDecodePath: String, CaseIterable, Sendable {
    case platformDefault, jsonDecoder

    func decode(_ data: Data) throws -> OPA.Manifest {
        switch self {
        case .platformDefault: return try OPA.Manifest(from: data)
        case .jsonDecoder: return try RegoValue.decodeRejectingDuplicateKeys(OPA.Manifest.self, json: data)
        }
    }
}

// Duplicate keys are rejected in every JSON file Swift OPA decodes into typed structs.
@Suite
struct JSONDuplicateKeyLoadingTests {
    @Test(
        arguments: [
            #"{"roots":["x"],"roots":[""]}"#,
            #"{"revision":"a","revision":"b"}"#,
            #"{"metadata":{"name":"a","name":"b"}}"#,
        ], ManifestDecodePath.allCases)
    func manifestRejectsDuplicateKeys(json: String, decodePath: ManifestDecodePath) {
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try decodePath.decode(Data(json.utf8))
        }
    }

    @Test
    func manifestWithoutDuplicatesStillDecodes() throws {
        let manifest = try OPA.Manifest(from: Data(#"{"roots":["x","y"],"revision":"r1"}"#.utf8))
        #expect(manifest.roots == ["x", "y"])
        #expect(manifest.revision == "r1")
    }

    @Test
    func bundleLoadRejectsManifestWithDuplicateRoots() throws {
        let base = URL(fileURLWithPath: "/bundle/", isDirectory: true)
        let files: [Result<BundleFile, any Error>] = [
            .success(
                BundleFile(
                    url: URL(string: ".manifest", relativeTo: base)!,
                    data: Data(#"{"roots":["x"],"roots":[""]}"#.utf8)
                ))
        ]
        let error = try #require(throws: BundleLoader.LoadError.self) {
            try BundleLoader(fromFileSequence: files).load()
        }
        guard case .manifestParseError(let url, let cause) = error else {
            Issue.record("expected manifestParseError, got \(error)")
            return
        }
        #expect(url.relativePath == ".manifest")
        #expect(cause as? RegoValue.JSONInputError == .duplicateObjectKeys)
    }

    // Malformed JSON still reports a DecodingError, since duplicates are reported only after parsing succeeds.
    @Test(arguments: ManifestDecodePath.allCases)
    func malformedManifestKeepsDecodingError(decodePath: ManifestDecodePath) {
        #expect(throws: DecodingError.self) {
            try decodePath.decode(Data(#"{"roots":["x"],"#.utf8))
        }
    }

    @Test
    func malformedCapabilitiesKeepDecodingError() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("malformed-capabilities-\(UUID().uuidString).json")
        try Data(#"{"builtins":["#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let error = try #require(throws: RegoError.self) {
            try OPA.Engine.loadCapabilities(from: url)
        }
        #expect(error.code == .capabilitiesDecodeError)
        #expect(error.cause is DecodingError)
    }

    @Test
    func capabilitiesRejectDuplicateKeys() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dup-capabilities-\(UUID().uuidString).json")
        try Data(#"{"builtins":[],"builtins":[]}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let error = try #require(throws: RegoError.self) {
            try OPA.Engine.loadCapabilities(from: url)
        }
        #expect(error.code == .capabilitiesDecodeError)
        #expect(error.cause as? RegoValue.JSONInputError == .duplicateObjectKeys)
    }

    @Test
    func capabilitiesWithoutDuplicatesStillDecode() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("capabilities-\(UUID().uuidString).json")
        try Data(#"{"builtins":[],"features":["a"]}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let capabilities = try OPA.Engine.loadCapabilities(from: url)
        #expect(capabilities.builtins.isEmpty)
        #expect(capabilities.features == ["a"])
    }
}
