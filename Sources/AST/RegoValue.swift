import Foundation

// RegoValue represents any concrete JSON-representable value consumable by Rego
public enum RegoValue: Sendable, Hashable {
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
}

// Helpers for working with RegoValues
extension RegoValue {
    // count returns the element count for the value
    // if it is a collection type (array|object|set|string),
    // otherwise it returns zero.
    public var count: Int? {
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

    public func isUndefined() -> Bool {
        guard case .undefined = self else {
            return false
        }
        return true
    }

    public var isFloat: Bool {
        guard case .number = self else {
            return false
        }
        // We know it is a number, so if it is not an int, it must be a float
        return self.integerValue == nil
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
            // It's probably a float
            return nil
        }
        return integerValue
    }

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

// Helper for differentiating between an NSNumber which a boolean vs. a number.
// We're trying to avoid confusing NSNumber(0) from false and NSNumber(1) from true.
private let boolLiteral = NSNumber(booleanLiteral: true)
extension NSNumber {
    var isBool: Bool {
        return type(of: self) == type(of: boolLiteral)
    }

    var numberType: CFNumberType {
        return CFNumberGetType(self as CFNumber)
    }
}
