/// A representation of an error thrown by the Rego engine.
///
/// A RegoError will have a ``code`` specifying the type of error.
/// See ``RegoError/Code`` for available codes.
public struct RegoError: Sendable, Swift.Error {

    /// A domain-specific code describing the type of error.
    public struct Code: Hashable, Sendable {
        internal enum InternalCode {
            case internalError

            // Bundle errors
            case bundleInitializationError
            case bundleLoadError
            case bundleNameConflictError
            case bundleRootConflictError
            case bundleUnpreparedError
            case invalidArgumentError

            // Evaluation errors
            case assignOnceError
            case evaluationCancelled
            case invalidDataType
            case invalidOperand
            case maxCallDepthExceeded
            case noPlansFoundError
            case objectInsertOnceError
            case unknownDynamicFunction
            case unknownQuery
            case unsupportedQuery

            // Store errors
            case storePathNotFound

            // Builtin errors
            case argumentCountMismatch
            case argumentTypeMismatch
            case halt
        }

        private let internalCode: InternalCode

        internal init(_ code: InternalCode) {
            self.internalCode = code
        }

        // Bundle-related codes
        public static let bundleInitializationError = Code(.bundleInitializationError)
        public static let bundleLoadError = Code(.bundleLoadError)
        public static let bundleNameConflictError = Code(.bundleNameConflictError)
        public static let bundleRootConflictError = Code(.bundleRootConflictError)
        public static let bundleUnpreparedError = Code(.bundleUnpreparedError)
        public static let internalError = Code(.internalError)
        public static let invalidArgumentError = Code(.invalidArgumentError)

        // Evaluation errors
        public static let assignOnceError = Code(.assignOnceError)
        public static let evaluationCancelled = Code(.evaluationCancelled)
        public static let invalidDataType = Code(.invalidDataType)
        public static let invalidOperand = Code(.invalidOperand)
        public static let maxCallDepthExceeded = Code(.maxCallDepthExceeded)
        public static let noPlansFoundError = Code(.noPlansFoundError)
        public static let objectInsertOnceError = Code(.objectInsertOnceError)
        public static let unknownDynamicFunction = Code(.unknownDynamicFunction)
        public static let unknownQuery = Code(.unknownQuery)
        public static let unsupportedQuery = Code(.unsupportedQuery)

        // Store errors
        public static let storePathNotFound = Code(.storePathNotFound)

        // Builtin errors
        public static let argumentCountMismatch = Code(.argumentCountMismatch)
        public static let argumentTypeMismatch = Code(.argumentTypeMismatch)
        public static let halt = Code(.halt)
    }

    /// A code representing the high-level domain of the error.
    public var code: Code

    /// A message providing additional context about the error.
    public var message: String

    /// The original error which led to this error being thrown.
    public var cause: (any Swift.Error)?
}

/// A collection of Builtin-specific error constructors
public enum BuiltinError {
    public static func argumentCountMismatch(got: Int, want: Int) -> RegoError {
        return RegoError(
            code: .argumentCountMismatch,
            message: "argument count mismatch (got: \(got), want: \(want))"
        )
    }

    public static func argumentTypeMismatch(arg: String, got: String, want: String) -> RegoError {
        return RegoError(
            code: .argumentTypeMismatch,
            message: "argument type mismatch (arg: \(arg), got: \(got), want: \(want))"
        )
    }

    /// General-purpose builtin evaluation error.
    ///
    public static func evalError(msg: String) -> RegoError {
        return RegoError(
            code: .argumentCountMismatch,
            message: "builtin evalutation error: \(msg)"
        )
    }

    // halt is a special purpose builtin error that will signal that policy evaluation
    // must be stopped immediately. This will bypass the strict builtin configuration
    // and always raise an evaluation error.
    internal static func halt(reason: String) -> RegoError {
        return RegoError(
            code: .halt,
            message: "builtin error (halting): \(reason)"
        )
    }

    internal static func isHaltError(_ error: Error) -> Bool {
        guard let regoError = error as? RegoError else {
            return false
        }
        return regoError.code == .halt
    }
}
