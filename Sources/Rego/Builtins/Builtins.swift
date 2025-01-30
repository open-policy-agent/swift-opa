import AST
import Foundation

// BuiltinFuncs is a wrapper around all the well defined (and implemented in swift)
// Rego builtin functions. The functions are implemented in files following the
// upstream Go topdown file organization to help better keep the 1:1 mapping.
// Each function needs to be registered in the BuiltinRegistry's defaultBuiltins.
enum BuiltinFuncs {
    enum BuiltinError: Error {
        case argumentCountMismatch(got: Int, expected: Int)
        case argumentTypeMismatch(arg: String)
    }
}
