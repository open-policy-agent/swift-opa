import AST
import Foundation

// BuiltinFuncs is a wrapper around all the well defined (and implemented in swift)
// Rego builtin functions. The functions are implemented in files following the
// upstream Go topdown file organization to help better keep the 1:1 mapping.
// Each function needs to be registered in the BuiltinRegistry's defaultBuiltins.
enum BuiltinFuncs {
    public enum BuiltinError: Equatable, Error {
        case argumentCountMismatch(got: Int, expected: Int)
        case argumentTypeMismatch(arg: String, got: String = "", want: String = "")

        /// General-purpose Evaluation Error.
        case evalError(msg: String)

        // halt is a special purpose builtin error that will signal that policy evaluation
        // must be stopped immediately. This will bypass the strict builtin configuration
        // and always raise an evaluation error.
        case halt(reason: String)
    }
}
