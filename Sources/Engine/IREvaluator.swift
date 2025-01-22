import Foundation
import IR

internal struct IREvaluator {
    private var policies: [IndexedIRPolicy] = []

    init(bundles: [String: Bundle]) async throws {
        for (bundleName, bundle) in bundles {
            try bundle.planFiles.forEach {
                do {
                    let parsed = try JSONDecoder().decode(IR.Policy.self, from: $0.data)
                    self.policies.append(IndexedIRPolicy(policy: parsed))
                } catch {
                    throw EvaluatorError.bundleInitializationFailed(
                        bundle: bundleName,
                        reason: "IR plan file '\($0.url)' parsing failed: \(error)"
                    )
                }
            }
        }
    }
}

extension IREvaluator: Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        // TODO: We're assuming that queries are only ever defined in a single policy... that _should_ hold true.. but who's checkin?
        for policy in policies {
            if let plan = policy.plans[ctx.query] {
                return try evalPlan(
                    withContext: IREvaluationContext(ctx: ctx, policy: policy), plan: plan)
            }
        }
        throw EvaluationError.unknownQuery(query: ctx.query)
    }
}

// Policy wraps an IR.Policy with some more optimized accessors for use in evaluations.
private struct IndexedIRPolicy {
    var ir: IR.Policy
    var plans: [String: IR.Plan] = [:]  // indexed from the policy top level plans by plan name (aka query name)
    var funcs: [String: IR.Func] = [:]  // indexed from the policy top-level funcs by function name
    var staticStrings: [String] = []  // populate from the policy top-level static.strings, indexes match original plan

    // On init() we'll pre-process some of the raw parsed IR.Policy to structure it in
    // more convienent (and optimized) structures to evaluate queries.
    init(policy: IR.Policy) {
        self.ir = policy
        for plan in policy.plans?.plans ?? [] {
            self.plans[plan.name] = plan  // TODO: is plan.name actually the right string format to match a query string? If no, convert it here.
        }
        for funcDecl in policy.funcs?.funcs ?? [] {
            self.funcs[funcDecl.name] = funcDecl
        }
        self.ir.staticData?.strings?.forEach { self.staticStrings.append($0.value) }
    }
}

private struct IREvaluationContext {
    var ctx: EvaluationContext
    var policy: IndexedIRPolicy

    var results: ResultSet = ResultSet()  // TODO: do we need/want to track results on this context?

    init(ctx: EvaluationContext, policy: IndexedIRPolicy) {
        self.ctx = ctx
        self.policy = policy
    }
}

private struct Locals {
    var locals: [Int: Any]
}

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
private struct Frame {
    // TODO this needs to point back to the next block->statement after the callsite.
    let returnAddress: Int
    var locals: Locals  // Superset of frame locals
    var scopeLocals: [Locals]  // Stack of locals per-scope
}

// Evaluate an IR Plan from start to finish for the given IREvaluationContext
private func evalPlan(withContext ctx: IREvaluationContext, plan: IR.Plan) throws -> ResultSet {

    // TODO: Initialize the starting Frame and begin processing the first block of the plan

    if Task.isCancelled {
        // TODO: What should we do on cancel? Is raising an error the right thing?
        throw EvaluationError.evaluationCancelled(reason: "parent task cancelled")
    }

    return ResultSet()
}
