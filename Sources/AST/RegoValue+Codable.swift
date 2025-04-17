import CoreFoundation
import Foundation

extension RegoValue: Codable {
    // Constructor for use with JSONSerialization
    package init(from: Any) throws(ValueError) {
        switch from {
        case let v as String:
            self = .string(v)
        case let v as [Any]:
            do {
                let values: [RegoValue] = try v.map { try RegoValue(from: $0) }
                self = .array(values)
            } catch {
                // TODO wrap the inital error. Need to assert it backto RegoError
                throw .unsupportedArrayElement
            }
        case let v as [String: Any]:
            do {
                let values: [RegoValue: RegoValue] = try v.reduce(into: [:]) { m, elem in
                    m[try RegoValue(from: elem.key)] = try RegoValue(from: elem.value)
                }
                self = .object(values)
            } catch {
                // TODO wrap the inital error. Need to assert it back to RegoError
                throw .unsupportedObjectElement
            }
        case let v as NSNumber:
            if v.isBool {
                self = .boolean(v.boolValue)
            } else {
                self = .number(v)
            }
        case _ as NSNull:
            self = .null
        default:
            throw .unsupportedType(type(of: from))
        }
    }

    // Initialize a RegoValue from raw JSON-encoded data
    public init(jsonData rawJson: Data) throws {
        // TODO throws deserializationerror, valuerror
        let d = try JSONSerialization.jsonObject(with: rawJson, options: [])
        try self.init(from: d)
    }

    // Decodable initializer
    public init(from decoder: Decoder) throws {
        // Try as an object
        do {
            let container = try decoder.container(keyedBy: AnyKey.self)
            let obj: [RegoValue: RegoValue] = try container.allKeys.reduce(into: [:]) { out, key in
                out[.string(key.stringValue)] = try container.decode(RegoValue.self, forKey: key)
            }
            self = .object(obj)
            return
        } catch {}

        // Try as an array
        do {
            var container = try decoder.unkeyedContainer()
            var out: [RegoValue] = []
            if let count = container.count {
                out.reserveCapacity(count)
            }
            while !container.isAtEnd {
                out.append(try container.decode(RegoValue.self))
            }

            self = .array(out)
            return
        } catch {}

        // Try as a scalar
        do {
            let container = try decoder.singleValueContainer()

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
                return
            }
            if let doubleValue = try? container.decode(Double.self) {
                self = .number(NSNumber(value: doubleValue))
                return
            }
            if let intValue = try? container.decode(Int.self) {
                self = .number(NSNumber(value: intValue))
                return
            }
            if let boolValue = try? container.decode(Bool.self) {
                self = .boolean(boolValue)
                return
            }
            if container.decodeNil() {
                self = .null
                return
            }
        } catch {}

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "unsupported RegoValue encoding"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            // *sigh* https://medium.com/@iostechset/dictionary-encoded-as-an-array-991d3f2608d0
            // I guess thats still a thing? Anyway, to get [RegoValue: RegoValue] to
            // encode matching Go, and not just make an array of alternating keys and
            // values, we'll do it ourselves.. Assume that at some point in the recursive
            // encoding we hit non-object (or empty object) values with concrete types for
            // the keys... then let the standard dictionary encoder handle the values.
            let keyEncoder = JSONEncoder()
            keyEncoder.outputFormatting = [.sortedKeys]
            let partiallyEncoded = try o.reduce(into: [String: RegoValue]()) { (result, elem) in
                let strKey: String
                do {
                    try strKey = String(elem.key)
                } catch {
                    throw EncodingError.invalidValue(
                        elem.key,
                        EncodingError.Context(
                            codingPath: encoder.codingPath,
                            debugDescription: "failed to stringify key",
                            underlyingError: error
                        )
                    )
                }
                result[strKey] = elem.value
            }
            try container.encode(partiallyEncoded)
        case .boolean(let b):
            try container.encode(b)
        case .number(let n):
            if self.isFloat {
                try container.encode(n.doubleValue)
            } else {
                try container.encode(n.intValue)
            }
        case .null:
            try container.encodeNil()
        case .set(let s):
            // The sets don't seem to follow the usual rules for ordering, this is expensive but
            // we need to give idempotent results on encoding outputs of a policy decision.
            try container.encode(s.sorted())
        case .undefined:
            try container.encode("<undefined>")
        }
    }

}

// RegoValue -> String initializer (Stringify)
extension String {
    public init(_ v: RegoValue) throws {
        self = try stringify(v)
    }
}

// stringify returns a string representation of a RegoValue
func stringify(_ v: RegoValue) throws -> String {
    if case .string(let s) = v {
        return s
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.nonConformingFloatEncodingStrategy = .throw
    guard let output = String(data: try encoder.encode(v), encoding: .utf8) else {
        throw RegoValue.RegoEncodingError.invalidUTF8
    }
    return output
}

// AnyKey allows dynamic decoding when keys are not known ahead of time
struct AnyKey: CodingKey {
    var intValue: Int?
    var stringValue: String = ""

    init?(intValue: Int) {
        self.intValue = intValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
}
