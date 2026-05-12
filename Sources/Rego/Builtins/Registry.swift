import AST
import Foundation

public typealias AsyncBuiltin = @Sendable (BuiltinContext, [AST.RegoValue]) async throws -> AST.RegoValue

/// Non-async variant of `AsyncBuiltin` for use in the synchronous VM path.
public typealias SyncBuiltin = @Sendable (BuiltinContext, [AST.RegoValue]) throws -> AST.RegoValue

/// Whether a builtin is synchronous (usable on both the async and sync VM paths)
/// or async-only (usable on the async path only, e.g. because it performs network I/O).
public enum BuiltinImpl: Sendable {
    case sync(SyncBuiltin)
    case asyncOnly(AsyncBuiltin)
}

public struct BuiltinContext: @unchecked Sendable {
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
    // Precomputed callables to avoid a closure allocation on every lookup.
    private let asyncCallables: [String: AsyncBuiltin]
    private let syncCallables: [String: SyncBuiltin]

    init(builtins: [String: BuiltinImpl]) {
        var asyncImpls: [String: AsyncBuiltin] = Dictionary(minimumCapacity: builtins.count)
        var syncImpls: [String: SyncBuiltin] = Dictionary(minimumCapacity: builtins.count)
        for (name, impl) in builtins {
            switch impl {
            case .sync(let f):
                // Use Swift's implicit throws→async throws widening (static thunk, no allocation).
                asyncImpls[name] = f
                syncImpls[name] = f
            case .asyncOnly(let f):
                asyncImpls[name] = f
            }
        }
        self.asyncCallables = asyncImpls
        self.syncCallables = syncImpls
    }

    /// Names of all registered builtins.
    public var names: Set<String> { Set(asyncCallables.keys) }

    /// The default registry containing all built-in Rego functions.
    public static var defaultRegistry: BuiltinRegistry {
        BuiltinRegistry(builtins: defaultBuiltins.mapValues { .sync($0) })
    }

    /// Creates a registry by merging custom async-only builtins with the default sync builtins.
    /// Custom builtins are available on the async path only.
    /// Throws `RegoError.ambiguousBuiltinError` if any custom builtin name conflicts with a default one.
    static func merging(customBuiltins: [String: AsyncBuiltin]) throws -> BuiltinRegistry {
        let conflicting = Set(customBuiltins.keys).intersection(defaultBuiltins.keys)
        guard conflicting.isEmpty else {
            throw RegoError(
                code: .ambiguousBuiltinError,
                message: "encountered conflicting builtin names between custom and default builtins: \(conflicting)"
            )
        }
        var impls: [String: BuiltinImpl] = defaultBuiltins.mapValues { .sync($0) }
        for (name, impl) in customBuiltins {
            impls[name] = .asyncOnly(impl)
        }
        return BuiltinRegistry(builtins: impls)
    }

    internal static var defaultBuiltins: [String: SyncBuiltin] {
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
            "json.is_valid": BuiltinFuncs.jsonIsValid,
            "json.marshal": BuiltinFuncs.jsonMarshal,
            "json.unmarshal": BuiltinFuncs.jsonUnmarshal,

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

            // SemVer
            "semver.compare": BuiltinFuncs.semverCompare,
            "semver.is_valid": BuiltinFuncs.semverIsValid,

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
            "strings.any_prefix_match": BuiltinFuncs.anyPrefixMatch,
            "strings.any_suffix_match": BuiltinFuncs.anySuffixMatch,
            "strings.count": BuiltinFuncs.stringsCount,
            "strings.render_template": BuiltinFuncs.renderTemplate,
            "strings.replace_n": BuiltinFuncs.replaceN,
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
            "time.add_date": BuiltinFuncs.timeAddDate,
            "time.clock": BuiltinFuncs.timeClock,
            "time.date": BuiltinFuncs.timeDate,
            "time.diff": BuiltinFuncs.timeDiff,
            "time.format": BuiltinFuncs.timeFormat,
            "time.now_ns": BuiltinFuncs.timeNowNanos,
            "time.parse_duration_ns": BuiltinFuncs.timeParseDurationNanos,
            "time.parse_ns": BuiltinFuncs.timeParseNanos,
            "time.parse_rfc3339_ns": BuiltinFuncs.timeParseRFC3339Nanos,
            "time.weekday": BuiltinFuncs.timeWeekday,

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

            // Walk
            "walk": BuiltinFuncs.walk,
        ]
    }

    public subscript(name: String) -> AsyncBuiltin? {
        asyncCallables[name]
    }

    func asyncLookup(_ name: String) -> AsyncBuiltin? { asyncCallables[name] }

    func syncLookup(_ name: String) -> SyncBuiltin? { syncCallables[name] }

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
