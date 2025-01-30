import AST
import Foundation

extension BuiltinFuncs {
    // trace(note) allows for inserting events into the trace from a Rego policy.
    // The note must be a string.
    static func trace(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let msg) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "note")
        }

        if let tracer = ctx.tracer {
            tracer.traceEvent(
                BuiltinNoteEvent(
                    message: msg,
                    location: ctx.location
                ))
        }

        return AST.RegoValue.boolean(true)
    }
}
