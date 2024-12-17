// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.

struct EvaluationContext {
    let query: String = ""
    let input: ObjectType = ObjectType(staticProps: [])
    var results: ResultSet = ResultSet()
    var funcs: [String: Func] = [:]  // indexed from the policy top-level funcs
    let staticStrings: [String] = []  // populate from the policy top-level static.strings
}

struct ResultSet {
    var results: [[String: RegoValue]] = []  // array of [String: RegoValue] dictionaries
}

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
struct Frame {
    // TODO this needs to point back to the next block->statement after the callsite.
    let returnAddress: Int
    var locals: [Any]

}
