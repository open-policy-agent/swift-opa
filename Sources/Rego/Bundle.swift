import AST
import Foundation

extension OPA {
    /// A collection of policy and data, along with related metadata.
    ///
    /// See: https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format
    public struct Bundle: Hashable, Sendable {
        public var manifest: OPA.Manifest = OPA.Manifest()
        public var planFiles: [BundleFile] = []
        public var regoFiles: [BundleFile] = []
        public var data: AST.RegoValue = .object([:])

        // Internal - trie built from the manifest roots
        var rootsTrie: TrieNode
    }

    /// Metadata describing an ``OPA/Bundle``.
    public struct Manifest: Hashable, Sendable {
        /// The revision of the bundle.
        public var revision: String = ""
        /// The list of path prefixes declaring the scope of the data managed in the bundle.
        public var roots: [String] = [""]
        /// The version of Rego used in the bundle. Only ``Version/regoV1`` is supported.
        public var regoVersion: Version = .regoV1
        /// Additional structured metadata from the manifest.
        public var metadata: AST.RegoValue = .null

        /// Specifies a version of the Rego language.
        public enum Version: Int, Sendable {
            case regoV0 = 0
            case regoV1 = 1
        }

        public init(
            revision: String = "", roots: [String] = [""], regoVersion: Version = .regoV1,
            metadata: AST.RegoValue = .null
        ) {
            self.revision = revision
            self.roots = roots
            self.regoVersion = regoVersion
            self.metadata = metadata
        }
    }
}

extension OPA.Bundle {
    public init(
        manifest: OPA.Manifest = OPA.Manifest(), planFiles: [BundleFile] = [], regoFiles: [BundleFile] = [],
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

    public enum BundleError: Swift.Error {
        case overlappingRoots(String)
        case internalError(String)
    }
}

extension OPA.Manifest {
    /// Construct a manifest by parsing the provided JSON-encoded data.
    /// - Parameter jsonData: The JSON-encoded manifest data.
    public init(from jsonData: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: jsonData)
    }

    enum CodingKeys: String, CodingKey {
        case revision = "revision"
        case roots = "roots"
        case regoVersion = "rego_version"
        case metadata = "metadata"
    }
}

/// A descriptor pointing to an on-disk serialized ``OPA/Bundle``
public struct BundleFile: Sendable, Hashable {
    /// The path to an individual file within an ``OPA/Bundle``.
    public let url: URL  // relative to bundle root
    /// The raw file contents.
    public let data: Data

    public init(url: URL, data: Data) {
        self.url = url
        self.data = data
    }
}
