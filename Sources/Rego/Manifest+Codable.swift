import AST
import Foundation

extension OPA.Manifest: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.revision = try container.decodeIfPresent(String.self, forKey: .revision) ?? ""

        var roots = try container.decodeIfPresent([String].self, forKey: .roots) ?? [""]
        if roots.isEmpty {
            roots = [""]
        }
        self.roots = roots

        let regoVersionInt = try container.decodeIfPresent(Int.self, forKey: .regoVersion) ?? 1
        guard let version = Version(rawValue: regoVersionInt) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.regoVersion],
                    debugDescription: "Unsupported Rego version: \(regoVersionInt)"
                )
            )
        }
        self.regoVersion = version

        self.metadata = try container.decodeIfPresent(AST.RegoValue.self, forKey: .metadata) ?? .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(revision, forKey: .revision)
        try container.encode(roots, forKey: .roots)
        try container.encode(regoVersion.rawValue, forKey: .regoVersion)

        // omitempty: only encode metadata when non-null
        if metadata != .null {
            try container.encode(metadata, forKey: .metadata)
        }
    }
}

#if canImport(Darwin)
    extension OPA.Manifest {
        // Custom decoding from Darwin JSONSerialization output (see JSONObject). Must match init(from:).
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            let revision = try o.stringIfPresent("revision") ?? ""
            var roots = try o.arrayIfPresent("roots", JSONConvert.string) ?? [""]
            if roots.isEmpty {
                roots = [""]
            }
            let regoVersionInt: Int = try o.integerIfPresent("rego_version") ?? 1
            guard let version = Version(rawValue: regoVersionInt) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: [JSONKey("rego_version")],
                        debugDescription: "Unsupported Rego version: \(regoVersionInt)"))
            }
            let metadata = try o.decodeIfPresent("metadata", JSONConvert.regoValue) ?? .null
            self.init(revision: revision, roots: roots, regoVersion: version, metadata: metadata)
        }
    }
#endif
