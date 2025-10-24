import AST
import Foundation

extension BuiltinFuncs {
    // internal.member_2
    // memberOf is a membership check - memberOf(x: any, y: any) checks if y in x
    // For objects, we are checking the values, not the keys.
    static func isMemberOf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
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

    // internal.member_3
    // memberOfWithKey is a membership check with key:
    // memberOfWithKey(k: any, x: any, y: any) checks if y has property or index k and it is equal to x
    // For objects, we are checking the keys AND the values.
    static func isMemberOfWithKey(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        let key = args[0]
        let value = args[1]
        // See https://github.com/open-policy-agent/opa/blob/b942136a4ad049262fd72026421dac6bdd705059/v1/topdown/aggregates.go#L247
        let match = args[2][key]
        if match != nil {
            return .boolean(RegoValue.compare(value, match!) == .orderedSame)
        }
        return .boolean(false)
    }
}

extension RegoValue {
    /// Some RegoValues implement Get(key) interface. We will just implement it here as a subscript extension.
    /// See https://github.com/open-policy-agent/opa/blob/7ddaff2cc3dd749af25bab7d6a1f5a9cdbfe9833/v1/ast/term.go#L380
    fileprivate subscript(key: RegoValue) -> RegoValue? {
        switch self {
        case .object(let o):
            return o[key]
        case .array(let a):
            // key must be an integer position
            guard !key.isFloat, let index = key.integerValue else { return nil }
            // check bounds
            guard index >= 0 && index < a.count && index < Int32.max else { return nil }
            return a[Int(index)]
        case .set(let s):
            if s.contains(key) {
                return key
            }
            return nil
        default:
            return nil
        }
    }
}
