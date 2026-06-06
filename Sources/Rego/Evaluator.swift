// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import Foundation

protocol Evaluator: Sendable {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
    /// Synchronous evaluation. `data` is the `/data` document, read synchronously by the caller.
    /// Throws `syncEvaluationUnsupported` if the query needs to suspend on an async builtin.
    func evaluateSync(withContext ctx: EvaluationContext, data: AST.RegoValue) throws -> ResultSet
}

/// EvaluationContext is the common evaluation context that is passed to the common Engine.
internal struct EvaluationContext {
    public let query: String
    public let input: AST.RegoValue
    public var store: OPA.Store
    public var builtins: BuiltinRegistry
    public var tracer: OPA.Trace.QueryTracer?
    public var strictBuiltins: Bool = false
    /// True if the policy references any async builtin; the async evaluator then runs the
    /// synchronous VM off the cooperative pool so blocking on those builtins is safe.
    public var hasAsyncBuiltins: Bool = false
    /// Date and Time of Context creation
    public let timestamp: Date
    /// Shared cache for builtin function calls
    public let builtinsCache: Ptr<BuiltinsCache>

    init(
        query: String,
        input: AST.RegoValue,
        store: OPA.Store = NullStore(),
        builtins: BuiltinRegistry = .defaultRegistry,
        tracer: OPA.Trace.QueryTracer? = nil,
        strictBuiltins: Bool = false,
        hasAsyncBuiltins: Bool = false,
        timestamp: Date? = nil
    ) {
        self.query = query
        self.input = input
        self.store = store
        self.builtins = builtins
        self.tracer = tracer
        self.strictBuiltins = strictBuiltins
        self.hasAsyncBuiltins = hasAsyncBuiltins
        self.timestamp = timestamp ?? Date()
        self.builtinsCache = Ptr<BuiltinsCache>(toCopyOf: BuiltinsCache())
    }
}

public typealias ResultSet = Set<EvalResult>

public typealias EvalResult = AST.RegoValue

extension ResultSet {
    /// An empty ResultSet
    public static var empty: ResultSet {
        return []
    }
}
