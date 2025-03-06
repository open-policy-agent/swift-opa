// Evaluator.swift - this file contains code related to evaluating an Rego IR Plan.
import AST
import Foundation
import IR

protocol Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet
}

/// EvaluationContext is the common evaluation context that is passed to the common Engine.
internal struct EvaluationContext {
    public let query: String
    public let input: AST.RegoValue
    public var store: OPA.Store
    public var builtins: BuiltinRegistry
    public var tracer: OPA.Trace.QueryTracer?
    public var strictBuiltins: Bool = false
    /// Time of Context creation since epoch, in nanoseconds
    public let timeNanos: UInt64

    init(
        query: String,
        input: AST.RegoValue,
        store: OPA.Store = NullStore(),
        builtins: BuiltinRegistry = .defaultRegistry,
        tracer: OPA.Trace.QueryTracer? = nil,
        strictBuiltins: Bool = false,
        timeNanos: UInt64? = nil
    ) {
        self.query = query
        self.input = input
        self.store = store
        self.builtins = builtins
        self.tracer = tracer
        self.strictBuiltins = strictBuiltins
        self.timeNanos = timeNanos ?? UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
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
