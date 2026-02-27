import AST
import Foundation

extension OPA {
    /// A collection of policy and data, along with related metadata.
    ///
    /// See: https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format
    public struct Bundle: Hashable, Sendable {
        public var manifest: OPA.Manifest
        public var planFiles: [BundleFile]
        public var regoFiles: [BundleFile]
        public var data: AST.RegoValue

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
                throw .internalError("no roots in manifest")
            }
        }

        // validate runs integrity checks on the bundle, such as
        // verifying that all data is contained under the bundle roots.
        // Because this can be an expensive check, it is not done at
        // init time.
        public func validate() throws(BundleError) {
            try OPA.Bundle.checkDataCoveredByRoots(data: self.data, roots: self.manifest.roots)
        }
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
    public enum BundleError: Swift.Error {
        case overlappingRoots(String)
        case dataEscapedRoots(String)
        case internalError(String)
    }

    /// A simple trie node used for validating that data is covered by roots.
    /// A node is `isRoot == true` when a declared root path ends here, meaning
    /// everything below this point in the data tree is covered.
    fileprivate final class RootTrieNode {
        var children: [String: RootTrieNode] = [:]
        var isRoot: Bool = false
    }

    /// Verify that every path in `data` is covered by one of `roots`.
    ///
    /// A root like `"/a/b"` covers the data at `data.a.b` and anything beneath it.
    /// An empty root (`""` or `"/"`) covers the entire data tree.
    ///
    /// Throws `BundleError.dataOutsideBundleRoots` at the first uncovered path found.
    /// Non-object values encountered mid-path (before reaching a root terminator)
    /// are considered uncovered, since roots describe object key paths.
    static func checkDataCoveredByRoots(
        data: AST.RegoValue,
        roots: [String]
    ) throws(BundleError) {
        // Build the trie of roots.
        let trieRoot = RootTrieNode()
        for raw in roots {
            let trimmed = raw.trimmingCharacters(in: ["/"])
            if trimmed.isEmpty {
                // "" or "/" covers everything; nothing left to check.
                return
            }
            var node = trieRoot
            for segment in trimmed.split(separator: "/", omittingEmptySubsequences: true) {
                let key = String(segment)
                if let next = node.children[key] {
                    node = next
                } else {
                    let next = RootTrieNode()
                    node.children[key] = next
                    node = next
                }
            }
            node.isRoot = true
        }

        guard case .object(let topLevel) = data else {
            // Non-object top-level data requires a "" root (handled above).
            // Treat anything else as covered to avoid false positives on null/etc.
            return
        }

        // DFS via an explicit stack. Each frame holds the parent segment that
        // led to it, plus an iterator over the remaining (key, value) pairs.
        // On error we walk the stack to reconstruct the full path; on the
        // happy path we never allocate a path string.
        struct Frame {
            let segment: String  // segment from parent to reach this object ("" at root)
            let node: RootTrieNode
            var iterator: Dictionary<AST.RegoValue, AST.RegoValue>.Iterator
        }

        // Build a full "/a/b/c" path from the current stack plus an optional
        // failing leaf segment. Only invoked on the error path.
        func buildPath(stack: [Frame], leaf: String?) -> String {
            var out = ""
            for frame in stack where !frame.segment.isEmpty {
                out += "/" + frame.segment
            }
            if let leaf {
                out += "/" + leaf
            }
            return out.isEmpty ? "/" : out
        }

        var stack: [Frame] = [
            Frame(segment: "", node: trieRoot, iterator: topLevel.makeIterator())
        ]

        while !stack.isEmpty {
            // Mutate the top frame's iterator in place.
            let topIndex = stack.count - 1
            guard let (k, v) = stack[topIndex].iterator.next() else {
                stack.removeLast()
                continue
            }

            // Root paths are string-keyed; non-string keys can't be covered.
            guard case .string(let keyStr) = k else {
                throw .dataEscapedRoots(
                    "data path \(buildPath(stack: stack, leaf: "<non-string key>")) is not covered by any root")
            }

            guard let childNode = stack[topIndex].node.children[keyStr] else {
                throw .dataEscapedRoots(
                    "data path \(buildPath(stack: stack, leaf: keyStr)) is not covered by any root")
            }

            // Root terminator => everything below is covered, no need to descend.
            if childNode.isRoot {
                continue
            }

            // Must descend further; only objects can continue matching the trie.
            switch v {
            case .object(let childObj):
                stack.append(
                    Frame(segment: keyStr, node: childNode, iterator: childObj.makeIterator()))
            default:
                throw .dataEscapedRoots(
                    "data path \(buildPath(stack: stack, leaf: keyStr)) is not covered by any root")
            }
        }
    }

    /// checkBundlesForOverlap verifies whether a set of bundles is valid
    /// together, in that there are no overlaps of their reserved roots
    /// space within the logical data tree.
    ///
    /// The original algorithm used O(N^2) comparisons, the new algorithm
    /// runs in O(N log N) for success cases, and O(N log (N+K)) in the worst
    /// case.
    ///
    /// Inuition: We sort all paths lexicographically, then scan forward for
    /// prefix matches. Prefix matches == collisions. This works because
    /// shorter path prefixes will always be sorted ahead of any colliding
    /// longer paths.
    ///
    /// We use one loop to scan for exact matches. This forms a group of known
    /// conflicting paths. We then scan forward from that group until we hit
    /// a path which does not have our root path as the prefix. We then generate
    /// the conflict sets for all of the paths in the group against each other,
    /// and then against any conflicting longer paths.
    ///
    /// Throws a bundleConflictError if a conflict is detected.
    public static func checkBundlesForOverlap(bundleSet bundles: [String: OPA.Bundle]) throws {
        // Trim slashes for display, then add leading/trailing "/" so byte-prefix comparison
        // matches segment-prefix semantics. e.g. canonical "/a/b/" is a prefix
        // of "/a/b/c/" but not of "/a/bc/".
        struct Entry {
            let bundle: String
            let canonical: String

            init(bundle: String, rawRoot: String) {
                let trimmed = rawRoot.trimmingCharacters(in: ["/"])
                self.bundle = bundle
                self.canonical = (trimmed.isEmpty) ? "/" : "/" + trimmed + "/"
            }

            /// The trimmed root for error messages.
            var displayRoot: String {
                String(canonical.trimmingCharacters(in: ["/"]))
            }
        }

        let entries: [Entry] =
            bundles.flatMap { name, bundle in
                bundle.manifest.roots.map { Entry(bundle: name, rawRoot: $0) }
            }.sorted { $0.canonical < $1.canonical }

        var collidingBundles: Set<String> = []
        var conflictSet: Set<String> = []

        var groupStart = 0
        while groupStart < entries.count {
            // Identify the group of entries sharing the
            // exact same canonical root.
            var groupEnd = groupStart + 1
            while groupEnd < entries.count, entries[groupEnd].canonical == entries[groupStart].canonical {
                groupEnd += 1
            }

            let group = entries[groupStart..<groupEnd]

            // Same-root conflicts within the group (only across different bundles).
            let groupBundleNames = Set(group.map(\.bundle))
            if groupBundleNames.count > 1 {
                collidingBundles.formUnion(groupBundleNames)
                conflictSet.insert("root \(group[groupStart].displayRoot) is in multiple bundles")
            }

            // Descendant conflicts: forward scan while the group's canonical
            // root is a prefix of the next entry's canonical root.
            let groupCanonical = group[groupStart].canonical
            let groupDisplay = group[groupStart].displayRoot

            for descendant in entries[groupEnd...] {
                // Break if next entry isn't a conflict.
                guard descendant.canonical.hasPrefix(groupCanonical) else { break }

                // Pair the descendant against every group entry from a different bundle.
                var sawCrossBundleConflict = false
                for ancestor in group {
                    guard ancestor.bundle != descendant.bundle else { continue }
                    collidingBundles.insert(ancestor.bundle)
                    sawCrossBundleConflict = true
                }

                // Only record a conflict if the descendant overlaps with an
                // ancestor declared by a different bundle. A single bundle
                // is allowed to declare overlapping roots in its own manifest.
                guard sawCrossBundleConflict else { continue }

                collidingBundles.insert(descendant.bundle)

                let pair = [groupDisplay, descendant.displayRoot].sorted()
                conflictSet.insert("\(pair[0]) overlaps \(pair[1])")
            }

            groupStart = groupEnd
        }

        guard collidingBundles.isEmpty && conflictSet.isEmpty else {
            throw RegoError(
                code: .bundleRootConflictError,
                message: "detected overlapping roots in manifests for these bundles: "
                    + "[\(collidingBundles.sorted().joined(separator: ", "))] "
                    + "(\(conflictSet.sorted().joined(separator: ", ")))"
            )
        }
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
