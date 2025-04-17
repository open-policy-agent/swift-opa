import AST
import Foundation
import IR

extension OPA.Engine {
    // checkBundlesForOverlap verifies whether a set of bundles is valid
    // together, in that there are no overlaps of their reserved roots
    // space within the logical data tree.
    // Throws a bundleConflictError if a conflict is detected.
    func checkBundlesForOverlap(bundleSet bundles: [String: OPA.Bundle]) throws {
        // Patch all the bundle data into the data tree on the store
        var allRoots = TrieNode(value: "data", isLeaf: false, children: [:])
        for (name, bundle) in bundles {
            // Perform cross-bundle root overlap check
            do {
                allRoots = try mergeTrie(allRoots, withBundleRoots: bundle.manifest.roots)
            } catch OPA.Bundle.BundleError.overlappingRoots {
                throw RegoError(
                    code: .bundleRootConflictError,
                    message: "bundle \(name) overlaps with existing bundle roots"
                )
            } catch OPA.Bundle.BundleError.internalError(let msg) {
                throw RegoError(code: .internalError, message: msg)
            }
        }
    }
}

// mergeTrie is a helper to merge an existing trie with the roots defined from a bundle.
// Roots are '/' delimited paths representing a logical part of the data tree,
// e.g. 'app/rbac' or 'user_roles'.
// Throws BundleError.overlappingRoots if the bundle overlaps with paths already
// captured in the trie.
func mergeTrie(_ trie: TrieNode, withBundleRoots roots: [String]) throws(OPA.Bundle.BundleError) -> TrieNode {
    guard !roots.isEmpty else {
        // Expect [""], not [] when roots were undefined.
        // We rely on that below to enter the loop and
        // set the isLeaf on the trie accordingly.
        throw .internalError("no roots in manifest")
    }

    var trie = trie
    for root in roots {
        let rootPath = root.split(separator: "/").map { String($0) }
        // If rootPath is empty (say empty string root yielded no splits),
        // merging will return a "terminal" trie (isLeaf==true) - which will
        // contain any data tree if we ask contains(dataTree:)
        let (merged, conflict) = TrieNode.merge(node: trie, withSegments: rootPath[...])
        trie = merged

        guard !conflict else {
            throw .overlappingRoots(root)
        }
    }

    return trie
}
