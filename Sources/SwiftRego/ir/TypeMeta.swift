//
//  TypeMeta.swift
//  Type metadata for IR plans (used for describing function signatures, etc)
//

import Foundation

enum types {
    struct AnyType: Type, Codable {
        let type = KnownTypes.any
        var of: [any Type]?

        enum CodingKeys: String, CodingKey {
            case of = "of"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let argsDecoder = try container.decodeIfPresent(
                [TypeDecoder].self,
                forKey: .of)
            of = argsDecoder?.map { $0.type }
        }

        func encode(to encoder: any Encoder) throws {
            throw EncodingError.unsupported
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
        static func == (lhs: AnyType, rhs: AnyType) -> Bool {
            // TODO Implement!!
            return false
        }
    }

    struct ArrayType: Type, Codable {
        let type = KnownTypes.array
        var staticItems: [any Type]?
        var dynamicItems: (any Type)?

        enum CodingKeys: String, CodingKey {
            case staticItems = "static"
            case dynamicItems = "dynamic"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let argsDecoder = try container.decodeIfPresent(
                [TypeDecoder].self,
                forKey: .staticItems)
            staticItems = argsDecoder?.map { $0.type }
            dynamicItems = try container.decodeIfPresent(TypeDecoder.self, forKey: .dynamicItems)?.type
        }

        func encode(to encoder: any Encoder) throws {
            throw EncodingError.unsupported
        }

        static func == (lhs: ArrayType, rhs: ArrayType) -> Bool {
            // TODO Implement!!
            return false
            //        if lhs.args == nil && rhs.args == nil {
            //            return true
            //        }
            //
            //        guard let lArgs = lhs.args else {
            //            return false
            //        }
            //        guard let rArgs = rhs.args else {
            //            return false
            //        }
            //
            //        return zip(lArgs, rArgs).allSatisfy { (elem) -> Bool in
            //            let (l, r) = elem
            //            return l.isEqual(to: r)
            //        }
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct BooleanType: Type, Codable {
        let type = KnownTypes.boolean

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct FunctionType: Type, Codable {
        let type = KnownTypes.function

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct NullType: Type, Codable {
        let type = KnownTypes.null

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct NumberType: Type, Codable {
        let type = KnownTypes.number

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct ObjectType: Type, Codable {
        let type = KnownTypes.object
        var staticProps: [StaticProperty]?
        var dynamicProps: DynamicProperty?

        enum CodingKeys: String, CodingKey {
            case staticProps = "static"
            case dynamicProps = "dynamic"
        }

        static func == (lhs: ObjectType, rhs: ObjectType) -> Bool {
            // TODO Implement!!
            return false
            //        if lhs.args == nil && rhs.args == nil {
            //            return true
            //        }
            //
            //        guard let lArgs = lhs.args else {
            //            return false
            //        }
            //        guard let rArgs = rhs.args else {
            //            return false
            //        }
            //
            //        return zip(lArgs, rArgs).allSatisfy { (elem) -> Bool in
            //            let (l, r) = elem
            //            return l.isEqual(to: r)
            //        }
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }

    }

    struct StaticProperty: Codable {
        var key: String  // TODO????
        var value: any Type

        enum CodingKeys: String, CodingKey {
            case key
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try container.decode(String.self, forKey: .key)
            value = try container.decode(TypeDecoder.self, forKey: .value).type
        }

        func encode(to encoder: any Encoder) throws {
            throw EncodingError.unsupported
        }
        // TODO equatable
    }

    struct DynamicProperty: Codable {
        var key: any Type
        var value: any Type

        enum CodingKeys: String, CodingKey {
            case key
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try container.decode(TypeDecoder.self, forKey: .key).type
            value = try container.decode(TypeDecoder.self, forKey: .value).type
        }

        func encode(to encoder: any Encoder) throws {
            throw EncodingError.unsupported
        }
        // TODO equatable
    }

    struct SetType: Type, Codable {
        let type = KnownTypes.set

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    struct StringType: Type, Codable {
        let type = KnownTypes.set

        init(from decoder: Decoder) throws {
        }

        func isEqual(to other: any Type) -> Bool {
            guard let rhs = other as? Self else {
                return false
            }
            return self == rhs
        }
    }

    enum IRType {
        case any(AnyType)
        case array(ArrayType)
        case boolean(BooleanType)
        case function(FunctionType)
        case null(NullType)
        case number(NumberType)
        case object(ObjectType)
        case set(SetType)
        case string(StringType)
    }
}

enum KnownTypes: String, Codable {
    case any = "any"
    case array = "array"
    case boolean = "boolean"
    case function = "function"
    //case namedType = "named_type"
    case null = "null"
    case number = "number"
    case object = "object"
    case set = "set"
    case string = "string"
}

// TypeDecoder is used for partial decoding of polymorphic types
// to determine the concrete type, which is then decoded in the type member.
struct TypeDecoder: Decodable {
    var typeMarker: KnownTypes
    var type: any Type

    private enum CodingKeys: String, CodingKey {
        case typeMarker = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeMarker = try container.decode(KnownTypes.self, forKey: .typeMarker)

        switch typeMarker {
        case .any:
            type = try types.AnyType(from: decoder)
        case .array:
            type = try types.ArrayType(from: decoder)
        case .boolean:
            type = try types.BooleanType(from: decoder)
        case .function:
            type = try types.FunctionType(from: decoder)
        case .null:
            type = try types.NullType(from: decoder)
        case .number:
            type = try types.NumberType(from: decoder)
        case .object:
            type = try types.ObjectType(from: decoder)
        case .set:
            type = try types.SetType(from: decoder)
        case .string:
            type = try types.StringType(from: decoder)
        }
    }
}

// Statement is implemented by each conctete statement type
protocol Type: Sendable, Equatable {
    var type: KnownTypes { get }

    // This will be used to implement Equatable dynamically between heterogenous types
    func isEqual(to other: any Type) -> Bool
}

