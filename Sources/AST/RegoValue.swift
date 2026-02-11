import CoreFoundation
import Foundation

/// RegoValue represents structured data over which policy can be evaluated.
///
/// RegoValue maps closely to JSON types, but expands on these by supporting sets
/// and arbitrary values as object keys.
public enum RegoValue: Sendable, Hashable {
    case array([RegoValue])
    case boolean(Bool)
    case null
    case number(RegoNumber)
    case object([RegoValue: RegoValue])
    case set(Set<RegoValue>)
    case string(String)
    case undefined
}

// Related errors
extension RegoValue {
    package enum ValueError: Error {
        case unsupportedArrayElement
        case unsupportedObjectElement
        case unsupportedType(Any.Type)
    }
    package enum RegoEncodingError: Error {
        case invalidUTF8
    }
}

// Helpers for working with RegoValues
extension RegoValue {
    // count returns the element count for the value
    // if it is a collection type (array|object|set|string),
    // otherwise it returns zero.
    package var count: Int? {
        switch self {
        case .array(let a):
            return a.count
        case .object(let o):
            return o.count
        case .set(let s):
            return s.count
        case .string(let s):
            return s.count
        default:
            return nil
        }
    }

    package var isUndefined: Bool {
        guard case .undefined = self else {
            return false
        }
        return true
    }

    package var isCollection: Bool {
        switch self {
        case .array, .object, .set:
            return true
        default:
            return false
        }
    }

    package var isFloat: Bool {
        guard case .number(let n) = self else {
            return false
        }
        return n.isFloatType
    }

    /// The (long) integer value of a RegoValue, if it is a .number and contained value is in fact a whole number.
    /// Note that Decimals and Floats are treated as integers when they don't have fractional reminders.
    /// This does not do rounding or truncation and instead (for float types) relies on Decimal implementation
    /// to detect whether or not a decimal is a whole number or not.
    /// In all other cases, including different types of RegoValue, nil is returned.
    package var integerValue: Int64? {
        guard case .number(let number) = self else {
            return nil
        }
        return number.int64Value
    }

    /// The name repesenting the concrete type of this ``RegoValue``.
    ///
    /// Valid types are: [array|boolean|null|number|object|set|string|undefined].
    public var typeName: String {
        switch self {
        case .array(_):
            return "array"
        case .boolean(_):
            return "boolean"
        case .null:
            return "null"
        case .number(_):
            return "number"
        case .object(_):
            return "object"
        case .set(_):
            return "set"
        case .string(_):
            return "string"
        case .undefined:
            return "undefined"
        }
    }
}
