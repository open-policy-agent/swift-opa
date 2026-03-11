import AST
import Foundation
import IR

extension OPA.Engine {
    // The decoder used to decode the capabilities file
    static let capabilitiesDecoder = JSONDecoder()

    // checkBundlesForOverlap verifies whether a set of bundles is valid
    // together, in that there are no overlaps of their reserved roots
    // space within the logical data tree.
    // Throws a bundleConflictError if a conflict is detected.
    func checkBundlesForOverlap(bundleSet bundles: [String: OPA.Bundle]) throws {
        // Note(philip): The overlap check here is implemented with a
        // straightforward O(N^2) algorithm, same as OPA. In practice,
        // most bundles have few and shallow root path sets.
        var collidingBundles: Set<String> = []
        var conflictSet: Set<String> = []
        for (name, bundle) in bundles.sorted(by: { $0.key < $1.key }) {
            for (otherName, otherBundle) in bundles.sorted(by: { $0.key < $1.key }) {
                if name == otherName {
                    continue  // skip the current bundle.
                }

                for root in bundle.manifest.roots {
                    let rootPath = root.trimmingCharacters(in: ["/"])
                    for otherRoot in otherBundle.manifest.roots {
                        let otherRootPath = otherRoot.trimmingCharacters(in: ["/"])
                        guard OPA.Bundle.rootPathsOverlap(rootPath, otherRootPath) else {
                            continue  // skip non-overlapping paths.
                        }

                        // Record conflicting bundles and paths.
                        collidingBundles.insert(name)
                        collidingBundles.insert(otherName)

                        // Different message required if the roots are same
                        if rootPath == otherRootPath {
                            conflictSet.insert("root \(rootPath) is in multiple bundles")
                        } else {
                            let paths = [rootPath, otherRootPath].sorted()
                            conflictSet.insert("\(paths[0]) overlaps \(paths[1])")
                        }
                    }
                }
            }
        }

        guard collidingBundles.isEmpty && conflictSet.isEmpty else {
            throw RegoError(
                code: .bundleRootConflictError,
                message:
                    "detected overlapping roots in manifests for these bundles: [\(collidingBundles.sorted().joined(separator: ", "))] (\(conflictSet.sorted().joined(separator: ", ")))"
            )
        }
    }

    /// Verifies that all builtins referenced by the compiled policies are available both in the
    /// provided OPA capabilities and in the builtin registry.
    ///
    /// The method performs two checks:
    /// 1. If a `capabilities.json` is supplied, it ensures that all builtins required by the
    ///    policies are declared in the capabilities file, including their full signatures.
    /// 2. It validates that each required builtin name exists in the provided `builtins`
    ///    dictionary (default or custom). Signatures are not checked here—argument validation
    ///    occurs only at runtime inside the builtin implementation.
    ///
    /// - Parameters:
    ///   - capabilities: Optional input specifying the OPA capabilities to validate against.
    ///                   Can be a file path or an in-memory `Capabilities` object.
    ///   - builtins: A mapping of builtin names to their implementations available in Swift.
    ///   - evaluator: The intermediate representation (IR) evaluator containing the compiled policies.
    /// - Throws:
    ///   - `RegoError.capabilitiesMissingBuiltin` if the capabilities file does not list all
    ///     required builtins.
    ///   - `RegoError.builtinUndefinedError` if the builtin registry does not provide an
    ///     implementation for a required builtin.
    static func verifyCapabilitiesAndBuiltIns(
        capabilities: CapabilitiesInput?,
        builtins: [String: Builtin],
        evaluator: IREvaluator
    ) async throws {
        let capabilities: Capabilities? = try {
            switch capabilities {
            case .path(let url):
                let data: Data
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    throw RegoError(
                        code: .capabilitiesReadError,
                        message: "failed to read capabilities from \(url)",
                        cause: error
                    )
                }
                do {
                    return try Self.capabilitiesDecoder.decode(Capabilities.self, from: data)
                } catch {
                    throw RegoError(
                        code: .capabilitiesDecodeError,
                        message: "failed to decode capabilities from \(url)",
                        cause: error
                    )
                }
            case .data(let capabilities):
                return capabilities
            case .none:
                return nil
            }
        }()

        for policy in evaluator.policies.map(\.ir) {
            guard let requiredBuiltInsArray = policy.staticData?.builtinFuncs else {
                continue
            }

            // Check if all builtins required by the policy are present in the capabilities
            if let capabilities {
                let missingBuiltinsInCapabilities = Set(requiredBuiltInsArray).subtracting(Set(capabilities.builtins))
                if !missingBuiltinsInCapabilities.isEmpty {
                    throw RegoError(
                        code: .capabilitiesMissingBuiltin,
                        message: """
                            Missing the following builtins (required by the policies) in the capabilities.json: \
                            \(missingBuiltinsInCapabilities.description)
                            """
                    )
                }
            }

            // Check if all builtins required by the policy are present in the provided builtins
            // (default + custom builtins supplied at `OPA/Engine` init).
            //
            // We cannot actually verify a matching builtin signature here, since with the current setup
            // all builtins are defined as closures taking an arbitrary array of `AST.RegoValue`s.
            // The validity of the passed parameters can only be checked at runtime inside the builtin itself.
            // Therefore, we just check for matching builtin names.
            let missingBuiltins = Set(requiredBuiltInsArray.map { $0.name }).subtracting(Set(builtins.map(\.0)))
            if !missingBuiltins.isEmpty {
                throw RegoError(
                    code: .builtinUndefinedError,
                    message: """
                        Missing the following builtins (required by the policies) in the specified builtins (default or custom builtins): \
                        \(missingBuiltins.description)
                        """
                )
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
