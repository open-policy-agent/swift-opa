import Foundation

// RegoValue represents any concrete JSON-representable value consumable by Rego
public enum RegoValue: Equatable, Sendable, Hashable {
    case array([RegoValue])
    case boolean(Bool)
    case null
    case number(NSNumber)
    case object([String: RegoValue])
    //    case set(SetType) // TODO Implement sets
    case string(String)

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
                let values: [String: RegoValue] = try v.reduce(into: [:]) { m, elem in
                    m[elem.key] = try RegoValue(from: elem.value)
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
}

private let boolLiteral = NSNumber(booleanLiteral: true)
extension NSNumber {
    var isBool: Bool {
        return type(of: self) == type(of: boolLiteral)
    }
}
