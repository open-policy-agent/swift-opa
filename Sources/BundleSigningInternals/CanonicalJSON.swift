import Foundation

/// Serializes JSON into OPA's canonical form used for bundle-file hashing, matching Go's
/// behavior in `opa`:
///
/// - object keys are sorted recursively by their UTF-8 bytes,
/// - numbers are preserved verbatim as their source literal (like Go's `json.Number`),
/// - strings escape only `"`, `\`, control chars (`< 0x20`), and U+2028/U+2029, with all
///   other bytes (including non-ASCII, `<`, `>`, `&`, `/`, `0x7F`) passing through raw,
/// - no insignificant whitespace.
///
/// This is deliberately independent of `JSONEncoder`, whose number normalization and
/// escaping do not match `opa` and would break cross-tool signature verification.
///
/// Note(philip): The hope is that this will be a temporary hack, until we sort out
/// the intended serdes behaviors for numbers / strings across Rego implementations.
/// Most current edge-cases are exactly that: uncommon things that do not happen often
/// in real policies, but happen often enough for people to have complained about on
/// the OPA issue tracker.
public enum CanonicalJSON {
    enum Error: Swift.Error, Equatable {
        case unexpectedEnd
        case unexpected(offset: Int)
        case invalidNumber(offset: Int)
        case invalidString(offset: Int)
        case invalidEscape(offset: Int)
        case trailingData(offset: Int)
    }

    /// Parses `data` as JSON and returns its canonical byte serialization.
    public static func canonicalize(_ data: Data) throws -> Data {
        var parser = Parser(Array(data))
        let value = try parser.parseDocument()
        var out: [UInt8] = []
        out.reserveCapacity(data.count)
        value.write(to: &out)
        return Data(out)
    }

    indirect enum Value {
        case object([(String, Value)])
        case array([Value])
        case string(String)
        case number([UInt8])  // original literal token bytes
        case bool(Bool)
        case null

        func write(to out: inout [UInt8]) {
            switch self {
            case .object(let pairs):
                out.append(UInt8(ascii: "{"))
                let sorted = pairs.sorted { Array($0.0.utf8).lexicographicallyPrecedes(Array($1.0.utf8)) }
                for (i, pair) in sorted.enumerated() {
                    if i > 0 { out.append(UInt8(ascii: ",")) }
                    CanonicalJSON.writeString(pair.0, to: &out)
                    out.append(UInt8(ascii: ":"))
                    pair.1.write(to: &out)
                }
                out.append(UInt8(ascii: "}"))
            case .array(let items):
                out.append(UInt8(ascii: "["))
                for (i, item) in items.enumerated() {
                    if i > 0 { out.append(UInt8(ascii: ",")) }
                    item.write(to: &out)
                }
                out.append(UInt8(ascii: "]"))
            case .string(let s):
                CanonicalJSON.writeString(s, to: &out)
            case .number(let token):
                out.append(contentsOf: token)
            case .bool(let b):
                out.append(contentsOf: Array((b ? "true" : "false").utf8))
            case .null:
                out.append(contentsOf: Array("null".utf8))
            }
        }
    }

    /// Emits a JSON string literal using OPA's escaping rules.
    static func writeString(_ s: String, to out: inout [UInt8]) {
        out.append(UInt8(ascii: "\""))
        for scalar in s.unicodeScalars {
            switch scalar.value {
            case 0x22: out.append(contentsOf: Array("\\\"".utf8))
            case 0x5C: out.append(contentsOf: Array("\\\\".utf8))
            case 0x08: out.append(contentsOf: Array("\\b".utf8))
            case 0x09: out.append(contentsOf: Array("\\t".utf8))
            case 0x0A: out.append(contentsOf: Array("\\n".utf8))
            case 0x0C: out.append(contentsOf: Array("\\f".utf8))
            case 0x0D: out.append(contentsOf: Array("\\r".utf8))
            case 0x00...0x1F, 0x2028, 0x2029:
                out.append(contentsOf: Array(String(format: "\\u%04x", scalar.value).utf8))
            default:
                out.append(contentsOf: Array(String(scalar).utf8))
            }
        }
        out.append(UInt8(ascii: "\""))
    }

    struct Parser {
        let bytes: [UInt8]
        var i = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        mutating func parseDocument() throws -> Value {
            skipWhitespace()
            let value = try parseValue()
            skipWhitespace()
            guard i == bytes.count else { throw Error.trailingData(offset: i) }
            return value
        }

        mutating func skipWhitespace() {
            while i < bytes.count {
                switch bytes[i] {
                case 0x20, 0x09, 0x0A, 0x0D: i += 1
                default: return
                }
            }
        }

        mutating func parseValue() throws -> Value {
            guard i < bytes.count else { throw Error.unexpectedEnd }
            switch bytes[i] {
            case UInt8(ascii: "{"): return try parseObject()
            case UInt8(ascii: "["): return try parseArray()
            case UInt8(ascii: "\""): return .string(try parseString())
            case UInt8(ascii: "t"):
                try expect("true")
                return .bool(true)
            case UInt8(ascii: "f"):
                try expect("false")
                return .bool(false)
            case UInt8(ascii: "n"):
                try expect("null")
                return .null
            case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return .number(try parseNumber())
            default: throw Error.unexpected(offset: i)
            }
        }

        mutating func expect(_ literal: String) throws {
            for byte in literal.utf8 {
                guard i < bytes.count, bytes[i] == byte else { throw Error.unexpected(offset: i) }
                i += 1
            }
        }

        mutating func parseObject() throws -> Value {
            i += 1  // consume '{'
            var pairs: [(String, Value)] = []
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "}") {
                i += 1
                return .object(pairs)
            }
            while true {
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw Error.unexpected(offset: i) }
                let key = try parseString()
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw Error.unexpected(offset: i) }
                i += 1
                skipWhitespace()
                let value = try parseValue()
                pairs.append((key, value))
                skipWhitespace()
                guard i < bytes.count else { throw Error.unexpectedEnd }
                if bytes[i] == UInt8(ascii: ",") {
                    i += 1
                    continue
                }
                if bytes[i] == UInt8(ascii: "}") {
                    i += 1
                    return .object(pairs)
                }
                throw Error.unexpected(offset: i)
            }
        }

        mutating func parseArray() throws -> Value {
            i += 1  // consume '['
            var items: [Value] = []
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "]") {
                i += 1
                return .array(items)
            }
            while true {
                skipWhitespace()
                items.append(try parseValue())
                skipWhitespace()
                guard i < bytes.count else { throw Error.unexpectedEnd }
                if bytes[i] == UInt8(ascii: ",") {
                    i += 1
                    continue
                }
                if bytes[i] == UInt8(ascii: "]") {
                    i += 1
                    return .array(items)
                }
                throw Error.unexpected(offset: i)
            }
        }

        mutating func parseNumber() throws -> [UInt8] {
            let start = i
            if i < bytes.count, bytes[i] == UInt8(ascii: "-") { i += 1 }
            func consumeDigits() throws {
                let from = i
                while i < bytes.count, bytes[i] >= UInt8(ascii: "0"), bytes[i] <= UInt8(ascii: "9") { i += 1 }
                if i == from { throw Error.invalidNumber(offset: start) }
            }
            try consumeDigits()
            if i < bytes.count, bytes[i] == UInt8(ascii: ".") {
                i += 1
                try consumeDigits()
            }
            if i < bytes.count, bytes[i] == UInt8(ascii: "e") || bytes[i] == UInt8(ascii: "E") {
                i += 1
                if i < bytes.count, bytes[i] == UInt8(ascii: "+") || bytes[i] == UInt8(ascii: "-") { i += 1 }
                try consumeDigits()
            }
            return Array(bytes[start..<i])
        }

        mutating func parseString() throws -> String {
            let start = i
            i += 1  // consume opening quote
            var scalars = String.UnicodeScalarView()
            while i < bytes.count {
                let byte = bytes[i]
                if byte == UInt8(ascii: "\"") {
                    i += 1
                    return String(scalars)
                }
                if byte == UInt8(ascii: "\\") {
                    i += 1
                    guard i < bytes.count else { throw Error.invalidString(offset: start) }
                    switch bytes[i] {
                    case UInt8(ascii: "\""):
                        scalars.append("\"")
                        i += 1
                    case UInt8(ascii: "\\"):
                        scalars.append("\\")
                        i += 1
                    case UInt8(ascii: "/"):
                        scalars.append("/")
                        i += 1
                    case UInt8(ascii: "b"):
                        scalars.append("\u{08}")
                        i += 1
                    case UInt8(ascii: "f"):
                        scalars.append("\u{0C}")
                        i += 1
                    case UInt8(ascii: "n"):
                        scalars.append("\n")
                        i += 1
                    case UInt8(ascii: "r"):
                        scalars.append("\r")
                        i += 1
                    case UInt8(ascii: "t"):
                        scalars.append("\t")
                        i += 1
                    case UInt8(ascii: "u"): try scalars.append(parseUnicodeEscape(start: start))
                    default: throw Error.invalidEscape(offset: i)
                    }
                } else {
                    // Copy a full UTF-8 sequence for this leading byte.
                    let width = Self.utf8Width(byte)
                    guard width > 0, i + width <= bytes.count else { throw Error.invalidString(offset: i) }
                    guard let scalar = Self.decodeScalar(Array(bytes[i..<i + width])) else {
                        throw Error.invalidString(offset: i)
                    }
                    scalars.append(scalar)
                    i += width
                }
            }
            throw Error.invalidString(offset: start)
        }

        /// Parses a `\uXXXX` escape (already past the `u`), handling surrogate pairs.
        mutating func parseUnicodeEscape(start: Int) throws -> Unicode.Scalar {
            i += 1  // consume 'u'
            let high = try readHex4(start: start)
            if high >= 0xD800 && high <= 0xDBFF {
                // Expect a low surrogate.
                guard i + 1 < bytes.count, bytes[i] == UInt8(ascii: "\\"), bytes[i + 1] == UInt8(ascii: "u") else {
                    throw Error.invalidEscape(offset: i)
                }
                i += 2
                let low = try readHex4(start: start)
                guard low >= 0xDC00 && low <= 0xDFFF else { throw Error.invalidEscape(offset: i) }
                let value = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
                guard let scalar = Unicode.Scalar(value) else { throw Error.invalidEscape(offset: i) }
                return scalar
            }
            guard let scalar = Unicode.Scalar(high) else { throw Error.invalidEscape(offset: i) }
            return scalar
        }

        mutating func readHex4(start: Int) throws -> Int {
            guard i + 4 <= bytes.count else { throw Error.invalidEscape(offset: start) }
            var value = 0
            for _ in 0..<4 {
                guard let digit = Self.hexValue(bytes[i]) else { throw Error.invalidEscape(offset: i) }
                value = value << 4 | digit
                i += 1
            }
            return value
        }

        static func hexValue(_ byte: UInt8) -> Int? {
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): return Int(byte - UInt8(ascii: "a")) + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): return Int(byte - UInt8(ascii: "A")) + 10
            default: return nil
            }
        }

        static func utf8Width(_ leadingByte: UInt8) -> Int {
            switch leadingByte {
            case 0x00...0x7F: return 1
            case 0xC0...0xDF: return 2
            case 0xE0...0xEF: return 3
            case 0xF0...0xF7: return 4
            default: return 0
            }
        }

        static func decodeScalar(_ utf8Bytes: [UInt8]) -> Unicode.Scalar? {
            var view = String.UnicodeScalarView()
            var decoder = UTF8()
            var iterator = utf8Bytes.makeIterator()
            switch decoder.decode(&iterator) {
            case .scalarValue(let scalar): view.append(scalar)
            default: return nil
            }
            return view.first
        }
    }
}
