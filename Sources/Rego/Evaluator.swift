// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import IR

protocol Evaluator: Sendable {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
}

/// EvaluationContext is the common evaluation context that is passed to the common Engine.
internal struct EvaluationContext {
    public let query: String
    public let input: AST.RegoValue
    public var store: OPA.Store
    public var builtins: BuiltinRegistry
    public var tracer: OPA.Trace.QueryTracer?
    /// Per-evaluation builtin cache.
    ///
    /// Shared by all builtin invocations within a single top-down policy evaluation.
    public let cache: BuiltinsCache
    public var strictBuiltins: Bool = false

    init(
        query: String,
        input: AST.RegoValue,
        store: OPA.Store = NullStore(),
        builtins: BuiltinRegistry = .defaultRegistry,
        tracer: OPA.Trace.QueryTracer? = nil,
        cache: BuiltinsCache = .init(),
        strictBuiltins: Bool = false
    ) {
        self.query = query
        self.input = input
        self.store = store
        self.builtins = builtins
        self.tracer = tracer
        self.cache = cache
        self.strictBuiltins = strictBuiltins
    }
}

public typealias ResultSet = Set<EvalResult>

public typealias EvalResult = AST.RegoValue

extension ResultSet {
    /// An empty ResultSet
    public static var empty: ResultSet {
        return []
    }

    /// Constructs a ResultSet containing a single value.
    public init(value: AST.RegoValue) {
        self = [value]
    }
}
