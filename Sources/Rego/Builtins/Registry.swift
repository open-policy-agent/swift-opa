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
            "max": BuiltinFuncs.max,
            "min": BuiltinFuncs.min,

            // Arithmetic
            "plus": BuiltinFuncs.plus,
            "minus": BuiltinFuncs.minus,
            "mul": BuiltinFuncs.mul,
            "div": BuiltinFuncs.div,
            "round": BuiltinFuncs.round,
            "ceil": BuiltinFuncs.ceil,
            "floor": BuiltinFuncs.floor,
            "abs": BuiltinFuncs.abs,
            "rem": BuiltinFuncs.rem,

            // Array
            "array.concat": BuiltinFuncs.arrayConcat,
            "array.reverse": BuiltinFuncs.arrayReverse,
            "array.slice": BuiltinFuncs.arraySlice,

            // Bits
            "bits.and": BuiltinFuncs.bitsAnd,
            "bits.lsh": BuiltinFuncs.bitsShiftLeft,
            "bits.negate": BuiltinFuncs.bitsNegate,
            "bits.or": BuiltinFuncs.bitsOr,
            "bits.rsh": BuiltinFuncs.bitsShiftRight,
            "bits.xor": BuiltinFuncs.bitsXor,

            // Collections
            "internal.member_2": BuiltinFuncs.isMemberOf,

            // Comparison
            "gt": BuiltinFuncs.greaterThan,
            "gte": BuiltinFuncs.greaterThanEq,
            "lt": BuiltinFuncs.lessThan,
            "lte": BuiltinFuncs.lessThanEq,
            "neq": BuiltinFuncs.notEq,
            "equal": BuiltinFuncs.equal,

            // Cryptography
            "crypto.hmac.equal": BuiltinFuncs.hmacsEqual,
            "crypto.hmac.md5": BuiltinFuncs.insecureMD5HMAC,
            "crypto.hmac.sha1": BuiltinFuncs.insecureSha1HMAC,
            "crypto.hmac.sha256": BuiltinFuncs.sha256HMAC,
            "crypto.hmac.sha512": BuiltinFuncs.sha512HMAC,
            "crypto.md5": BuiltinFuncs.insecureMD5Hash,
            "crypto.sha1": BuiltinFuncs.insecureSHA1Hash,
            "crypto.sha256": BuiltinFuncs.sha256Hash,

            // Encoding
            "base64.encode": BuiltinFuncs.base64Encode,
            "base64.decode": BuiltinFuncs.base64Decode,
            "base64.is_valid": BuiltinFuncs.base64IsValid,
            "base64url.encode": BuiltinFuncs.base64UrlEncode,
            "base64url.encode_no_pad": BuiltinFuncs.base64UrlEncodeNoPad,
            "base64url.decode": BuiltinFuncs.base64UrlDecode,
            "hex.encode": BuiltinFuncs.hexEncode,
            "hex.decode": BuiltinFuncs.hexDecode,

            // Objects
            "object.get": BuiltinFuncs.objectGet,
            "object.keys": BuiltinFuncs.objectKeys,

            // Sets
            "and": BuiltinFuncs.and,
            "intersection": BuiltinFuncs.intersection,
            "or": BuiltinFuncs.or,
            "union": BuiltinFuncs.union,

            // String
            "concat": BuiltinFuncs.concat,
            "contains": BuiltinFuncs.contains,
            "endswith": BuiltinFuncs.endsWith,
            "format_int": BuiltinFuncs.formatInt,
            "indexof": BuiltinFuncs.indexOf,
            "indexof_n": BuiltinFuncs.indexOfN,
            "lower": BuiltinFuncs.lower,
            "replace": BuiltinFuncs.replace,
            "split": BuiltinFuncs.split,
            "sprintf": BuiltinFuncs.sprintf,
            "startswith": BuiltinFuncs.startsWith,
            "strings.reverse": BuiltinFuncs.reverse,
            "substring": BuiltinFuncs.substring,
            "trim": BuiltinFuncs.trim,
            "trim_left": BuiltinFuncs.trimLeft,
            "trim_prefix": BuiltinFuncs.trimPrefix,
            "trim_right": BuiltinFuncs.trimRight,
            "trim_space": BuiltinFuncs.trimSpace,
            "trim_suffix": BuiltinFuncs.trimSuffix,
            "upper": BuiltinFuncs.upper,

            // Trace
            "trace": BuiltinFuncs.trace,

            // Types
            "is_array": BuiltinFuncs.isArray,
            "is_boolean": BuiltinFuncs.isBoolean,
            "is_null": BuiltinFuncs.isNull,
            "is_number": BuiltinFuncs.isNumber,
            "is_object": BuiltinFuncs.isObject,
            "is_set": BuiltinFuncs.isSet,
            "is_string": BuiltinFuncs.isString,
            "type_name": BuiltinFuncs.typeName,

            // Units
            "units.parse": BuiltinFuncs.parseUnits,
            "units.parse_bytes": BuiltinFuncs.parseByteUnits,
        ]
    }

    func invoke(
        withCtx ctx: BuiltinContext,
        name: String,
        args: [AST.RegoValue],
        strict: Bool = false
    ) async throws -> AST.RegoValue {
        guard let builtin = builtins[name] else {
            throw RegistryError.builtinNotFound(name: name)
        }
        do {
            return try await builtin(ctx, args)
        } catch {
            if case .halt = error as? BuiltinFuncs.BuiltinError {
                // halt errors mean we propagate, always.
                throw error
            }

            // In "strict" mode we are going to propagate the error, if disabled
            // they are treated as undefined.
            if strict {
                throw error
            }
            return .undefined
        }
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
