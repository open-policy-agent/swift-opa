// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import IR

protocol Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
}

public enum EvaluationError: Error {
    case unknownQuery(query: String)
}

// EvaluationContext is the common evaluation context that is passed to the common Engine.
struct EvaluationContext {
    let query: String = ""
    let input: AST.RegoValue = AST.RegoValue.null
    let store: Store = NullStore()
    var results: ResultSet = ResultSet()
}

struct ResultSet {
    var results: [EvalResult] = []  // array of [String: RegoValue] dictionaries
}

typealias EvalResult = [String: AST.RegoValue]
