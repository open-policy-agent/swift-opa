import Foundation

// RegoValue represents any concrete JSON-representable value consumable by Rego
public enum RegoValue: Encodable, Equatable, Sendable, Hashable {
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

private let boolLiteral = NSNumber(booleanLiteral: true)
extension NSNumber {
    var isBool: Bool {
        return type(of: self) == type(of: boolLiteral)
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
