import Foundation

extension RegoValue {
    /// Errors from validating raw JSON before converting it into a RegoValue.
    public enum JSONInputError: Error, Equatable, CustomStringConvertible, LocalizedError {
        /// Keys in an object collapsed into one entry, including keys equal after unescaping or Unicode normalization.
        case duplicateObjectKeys
        /// The input contained a NUL byte. Only UTF-8 JSON is supported, as in OPA.
        case nulByte
        /// The parser produced more object members than the raw bytes contain. This is an internal error, and should be impossible.
        case memberCountMismatch(scanned: Int, parsed: Int)

        public var description: String {
            switch self {
            case .duplicateObjectKeys:
                return "JSON object contains duplicate keys"
            case .nulByte:
                return "JSON input contains a NUL byte (only UTF-8 JSON is supported)"
            case .memberCountMismatch(let scanned, let parsed):
                return "internal error: JSON parser produced \(parsed) object members, but the input has \(scanned)"
            }
        }

        public var errorDescription: String? { description }
    }

    /// Decodes JSON with JSONDecoder, rejecting duplicate object keys the same way as `init(jsonData:)`.
    /// Unlike `init(jsonData:)`, top-level scalars are accepted and numbers are parsed as exact decimals.
    package static func decodeRejectingDuplicateKeys(json data: Data) throws -> RegoValue {
        guard let scanned = jsonObjectMemberCount(data) else {
            throw JSONInputError.nulByte
        }
        let value = try JSONDecoder().decode(RegoValue.self, from: data)
        try checkObjectMembers(scanned: scanned, parsed: value.objectMemberCount)
        return value
    }

    /// Throws if raw JSON has duplicate object keys, for callers that decode it into another type.
    /// Uses JSONSerialization without building RegoValues, since only the entry counts are needed.
    package static func checkForDuplicateKeys(json data: Data) throws {
        let scanned = try scannedMembers(data)
        let parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        try checkObjectMembers(scanned: scanned, parsed: foundationObjectMemberCount(parsed))
    }

    /// Throws if raw JSON has duplicate object keys, given its JSONSerialization result.
    package static func checkForDuplicateKeys(json data: Data, parsed: Any) throws {
        try checkObjectMembers(scanned: try scannedMembers(data), parsed: foundationObjectMemberCount(parsed))
    }

    private static func scannedMembers(_ data: Data) throws(JSONInputError) -> Int {
        guard let scanned = jsonObjectMemberCount(data) else {
            throw .nulByte
        }
        return scanned
    }

    /// Fewer parsed members than scanned means keys collapsed together.
    static func checkObjectMembers(scanned: Int, parsed: Int) throws(JSONInputError) {
        if parsed < scanned {
            throw .duplicateObjectKeys
        }
        if parsed > scanned {
            throw .memberCountMismatch(scanned: scanned, parsed: parsed)
        }
    }

    /// The total number of entries across every object in this value.
    var objectMemberCount: Int {
        switch self {
        case .object(let o):
            return o.reduce(o.count) { $0 + $1.value.objectMemberCount }
        case .array(let a):
            return a.reduce(0) { $0 + $1.objectMemberCount }
        case .set(let s):
            return s.reduce(0) { $0 + $1.objectMemberCount }
        default:
            return 0
        }
    }
}

/// Counts object members in raw JSON as the `:` bytes outside of strings, or returns nil on a NUL byte.
/// This works for UTF-8 JSON on all platforms.
func jsonObjectMemberCount(_ data: Data) -> Int? {
    let quote = UInt8(ascii: "\"")
    let backslash = UInt8(ascii: "\\")
    let colon = UInt8(ascii: ":")
    return data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Int? in
        var members = 0
        var inString = false
        var escaped = false
        for b in buf {
            if b == 0 {
                return nil
            }
            if inString {
                if escaped {
                    escaped = false
                } else if b == backslash {
                    escaped = true
                } else if b == quote {
                    inString = false
                }
            } else if b == quote {
                inString = true
            } else if b == colon {
                members += 1
            }
        }
        return members
    }
}

/// Counts entries across every object in a JSONSerialization result, for `checkForDuplicateKeys`.
/// Bridging to `[String: Any]` merges canonically equivalent keys, as JSONDecoder does.
private func foundationObjectMemberCount(_ value: Any) -> Int {
    switch value {
    case let object as [String: Any]:
        return object.reduce(object.count) { $0 + foundationObjectMemberCount($1.value) }
    case let array as [Any]:
        return array.reduce(0) { $0 + foundationObjectMemberCount($1) }
    default:
        return 0
    }
}
