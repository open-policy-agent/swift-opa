import AST
import Foundation
import Testing

@testable import IR

// JSONObject and the custom decoders are Darwin-only.
#if canImport(Darwin)

    // The custom JSONObject decoders must decode IR exactly as JSONDecoder does.
    @Suite
    struct JSONObjectIRTests {
        static var fixtures: [URL] {
            let dir = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
            return (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        }

        static var capabilitiesFiles: [URL] {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
            let bundles = root.appendingPathComponent("Tests/RegoTests/TestData/Bundles")
            return [
                root.appendingPathComponent("capabilities.json"),
                bundles.appendingPathComponent("full-capabilities-bundle/capabilities.json"),
                bundles.appendingPathComponent(
                    "simple-capabilities-bundle-default-builtins/capabilities/capabilities-passing.json"),
            ]
        }

        static func expectSameResult<T: Equatable>(
            _ data: Data, _ type: T.Type, _ label: String, decodable: (Data) throws -> T,
            custom: (Data) throws -> T
        ) {
            let expected = Result { try decodable(data) }
            let got = Result { try custom(data) }
            switch (expected, got) {
            case (.success(let e), .success(let g)):
                #expect(e == g, "\(label)")
            case (.failure, .failure):
                break
            default:
                Issue.record("\(label): JSONDecoder \(expected), JSONObject \(got)")
            }
        }

        @Test(arguments: fixtures)
        func policyDecodesLikeJSONDecoder(fixture: URL) throws {
            let data = try Data(contentsOf: fixture)
            Self.expectSameResult(
                data, Policy.self, fixture.lastPathComponent,
                decodable: { try JSONDecoder().decode(Policy.self, from: $0) },
                custom: { try Policy(json: JSONObject.parse($0)) })
        }

        @Test(arguments: capabilitiesFiles)
        func capabilitiesDecodeLikeJSONDecoder(file: URL) throws {
            let data = try Data(contentsOf: file)
            _ = try Capabilities(jsonData: data)
            Self.expectSameResult(
                data, Capabilities.self, file.lastPathComponent,
                decodable: { try JSONDecoder().decode(Capabilities.self, from: $0) },
                custom: { try Capabilities(jsonData: $0) })
        }

        // Replacement values tried at each mutated position. `nil` removes the member or element.
        nonisolated(unsafe) static let replacements: [Any?] = [
            nil, NSNull(), "x", 1.5, 2.0, -1, 4_294_967_296, true, [Any](), [String: Any](),
        ]

        // Applies each replacement at every position in the document, up to `limit` positions.
        static func mutations(of root: Any, limit: Int) -> [(String, Any)] {
            var out: [(String, Any)] = []
            var positions = 0
            func visit(_ node: Any, _ path: String, _ rebuild: @escaping (Any?) -> Any) {
                guard positions < limit else { return }
                positions += 1
                for r in replacements {
                    out.append(("\(path) = \(r.map { "\($0)" } ?? "<removed>")", rebuild(r)))
                }
                if let o = node as? [String: Any] {
                    for (k, v) in o.sorted(by: { $0.key < $1.key }) {
                        visit(v, "\(path).\(k)") { r in
                            var copy = o
                            copy[k] = r
                            return rebuild(copy)
                        }
                    }
                } else if let a = node as? [Any] {
                    for (i, v) in a.enumerated() {
                        visit(v, "\(path)[\(i)]") { r in
                            var copy = a
                            if let r { copy[i] = r } else { copy.remove(at: i) }
                            return rebuild(copy)
                        }
                    }
                }
            }
            visit(root, "$") { $0 ?? NSNull() }
            return out
        }

        @Test(arguments: fixtures)
        func mutatedPolicyDecodesLikeJSONDecoder(fixture: URL) throws {
            let root = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture))
            for (label, mutated) in Self.mutations(of: root, limit: 400) {
                let data = try JSONSerialization.data(withJSONObject: mutated, options: [.fragmentsAllowed])
                Self.expectSameResult(
                    data, Policy.self, "\(fixture.lastPathComponent) \(label)",
                    decodable: { try JSONDecoder().decode(Policy.self, from: $0) },
                    custom: { try Policy(json: JSONObject.parse($0)) })
            }
        }

        @Test
        func mutatedCapabilitiesDecodeLikeJSONDecoder() throws {
            let file = Self.capabilitiesFiles[2]
            let root = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
            for (label, mutated) in Self.mutations(of: root, limit: 400) {
                let data = try JSONSerialization.data(withJSONObject: mutated, options: [.fragmentsAllowed])
                Self.expectSameResult(
                    data, Capabilities.self, label,
                    decodable: { try JSONDecoder().decode(Capabilities.self, from: $0) },
                    custom: { try Capabilities(jsonData: $0) })
            }
        }

        @Test
        func errorsCarryCodingPaths() throws {
            let json =
                #"{"plans":{"plans":[{"name":"p","blocks":[{"stmts":[{"type":"MakeNullStmt","stmt":{"row":1,"col":1,"file":0,"target":"x"}}]}]}]}}"#
            #expect {
                try Policy(json: JSONObject.parse(Data(json.utf8)))
            } throws: { error in
                guard case DecodingError.typeMismatch(_, let c) = error else { return false }
                let path = c.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
                return path == ["plans", "plans", "0", "blocks", "0", "stmts", "0", "stmt", "target"]
            }
        }
    }

    extension URL: @retroactive CustomTestStringConvertible {
        public var testDescription: String { lastPathComponent }
    }

#endif
