import AST
import Foundation

typealias Builtin = ([AST.RegoValue]) async throws -> AST.RegoValue
public struct BuiltinRegistry {
    var builtins: [String: Builtin]

    fileprivate static var defaultBuiltins: [String: Builtin] {
        return [
            "array.concat": BuiltinFuncs.arrayConcat,
            "internal.member_2": BuiltinFuncs.isMemberOf,
        ]
    }

    func invoke(name: String, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard let builtin = builtins[name] else {
            throw RegistryError.builtinNotFound(name: name)
        }
        return try await builtin(args)
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
