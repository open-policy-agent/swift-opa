import Foundation

// Custom decoding reads Darwin's JSONSerialization results in place, which is much faster than JSONDecoder.
// Other platforms decode with JSONDecoder, since swift-corelibs-foundation's JSONSerialization is much slower there.
#if canImport(Darwin)

    /// A value from JSONSerialization output. On Darwin we get Foundation objects, and using `AnyObject` allows us to
    /// avoid boxing each object in an `Any`. We still cast to concrete types later, but casting an `AnyObject` to a
    /// class like `NSNumber` is a quick class check, while casting out of an `Any` takes the slower general path.
    package typealias JSONValue = AnyObject

    /// A JSON object from JSONSerialization output. Provides typed member accessors for custom decoders.
    /// Accessors follow JSONDecoder's rules and throw `DecodingError` with the appropriate coding path filled in.
    package struct JSONObject {
        // Bridging an NSDictionary to a Swift dictionary would rehash every key, so we look keys up as NSStrings
        // instead.
        private let members: CFDictionary

        package init(_ value: JSONValue) throws {
            guard let members = value as? NSDictionary else {
                throw JSONConvert.mismatch([String: Any].self, value)
            }
            self.members = members as CFDictionary
        }

        @inline(__always)
        private func member(_ key: String) -> JSONValue? {
            // CFDictionaryGetValue borrows the key and returns the value without retaining either. We keep the bridged
            // key alive with `withExtendedLifetime` until the dictionary lookup returns, and then create a strong
            // reference to the returned value with `takeUnretainedValue`. This is safe because the dictionary in
            // `members` still holds the value when we take the reference.
            let nsKey = key as NSString
            let value = withExtendedLifetime(nsKey) {
                CFDictionaryGetValue(members, Unmanaged.passUnretained(nsKey).toOpaque()).map {
                    Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue()
                }
            }
            // NSString compares UTF-16 code units, while Swift's String (and so JSONDecoder) compares by canonical
            // equivalence. The two only differ for keys that are non-ASCII or contain "K", ";", or "`", which equal the
            // Kelvin sign, the Greek question mark, and the Greek varia. On a miss, we compare those keys as Strings.
            if value == nil, Self.needsCanonicalLookup(key) {
                return canonicalMember(key)
            }
            return value
        }

        static func needsCanonicalLookup(_ key: String) -> Bool {
            key.utf8.contains {
                $0 >= 0x80 || $0 == UInt8(ascii: "K") || $0 == UInt8(ascii: ";") || $0 == UInt8(ascii: "`")
            }
        }

        @inline(never)
        private func canonicalMember(_ key: String) -> JSONValue? {
            for case (let memberKey as String, let value) in members as NSDictionary where memberKey == key {
                return value as AnyObject
            }
            return nil
        }

        /// Parses JSON for custom decoders, rejecting NUL bytes and duplicate object keys.
        /// Malformed JSON reports a `DecodingError`, as JSONDecoder does.
        package static func parse(_ data: Data) throws -> JSONValue {
            try RegoValue.parseRejectingDuplicateKeys(data) {
                do {
                    return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as JSONValue
                } catch {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: [], debugDescription: "The given data was not valid JSON.",
                            underlyingError: error))
                }
            }
        }

        @inline(__always)
        private func required(_ key: String) throws -> JSONValue {
            guard let value = member(key) else {
                throw DecodingError.keyNotFound(
                    JSONKey(key), .init(codingPath: [], debugDescription: "No value associated with key \"\(key)\"."))
            }
            return value
        }

        @inline(__always)
        private func optional(_ key: String) -> JSONValue? {
            guard let value = member(key), !(value is NSNull) else {
                return nil
            }
            return value
        }

        /// Converts a required member. A missing key throws `keyNotFound`, and `null` throws `valueNotFound`.
        @inline(__always)
        package func decode<T>(_ key: String, _ convert: (JSONValue) throws -> T) throws -> T {
            let value = try required(key)
            do {
                return try convert(value)
            } catch let error as DecodingError {
                throw error.prepending(JSONKey(key))
            }
        }

        /// Converts an optional member. A missing key or `null` returns nil.
        @inline(__always)
        package func decodeIfPresent<T>(_ key: String, _ convert: (JSONValue) throws -> T) throws -> T? {
            guard let value = optional(key) else {
                return nil
            }
            do {
                return try convert(value)
            } catch let error as DecodingError {
                throw error.prepending(JSONKey(key))
            }
        }

        package func string(_ key: String) throws -> String {
            try decode(key, JSONConvert.string)
        }

        package func stringIfPresent(_ key: String) throws -> String? {
            try decodeIfPresent(key, JSONConvert.string)
        }

        // Generic accessors call their converter directly, since a closure would capture the metatype.
        package func integer<T: FixedWidthInteger>(_ key: String) throws -> T {
            let value = try required(key)
            do {
                return try JSONConvert.integer(value)
            } catch let error as DecodingError {
                throw error.prepending(JSONKey(key))
            }
        }

        package func integerIfPresent<T: FixedWidthInteger>(_ key: String) throws -> T? {
            guard let value = optional(key) else {
                return nil
            }
            do {
                return try JSONConvert.integer(value) as T
            } catch let error as DecodingError {
                throw error.prepending(JSONKey(key))
            }
        }

        package func bool(_ key: String) throws -> Bool {
            try decode(key, JSONConvert.bool)
        }

        package func rawValue<E: RawRepresentable>(_ key: String) throws -> E where E.RawValue == String {
            let value = try required(key)
            do {
                return try JSONConvert.rawValue(value)
            } catch let error as DecodingError {
                throw error.prepending(JSONKey(key))
            }
        }

        package func array<T>(_ key: String, _ element: (JSONValue) throws -> T) throws -> [T] {
            try decode(key) { try JSONConvert.array($0, element) }
        }

        package func arrayIfPresent<T>(_ key: String, _ element: (JSONValue) throws -> T) throws -> [T]? {
            try decodeIfPresent(key) { try JSONConvert.array($0, element) }
        }
    }

    /// Converters from JSONSerialization values to Swift types, following JSONDecoder's rules.
    package enum JSONConvert {
        package static func string(_ value: JSONValue) throws -> String {
            guard var s = value as? String else {
                throw mismatch(String.self, value)
            }
            // Bridged NSStrings are slower to hash and compare, so store native UTF-8 like JSONDecoder does.
            s.makeContiguousUTF8()
            return s
        }

        package static func bool(_ value: JSONValue) throws -> Bool {
            guard let n = value as? NSNumber, n.isBool else {
                throw mismatch(Bool.self, value)
            }
            return n.boolValue
        }

        /// Accepts integers and integral floats that fit in `T`, like JSONDecoder.
        package static func integer<T: FixedWidthInteger>(_ value: JSONValue) throws -> T {
            guard let n = value as? NSNumber, !n.isBool else {
                throw mismatch(T.self, value)
            }
            let result: T?
            switch UInt8(bitPattern: n.objCType.pointee) {
            case UInt8(ascii: "f"), UInt8(ascii: "d"):
                result = T(exactly: n.doubleValue)
            case UInt8(ascii: "Q"):
                result = T(exactly: n.uint64Value)
            default:
                result = T(exactly: n.int64Value)
            }
            guard let result else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Number \(n) does not fit in \(T.self)."))
            }
            return result
        }

        package static func rawValue<E: RawRepresentable>(_ value: JSONValue) throws -> E where E.RawValue == String {
            let s = try string(value)
            guard let e = E(rawValue: s) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: [], debugDescription: "Cannot initialize \(E.self) from invalid String value \(s)"))
            }
            return e
        }

        package static func array<T>(_ value: JSONValue, _ element: (JSONValue) throws -> T) throws -> [T] {
            // Reading NSArray elements through CoreFoundation avoids boxing each in an `Any`.
            guard let elements = value as? NSArray else {
                throw mismatch([Any].self, value)
            }
            let array = elements as CFArray
            let count = CFArrayGetCount(array)
            var out: [T] = []
            out.reserveCapacity(count)
            for i in 0..<count {
                // CFArrayGetValueAtIndex returns a raw pointer rather than an object, so we use `Unmanaged` to turn it
                // back into a reference. The array doesn't retain the value for us, so we use `takeUnretainedValue` to
                // create a strong reference. This is safe because `array` still holds the element when we take the
                // reference.
                let e = Unmanaged<AnyObject>.fromOpaque(CFArrayGetValueAtIndex(array, i)!).takeUnretainedValue()
                do {
                    out.append(try element(e))
                } catch let error as DecodingError {
                    throw error.prepending(JSONKey(index: i))
                }
            }
            return out
        }

        package static func regoValue(_ value: JSONValue) throws -> RegoValue {
            do {
                return try RegoValue(from: value)
            } catch {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Unsupported JSON value.", underlyingError: error))
            }
        }

        /// A `null` where a value is required is `valueNotFound`, and any other wrong type is `typeMismatch`.
        package static func mismatch(_ type: Any.Type, _ value: JSONValue) -> DecodingError {
            if value is NSNull {
                return .valueNotFound(
                    type, .init(codingPath: [], debugDescription: "Expected \(type) value but found null."))
            }
            return .typeMismatch(
                type, .init(codingPath: [], debugDescription: "Expected \(type), found \(Swift.type(of: value))."))
        }
    }

    package struct JSONKey: CodingKey {
        package var stringValue: String
        package var intValue: Int?

        package init(_ key: String) {
            self.stringValue = key
        }

        package init(stringValue: String) {
            self.stringValue = stringValue
        }

        package init(index: Int) {
            self.stringValue = "Index \(index)"
            self.intValue = index
        }

        package init(intValue: Int) {
            self.init(index: intValue)
        }
    }

    extension DecodingError {
        /// Adds `key` to the front of the coding path, as errors unwind out of nested values.
        package func prepending(_ key: CodingKey) -> DecodingError {
            func prepend(_ c: Context) -> Context {
                .init(
                    codingPath: [key] + c.codingPath, debugDescription: c.debugDescription,
                    underlyingError: c.underlyingError)
            }
            switch self {
            case .typeMismatch(let type, let c): return .typeMismatch(type, prepend(c))
            case .valueNotFound(let type, let c): return .valueNotFound(type, prepend(c))
            case .keyNotFound(let k, let c): return .keyNotFound(k, prepend(c))
            case .dataCorrupted(let c): return .dataCorrupted(prepend(c))
            @unknown default: return self
            }
        }
    }

#endif
