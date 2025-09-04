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
        builtins: [String : Builtin],
        evaluator: IREvaluator
    ) async throws {
        let capabilities: Capabilities? = switch capabilities {
        case .path(let url): try Self.capabilitiesDecoder.decode(Capabilities.self, from: Data(contentsOf: url))
        case .data(let capabilities): capabilities
        case .none: nil
        }

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

            // Check if all builtins required by the policy are present in default + custom builtins specified in the `customBuiltins` parameter.
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
