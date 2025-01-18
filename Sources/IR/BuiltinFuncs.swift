import Foundation

public struct BuiltinFunc: Codable, Equatable, Sendable {
    var name: String
    var decl: FunctionDecl
}

public struct FunctionDecl: Codable, Equatable, Sendable {
    // TODO are these really optional?
    var args: [any Type]?
    var result: (any Type)?
    var variadic: (any Type)?

    enum CodingKeys: String, CodingKey {
        case args
        case result
        case variadic
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argsDecoder = try container.decodeIfPresent(
            [TypeDecoder].self,
            forKey: .args)
        args = argsDecoder?.map { $0.type }
        result = try container.decodeIfPresent(TypeDecoder.self, forKey: .result)?.type
        variadic = try container.decodeIfPresent(TypeDecoder.self, forKey: .variadic)?.type
    }

    public func encode(to encoder: any Encoder) throws {
        throw EncodingError.unsupported
    }

    public static func == (lhs: FunctionDecl, rhs: FunctionDecl) -> Bool {
        // TODO compare result and variadic too!!!

        if lhs.args == nil && rhs.args == nil {
            return true
        }

        guard let lArgs = lhs.args else {
            return false
        }
        guard let rArgs = rhs.args else {
            return false
        }

        return zip(lArgs, rArgs).allSatisfy { (elem) -> Bool in
            let (l, r) = elem
            return l.isEqual(to: r)
        }
    }
}

//struct NamedType: Type, Equatable {
//    var type: String
//
//    static func == (lhs: NamedType, rhs: NamedType) -> Bool {
//        return lhs.type.isEqual(rhs.type)
//    }
//
//    var name: String
//    var description: String
//    var type: any Type
//
//    enum CodingKeys: String, CodingKey {
//        case name = "name"
//        case description = "description"
//    }
//
//    func isEqual(to other: any Type) -> Bool {
//        guard let rhs = other as? Self else {
//            return false
//        }
//        return self == rhs
//    }
//}

//struct AnyType: Codable/*, Equatable*/ {
//    enum KnownTypes: String, Codable {
//        case any = "any"
//        case array = "array"
//        case boolean = "boolean"
//        case function = "function"
//        //case namedType = "named_type"
//        case null = "null"
//        case number = "number"
//        case object = "object"
//        case set = "set"
//        case string = "string"
//    }
//    enum CodingKeys: String, CodingKey {
//        case type
//    }
//    var type: KnownTypes
//    var inner: (any Type)
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let peek = container
//
//        let anyType = try peek.decode(AnyType.self, forKey: .type)
//        print(anyType)
//
////        inner = nil
//
////        var iter = try container.nestedUnkeyedContainer(forKey: .statements)
////        var peek = iter
//
//    }
//
//    // Equatable, we need a custom implementation for dynamic dispatch
//    // to our heterogenous extistential type instances (statements)
////    static func == (lhs: Self, rhs: Self) -> Bool {
////        return lhs.isEqual(to: rhs)
////    }
//}
