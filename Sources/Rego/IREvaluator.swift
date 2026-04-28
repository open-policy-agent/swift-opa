import AST
import Bytecode
import Foundation
import IR

internal struct IREvaluator {
    let policies: [Bytecode.Policy]

    init(
        bundles: [String: OPA.Bundle],
        builtinRegistry: BuiltinRegistry = .defaultRegistry,
        optimizeAsync: Bool = true
    ) throws {
        var policies: [Bytecode.Policy] = []
        for (bundleName, bundle) in bundles {
            for planFile in bundle.planFiles {
                do {
                    var parsed = try IR.Policy(jsonData: planFile.data)
                    try parsed.prepareForExecution()
                    let converted = try Converter.convert(parsed)
                    policies.append(
                        optimizeAsync
                            ? SyncSafePatcher.patch(policy: converted, builtins: builtinRegistry)
                            : converted
                    )
                } catch {
                    throw RegoError(
                        code: .bundleInitializationError,
                        message: """
                            initialization failed for bundle \(bundleName), \
                            parsing failed in file: \(planFile.url)
                            """,
                        cause: error
                    )
                }
            }
        }
        guard !policies.isEmpty else {
            throw RegoError(code: .noPlansFoundError, message: "no IR plans were found in any of the provided bundles")
        }
        self.policies = policies
    }

    // Initialize directly with parsed policies - useful for testing
    init(
        policies: [IR.Policy],
        builtinRegistry: BuiltinRegistry = .defaultRegistry,
        optimizeAsync: Bool = true
    ) throws {
        self.policies = try policies.map {
            var p = $0
            try p.prepareForExecution()
            let converted = try Converter.convert(p)
            return optimizeAsync
                ? SyncSafePatcher.patch(policy: converted, builtins: builtinRegistry)
                : converted
        }
    }
}

extension IREvaluator: Evaluator {
    @sync
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        // TODO: We're assuming that queries are only ever defined in a single policy... that _should_ hold true.. but who's checkin?
        let entrypoint = try queryToEntryPoint(ctx.query)
        for policy in policies {
            if let planIndex = policy.plans.firstIndex(where: { $0.name == entrypoint }) {
                let vm = VM(policy: policy)
                guard policy.plans[planIndex].syncSafe else {
                    return try await vm.executePlan(withContext: ctx, planIndex: planIndex)
                }
                return try vm.executePlanSync(withContext: ctx, planIndex: planIndex)
            }
        }
        throw RegoError(code: .unknownQuery, message: "query not found in plan: \(ctx.query)")
    }
}

func queryToEntryPoint(_ query: String) throws -> String {
    let prefix = "data"
    guard query.hasPrefix(prefix) else {
        throw RegoError(code: .unsupportedQuery, message: "unsupported query: \(query), must start with 'data'")
    }
    if query == prefix {
        // done!
        return query
    }
    return query.dropFirst(prefix.count + 1).replacingOccurrences(of: ".", with: "/")
}
