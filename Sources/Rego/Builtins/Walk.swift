import AST
import Foundation

extension BuiltinFuncs {

    // Note(philipc): We can't optimize the walk builtin for the
    // "path not used" cases, like what is done in upstream OPA, because
    // in the IR we don't get any information at the callsite about
    // wildcard/"don't care" values in the output array.
    static func walk(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard !args[0].isUndefined else {
            return .undefined
        }

        return try .array(walkRegoValueDFS(path: [], source: args[0]))
    }

    private static func walkRegoValueDFS(path: [RegoValue], source: AST.RegoValue) throws -> (
        [AST.RegoValue]
    ) {
        var result: [AST.RegoValue] = []

        // The * case for aggregate types.
        if source.isCollection {
            result.append([.array(path), source])
        }

        // For both Object and Set types, we have to walk their values in
        // sorted order to match OPA's behavior.
        switch source {
        case .array(let arr):
            for i in 0..<arr.count {
                let k: AST.RegoValue = .number(RegoNumber(value: Int64(i)))
                let v = arr[i] as AST.RegoValue
                try result.append(contentsOf: walkRegoValueDFS(path: path + [k], source: v))
            }
        case .object(let o):
            for (k, v) in o.sorted(by: { $0.key < $1.key }) {
                try result.append(contentsOf: walkRegoValueDFS(path: path + [k], source: v))
            }
        case .set(let set):
            for v in set.sorted(by: { $0 < $1 }) {
                try result.append(contentsOf: walkRegoValueDFS(path: path + [v], source: v))
            }
        default:
            result.append([.array(path), source])
        }

        return result
    }
}
