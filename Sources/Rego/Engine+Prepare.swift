import AST
import Bytecode
import Foundation
import IR

extension OPA.Engine {
    // The decoder used to decode the capabilities file
    static let capabilitiesDecoder = JSONDecoder()

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
        builtins: [String: AnyBuiltin],
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

        for policy in evaluator.policies {
            let requiredBuiltInsArray = policy.builtinFuncs
            guard !requiredBuiltInsArray.isEmpty else {
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

    /// Rejects user-supplied IR policies whose plan names fall under any
    /// bundle's declared roots.
    ///
    /// ``IREvaluator`` ensures a bundle's plans must lie under its roots,
    /// and that plan-names are globally unique. Roots overlap between
    /// bundles is prevented by the bundle cache. This check prevents
    /// user IR policies from having plan names that overlap with any
    /// existing bundle roots.
    ///
    /// - Throws: `RegoError.planNameConflictError` listing every offending
    ///   user plan and the bundles whose roots claim it.
    static func checkUserPoliciesAgainstBundleRoots(
        userPolicies: [IR.Policy],
        bundles: [String: OPA.Bundle]
    ) throws {
        // Collect (bundleName, root) pairs.
        let bundleRoots: [(name: String, roots: [String])] =
            bundles
            .sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value.manifest.roots) }

        // planName -> sorted list of bundles whose roots claim it.
        var conflicts: [String: [String]] = [:]
        for (i, policy) in userPolicies.enumerated() {
            for plan in policy.plans?.plans ?? [] {
                for (bundleName, roots) in bundleRoots
                where OPA.Bundle.rootPathsContain(roots, plan.name) {
                    let key = "user:#\(i) '\(plan.name)'"
                    conflicts[key, default: []].append("bundle:\(bundleName)")
                }
            }
        }

        guard !conflicts.isEmpty else { return }

        let parts = conflicts.keys.sorted().map { key in
            let owners = conflicts[key]!.sorted()
            return "\(key) falls under roots of [\(owners.joined(separator: ", "))]"
        }
        throw RegoError(
            code: .planNameConflictError,
            message: "user IR policy plan names conflict with bundle roots: \(parts.joined(separator: "; "))"
        )
    }
}
