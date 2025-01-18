// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import IR

struct EvaluationContext {
    let query: String = ""
    let input: AST.RegoValue = AST.RegoValue.null
    let store: Store = NullStore()
    var results: ResultSet = ResultSet()
    var funcs: [String: IR.Func] = [:]  // indexed from the policy top-level funcs
    let staticStrings: [String] = []  // populate from the policy top-level static.strings
}

struct ResultSet {
    var results: [EvalResult] = []  // array of [String: RegoValue] dictionaries
}

typealias EvalResult = [String: AST.RegoValue]

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
