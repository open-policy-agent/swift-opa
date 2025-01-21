import IR

struct IREvaluator {
    var ctx: IREvaluationContext
}

struct IREvaluationContext {
    var ctx: EvaluationContext

    let policies: [IR.Policy]
    var funcs: [String: IR.Func] = [:]  // indexed from the policy top-level funcs
    let staticStrings: [String] = []  // populate from the policy top-level static.strings
}

struct Locals {
    var locals: [Int: Any]
}

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
struct Frame {
    // TODO this needs to point back to the next block->statement after the callsite.
    let returnAddress: Int
    var locals: Locals  // Superset of frame locals
    var scopeLocals: [Locals]  // Stack of locals per-scope
}
