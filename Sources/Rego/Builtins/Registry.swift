import AST
import Foundation

typealias Builtin = (BuiltinContext, [AST.RegoValue]) async throws -> AST.RegoValue

public struct BuiltinContext {
    public let location: TraceLocation
    public var tracer: QueryTracer?

    init(location: TraceLocation = TraceLocation(), tracer: QueryTracer? = nil) {
        self.location = location
        self.tracer = tracer
    }
}

public struct BuiltinRegistry {
    var builtins: [String: Builtin]

    fileprivate static var defaultBuiltins: [String: Builtin] {
        return [
            // Aggregates
            "count": BuiltinFuncs.count,

            // Array
            "array.concat": BuiltinFuncs.arrayConcat,

            // Bits
            "bits.lsh": BuiltinFuncs.bitsShiftLeft,

            // Collections
            "internal.member_2": BuiltinFuncs.isMemberOf,

            // Comparison
            "gt": BuiltinFuncs.greaterThan,
            "gte": BuiltinFuncs.greaterThanEq,
            "lt": BuiltinFuncs.lessThan,
            "lte": BuiltinFuncs.lessThanEq,
            "neq": BuiltinFuncs.notEq,
            "equal": BuiltinFuncs.equal,

            // String
            "concat": BuiltinFuncs.concat,
            "contains": BuiltinFuncs.contains,
            "endswith": BuiltinFuncs.endsWith,
            "indexof": BuiltinFuncs.indexOf,
            "lower": BuiltinFuncs.lower,
            "upper": BuiltinFuncs.upper,

            // Trace
            "trace": BuiltinFuncs.trace,
        ]
    }

    func invoke(withCtx ctx: BuiltinContext, name: String, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard let builtin = builtins[name] else {
            throw RegistryError.builtinNotFound(name: name)
        }
        return try await builtin(ctx, args)
    }

    func hasBuiltin(_ name: String) -> Bool {
        return builtins[name] != nil
    }
}

// DefaultBuiltinRegistry is the BuiltinRegistry with all capabilities enabled
public var defaultBuiltinRegistry: BuiltinRegistry {
    BuiltinRegistry(
        builtins: BuiltinRegistry.defaultBuiltins
    )
}

extension BuiltinRegistry {
    enum RegistryError: Error {
        case builtinNotFound(name: String)
    }
}

public struct BuiltinNoteEvent: TraceableEvent {
    public var operation: TraceOperation = .note
    public var message: String
    public var location: TraceLocation
}
