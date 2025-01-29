import AST
import Foundation

enum BuiltinFuncs {
    enum BuiltinError: Error {
        case argumentCountMismatch(got: Int, expected: Int)
        case argumentTypeMismatch(arg: String)
    }

    static func arrayConcat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array - the first array
        // y: array - the second array
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }
        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x")
        }
        guard case .array(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y")
        }

        return .array(x + y)
    }

    // memberOf is a membership check - memberOf(x: any, y: any) checks if y in x
    // For objects, we are checking the values, not the keys.
    static func isMemberOf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        switch args[1] {
        case .set(let set):
            return .boolean(set.contains(args[0]))
        case .array(let arr):
            return .boolean(arr.contains(args[0]))
        case .object(let obj):
            return .boolean(obj.values.contains(args[0]))
        default:
            return .boolean(false)
        }
    }

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
