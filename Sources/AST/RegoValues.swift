import Foundation

// RegoValue represents any concrete JSON-representable value consumable by Rego
public enum RegoValue: Codable, Comparable, Sendable, Hashable {
    case array([RegoValue])
    case boolean(Bool)
    case null
    case number(NSNumber)
    case object([RegoValue: RegoValue])
    case set(Set<RegoValue>)
    case string(String)
    case undefined

    public enum ValueError: Error {
        case unsupportedArrayElement
        case unsupportedObjectElement
        case unsupportedType(Any.Type)
    }

    public init(from: Any) throws(ValueError) {
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
    public init(fromJson rawJson: Data) throws {
        // TODO throws deserializationerror, valuerror
        let d = try JSONSerialization.jsonObject(with: rawJson, options: [])
        try self.init(from: d)
    }

    public init(_ obj: [String: RegoValue]) {
        let d: [RegoValue: RegoValue] = obj.reduce(into: [:]) { m, elem in
            m[.string(elem.key)] = elem.value
        }
        self = .object(d)
    }

    public func isUndefined() -> Bool {
        guard case .undefined = self else {
            return false
        }
        return true
    }

    public var integerValue: Int? {
        guard case .number(let number) = self else {
            return nil
        }

        // TODO: Whats more sketchy? This switch that might not be exhaustive or the math check that might be lossy and more slow?
        //switch numberType {
        //    case
        //        .sInt8Type,
        //        .sInt16Type,
        //        .sInt32Type,
        //        .sInt64Type,
        //        .shortType,
        //        .intType,
        //        .longType,
        //        .longLongType,
        //        .charType,
        //        .cfIndexType,
        //        .nsIntegerType:
        //    return true
        //default:
        //    return false

        let decimalValue = Decimal(number.doubleValue)
        let integerValue = number.intValue

        // Check if there is a fractional part comparing between coerced types
        // to detect truncation of the number when its an Integer
        let fractionalRemainder = decimalValue - Decimal(integerValue)
        guard fractionalRemainder == Decimal(0) else {
            return nil
        }
        return integerValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(RegoValue.self)
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
            let partiallyEncoded = try o.reduce(into: [String: RegoValue]()) { (result, elem) in
                let strKey =
                    switch elem.key {
                    case .string(let s):
                        s
                    default:
                        String(data: try JSONEncoder().encode(elem.key), encoding: .utf8)!
                    }
                result[strKey] = elem.value
            }
            try container.encode(partiallyEncoded)
        case .boolean(let b):
            try container.encode(b)
        case .number(let n):
            try container.encode(n.stringValue)
        case .null:
            try container.encodeNil()
        case .set(let s):
            try container.encode(s)
        case .undefined:
            try container.encode("<undefined>")
        }
    }

    // Following the upstream OPA Go implementation:
    //
    //   Different types are never equal to each other. For comparison purposes, types
    //   are sorted as follows:
    //
    //   nil < Null < Boolean < Number < String < Var < Ref < Array < Object < Set <
    //   ArrayComprehension < ObjectComprehension < SetComprehension < Expr < SomeDecl
    //   < With < Body < Rule < Import < Package < Module.
    //
    //   Arrays and Refs are equal if and only if both a and b have the same length
    //   and all corresponding elements are equal. If one element is not equal, the
    //   return value is the same as for the first differing element. If all elements
    //   are equal but a and b have different lengths, the shorter is considered less
    //   than the other.
    //
    //   Objects are considered equal if and only if both a and b have the same sorted
    //   (key, value) pairs and are of the same length. Other comparisons are
    //   consistent but not defined.
    //
    //   Sets are considered equal if and only if the symmetric difference of a and b
    //   is empty.
    //   Other comparisons are consistent but not defined.
    //
    // Since we have a subset of these types we'll keep the order, skipping any that we
    // don't have implemented here (yet).
    public static func < (lhs: RegoValue, rhs: RegoValue) -> Bool {
        // Check their type sort orders first
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        // Handle the case where the lhs and rhs are the same types
        // For the collection types compare by size first, fall back
        // to the default hash behavior
        switch (lhs, rhs) {
        case (.array(let lhs), .array(let rhs)):
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
        case (.boolean(let lhs), .boolean(let rhs)):
            return rhs && !lhs
        case (.number(let lhs), .number(let rhs)):
            return lhs.compare(rhs) == .orderedAscending
        case (.object(let lhs), .object(let rhs)):
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
        case (.set(let lhs), .set(let rhs)):
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
        case (.string(let lhs), .string(let rhs)):
            return lhs < rhs
        default:
            break
        }

        return lhs.hashValue < rhs.hashValue
    }

    public static func compare(_ lhs: RegoValue, _ rhs: RegoValue) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        } else if lhs > rhs {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    public var sortOrder: Int {
        return switch self {
        case .undefined: 0
        case .null: 1
        case .boolean: 2
        case .number: 3
        case .string: 4
        case .array: 5
        case .object: 6
        case .set: 7
        }
    }
}

private let boolLiteral = NSNumber(booleanLiteral: true)
extension NSNumber {
    var isBool: Bool {
        return type(of: self) == type(of: boolLiteral)
    }

    var numberType: CFNumberType {
        return CFNumberGetType(self as CFNumber)
    }
}

extension [RegoValue: RegoValue] {
    public func merge(with other: [RegoValue: RegoValue]) -> [RegoValue: RegoValue] {
        var result = self
        for (k, v) in other {
            if case .object(let objValueSelf) = self[k], case .object(let objValueOther) = v {
                // both self and other have objects at this key, merge them recursively
                result[k] = .object(objValueSelf.merge(with: objValueOther))
            } else {
                result[k] = v
            }
        }
        return result
    }
}
