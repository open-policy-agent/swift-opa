import AST
import Foundation

public struct Bundle: Equatable, Sendable {
    public var manifest: Manifest = Manifest()
    public var planFiles: [BundleFile] = []
    public var regoFiles: [BundleFile] = []
    public var data: AST.RegoValue = .object([:])

    // Internal - trie built from the manifest roots
    var rootsTrie: TrieNode

    init(
        manifest: Manifest = Manifest(), planFiles: [BundleFile] = [], regoFiles: [BundleFile] = [],
        data: AST.RegoValue = .object([:])
    ) throws(BundleError) {
        self.manifest = manifest
        self.planFiles = planFiles
        self.regoFiles = regoFiles
        self.data = data

        guard !manifest.roots.isEmpty else {
            // Expect [""], not [] when roots were undefined.
            // We rely on that below to enter the loop and
            // set the isLeaf on the trie accordingly.
            throw .internalError("no roots in manifest")
        }

        let trieRoot = TrieNode(value: "data", isLeaf: false, children: [:])
        let trie: TrieNode = try mergeTrie(trieRoot, withBundleRoots: manifest.roots)
        self.rootsTrie = trie
    }

    enum BundleError: Error {
        case overlappingRoots(String)
        case internalError(String)
    }
}

public struct Manifest: Equatable, Sendable {
    public var revision: String = ""
    public var roots: [String] = [""]
    public var regoVersion: Version = .regoV1
    public var metadata: AST.RegoValue = .null

    public enum Version: Int, Sendable {
        case regoV0 = 0
        case regoV1 = 1
    }
}

extension Manifest {
    public init(from jsonData: Data) throws {
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let jsonDict = jsonObject as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON format"))
        }

        let revision = jsonDict["revision"] as? String ?? ""
        self.revision = revision

        var roots = jsonDict["roots"] as? [String] ?? [""]
        if roots.isEmpty {
            roots = [""]
        }
        self.roots = roots

        let regoVersionInt = jsonDict["rego_version"] as? Int ?? 1
        self.regoVersion =
            switch regoVersionInt {
            case 0:
                .regoV0
            case 1:
                .regoV1
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [], debugDescription: "Unsupported Rego version"))
            }

        guard let metadataAny = jsonDict["metadata"] else {
            // No metadata, use default
            self.metadata = .null
            return
        }

        // Parse metadata
        let metadataValue = try AST.RegoValue(from: metadataAny)
        self.metadata = metadataValue
    }

    public enum CodingKeys: String, CodingKey {
        case revision = "revision"
        case roots = "roots"
        case regoVersion = "rego_version"
        case metadata = "metadata"
    }
}

public struct BundleFile: Sendable, Hashable {
    public let url: URL  // relative to bundle root
    public let data: Data
}
