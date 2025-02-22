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
    case unsupportedQuery(query: String)
    case unknownQuery(query: String)
    case evaluationCancelled(reason: String)
    case internalError(reason: String)
    case invalidDataType(reason: String)
    case invalidOperand(reason: String)
    case assignOnceError(reason: String)
    case objectInsertOnceError(reason: String)
    case unknownDynamicFunction(name: String)
    case maxCallDepthExceeded(depth: Int)
}

// EvaluationContext is the common evaluation context that is passed to the common Engine.
public struct EvaluationContext {
    public let query: String
    public let input: AST.RegoValue
    public var store: Store
    public var builtins: BuiltinRegistry
    public var tracer: QueryTracer?
    public var strictBuiltins: Bool = false

    init(
        query: String,
        input: AST.RegoValue,
        store: Store = NullStore(),
        builtins: BuiltinRegistry = defaultBuiltinRegistry,
        tracer: QueryTracer? = nil,
        strictBuiltins: Bool = false
    ) {
        self.query = query
        self.input = input
        self.store = store
        self.builtins = builtins
        self.tracer = tracer
        self.strictBuiltins = strictBuiltins
    }
}

public typealias ResultSet = Set<EvalResult>

public typealias EvalResult = AST.RegoValue

extension ResultSet {
    public static var empty: ResultSet {
        return []
    }

    public init(value: AST.RegoValue) {
        self = [value]
    }
}
