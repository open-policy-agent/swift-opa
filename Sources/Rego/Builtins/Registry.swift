import AST
import Foundation

public typealias Builtin = @Sendable (BuiltinContext, [AST.RegoValue]) async throws -> AST.RegoValue

public struct BuiltinContext {
    public let location: OPA.Trace.Location
    public var tracer: OPA.Trace.QueryTracer?
    /// Date and Time of Context creation
    public let timestamp: Date
    internal let cache: Ptr<BuiltinsCache>
    internal let rand: Ptr<RandomNumberGenerator>

    init(

        location: OPA.Trace.Location = .init(),
        tracer: OPA.Trace.QueryTracer? = nil,
        cache: Ptr<BuiltinsCache>? = nil,
        timestamp: Date? = nil,
        rand: Ptr<RandomNumberGenerator>? = nil
    ) {
        self.location = location
        self.tracer = tracer
        // Note that we will create a new cache if one hasn't been provided -
        // some builtin evaluations (e.g. UUID) expect the cache.
        // In most/all? cases, we expect a shared cache to be passed in here from EvaluationContext
        self.cache = cache ?? Ptr<BuiltinsCache>(toCopyOf: BuiltinsCache())
        self.timestamp = timestamp ?? Date()
        // Unless Random Number Generator is provided, we will use a new System one.
        // Note that SystemRandomNumberGenerator is automatically seeded,
        // safe to use in multiple threads, and uses a cryptographically secure
        // algorithm whenever possible.
        // See https://developer.apple.com/documentation/swift/systemrandomnumbergenerator/
        self.rand = rand ?? Ptr<RandomNumberGenerator>(toCopyOf: SystemRandomNumberGenerator())
    }
}

public struct BuiltinRegistry: Sendable {
    let builtins: [String: Builtin]

    // defaultRegistry is the BuiltinRegistry with all capabilities enabled
    public static var defaultRegistry: BuiltinRegistry {
        BuiltinRegistry(
            builtins: BuiltinRegistry.defaultBuiltins
        )
    }

    internal static var defaultBuiltins: [String: Builtin] {
        return [
            // Aggregates
            "count": BuiltinFuncs.count,
            "max": BuiltinFuncs.max,
            "min": BuiltinFuncs.min,
            "product": BuiltinFuncs.product,
            "sort": BuiltinFuncs.sort,
            "sum": BuiltinFuncs.sum,

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
            "internal.member_3": BuiltinFuncs.isMemberOfWithKey,

            // Comparison
            "gt": BuiltinFuncs.greaterThan,
            "gte": BuiltinFuncs.greaterThanEq,
            "lt": BuiltinFuncs.lessThan,
            "lte": BuiltinFuncs.lessThanEq,
            "neq": BuiltinFuncs.notEq,
            "equal": BuiltinFuncs.equal,

            // Conversions aka Casts
            "to_number": BuiltinFuncs.toNumber,

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

            // Numbers
            "numbers.range": BuiltinFuncs.numbersRange,
            "numbers.range_step": BuiltinFuncs.numbersRangeStep,

            // Objects
            "object.get": BuiltinFuncs.objectGet,
            "object.keys": BuiltinFuncs.objectKeys,
            "object.union": BuiltinFuncs.objectUnion,
            "object.union_n": BuiltinFuncs.objectUnionN,

            // Rand
            "rand.intn": BuiltinFuncs.numbersRandIntN,

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
            "strings.count": BuiltinFuncs.stringsCount,
            "strings.reverse": BuiltinFuncs.reverse,
            "substring": BuiltinFuncs.substring,
            "trim": BuiltinFuncs.trim,
            "trim_left": BuiltinFuncs.trimLeft,
            "trim_prefix": BuiltinFuncs.trimPrefix,
            "trim_right": BuiltinFuncs.trimRight,
            "trim_space": BuiltinFuncs.trimSpace,
            "trim_suffix": BuiltinFuncs.trimSuffix,
            "upper": BuiltinFuncs.upper,
            "internal.template_string": BuiltinFuncs.templateString,

            // Time
            "time.now_ns": BuiltinFuncs.timeNowNanos,

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

            // UUID
            "uuid.rfc4122": BuiltinFuncs.makeRfc4122UUID,
            "uuid.parse": BuiltinFuncs.parseUUID,
        ]
    }

    public subscript(name: String) -> Builtin? {
        self.builtins[name]
    }

    func invoke(
        withContext ctx: BuiltinContext,
        name: String,
        args: [AST.RegoValue],
        strict: Bool = false
    ) async throws -> AST.RegoValue {
        guard let builtin = self[name] else {
            throw RegistryError.builtinNotFound(name: name)
        }
        do {
            return try await builtin(ctx, args)
        } catch {
            if BuiltinError.isHaltError(error) {
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
    /// Returns the names of all supported builtins
    public static func getSupportedBuiltinNames() -> [String] {
        return Array(defaultBuiltins.keys)
    }
}

extension BuiltinRegistry {
    enum RegistryError: Swift.Error {
        case builtinNotFound(name: String)
    }
}

struct BuiltinNoteEvent: OPA.Trace.TraceableEvent {
    public var operation: OPA.Trace.Operation = .note
    public var message: String
    public var location: OPA.Trace.Location
}
