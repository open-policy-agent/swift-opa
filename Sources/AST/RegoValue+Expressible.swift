import Foundation

extension RegoValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = RegoValue

    public init(dictionaryLiteral elements: (String, RegoValue)...) {
        let obj: [RegoValue: RegoValue] = elements.reduce(into: [:]) { o, elem in
            o[.string(elem.0)] = elem.1
        }
        self = .object(obj)
    }
}

extension RegoValue: ExpressibleByArrayLiteral {
    public typealias Element = RegoValue

    public init(arrayLiteral elements: RegoValue...) {
        self = .array(elements)
    }
}

extension RegoValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(RegoNumber(int: Int64(value)))
    }
}

extension RegoValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(RegoNumber(floatLiteral: value))
    }
}

extension RegoValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension RegoValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension RegoValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
