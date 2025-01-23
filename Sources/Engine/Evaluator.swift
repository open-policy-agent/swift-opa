// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import IR

protocol Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
}

public enum EvaluatorError: Error {
    case bundleInitializationFailed(bundle: String, reason: String)
}

public enum EvaluationError: Error {
    case unknownQuery(query: String)
    case evaluationCancelled(reason: String)
    case internalError(reason: String)
}

// EvaluationContext is the common evaluation context that is passed to the common Engine.
struct EvaluationContext {
    let query: String = ""
    let input: AST.RegoValue = AST.RegoValue.null
    let store: Store = NullStore()
    var results: ResultSet = ResultSet()
}

typealias ResultSet = Set<EvalResult>

typealias EvalResult = [String: AST.RegoValue]
