import AST
import Bytecode
import Foundation
import IR

extension OPA.Engine {
    // The decoder used to decode the capabilities file
    static let capabilitiesDecoder = JSONDecoder()

    /// Returns the capabilities described by `input`, reading and decoding a file if needed.
    static func resolveCapabilities(_ input: CapabilitiesInput?) throws -> Capabilities? {
        switch input {
        case .path(let url):
            return try loadCapabilities(from: url)
        case .data(let capabilities):
            return capabilities
        case .none:
            return nil
        }
    }

    /// Reads and decodes a `capabilities.json` file.
    static func loadCapabilities(from url: URL) throws -> Capabilities {
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
    }

    /// Verifies that all builtins referenced by the compiled policies are available both in the
    /// provided OPA capabilities and in the builtin registry.
    ///
    /// The method performs two checks:
    /// 1. If capabilities are supplied, it ensures that all builtins required by the
    ///    policies are declared in the capabilities, including their full signatures.
    /// 2. It validates that each required builtin name exists in the provided `builtins`
    ///    dictionary (default or custom). Signatures are not checked here—argument validation
    ///    occurs only at runtime inside the builtin implementation.
    ///
    /// - Parameters:
    ///   - capabilities: Optional OPA capabilities to validate against.
    ///   - builtins: A mapping of builtin names to their implementations available in Swift.
    ///   - evaluator: The intermediate representation (IR) evaluator containing the compiled policies.
    /// - Throws:
    ///   - `RegoError.capabilitiesMissingBuiltin` if the capabilities do not list all
    ///     required builtins.
    ///   - `RegoError.builtinUndefinedError` if the builtin registry does not provide an
    ///     implementation for a required builtin.
    static func verifyCapabilitiesAndBuiltIns(
        capabilities: Capabilities?,
        builtins: BuiltinRegistry,
        evaluator: IREvaluator
    ) throws {
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
            let missingBuiltins = Set(requiredBuiltInsArray.map { $0.name }).subtracting(builtins.names)
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

    /// Rejects user-supplied IR policies whose plan names overlap with any
    /// bundle's declared roots.
    ///
    /// ``IREvaluator`` ensures a bundle's plans must lie under its roots,
    /// and that plan names are globally unique. Root overlap between
    /// bundles is prevented by the bundle cache. This check prevents
    /// user IR policies from having plan names under or above any
    /// existing bundle roots.
    ///
    /// - Throws: `RegoError.planNameConflictError` listing every offending
    ///   user plan and the bundles whose roots claim it.
    static func checkUserPoliciesAgainstBundleRoots(
        userPolicies: [IR.Policy],
        bundles: [String: OPA.Bundle]
    ) throws {
        var planNames: [String] = []
        var policyIndices: [Int] = []
        for (i, policy) in userPolicies.enumerated() {
            for plan in policy.plans?.plans ?? [] {
                planNames.append(plan.name)
                policyIndices.append(i)
            }
        }
        try checkUserPlans(planNames, againstBundleRoots: bundles.mapValues(\.manifest.roots)) { i in
            "user:#\(policyIndices[i]) '\(planNames[i])'"
        }
    }

    /// Rejects user plans whose names are under or above any of `bundleRoots`,
    /// which are keyed by bundle name. `label` names the plan at an index of `planNames` in the error.
    static func checkUserPlans(
        _ planNames: [String],
        againstBundleRoots bundleRoots: [String: [String]],
        label: (Int) -> String
    ) throws {
        // plan label -> list of bundles whose roots claim it.
        var conflicts: [String: [String]] = [:]
        for (i, planName) in planNames.enumerated() {
            for (bundleName, roots) in bundleRoots
            where roots.contains(where: { OPA.Bundle.pathsOverlap($0, planName) }) {
                conflicts[label(i), default: []].append("bundle:\(bundleName)")
            }
        }

        guard !conflicts.isEmpty else { return }

        let parts = conflicts.keys.sorted().map { key in
            let owners = conflicts[key]!.sorted()
            return "\(key) overlaps roots of [\(owners.joined(separator: ", "))]"
        }
        throw RegoError(
            code: .planNameConflictError,
            message: "user IR policy plan names conflict with bundle roots: \(parts.joined(separator: "; "))"
        )
    }
}
