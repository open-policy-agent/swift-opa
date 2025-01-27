// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import IR

protocol Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
}

public enum EvaluatorError: Error, Equatable {
    case bundleInitializationFailed(bundle: String, reason: String)
}

public enum EvaluationError: Error, Equatable {
    case unknownQuery(query: String)
    case evaluationCancelled(reason: String)
    case internalError(reason: String)
    case invalidDataType(reason: String)
    case invalidOperand(reason: String)
    case assignOnceError(reason: String)
}

// EvaluationContext is the common evaluation context that is passed to the common Engine.
public struct EvaluationContext {
    public let query: String
    public let input: AST.RegoValue
    public let store: Store = NullStore()
}

typealias ResultSet = Set<EvalResult>

typealias EvalResult = [String: AST.RegoValue]
