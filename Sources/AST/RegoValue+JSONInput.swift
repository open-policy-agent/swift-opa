import Foundation

extension RegoValue {
    /// Errors from validating raw JSON before converting it into a RegoValue.
    public enum JSONInputError: Error, Equatable, CustomStringConvertible, LocalizedError {
        /// An object repeats a key, including keys equal after unescaping or Unicode normalization.
        case duplicateObjectKeys
        /// The input contained a NUL byte. Only UTF-8 JSON is supported, as in OPA.
        case nulByte
        /// A number is too large or too small to convert to `Decimal`.
        case numberOutOfRange

        public var description: String {
            switch self {
            case .duplicateObjectKeys:
                return "JSON object contains duplicate keys"
            case .nulByte:
                return "JSON input contains a NUL byte (only UTF-8 JSON is supported)"
            case .numberOutOfRange:
                return "JSON number is outside the supported range"
            }
        }

        public var errorDescription: String? { description }
    }

    /// Runs `parse`, rejecting raw JSON that has a NUL byte or duplicate object keys.
    /// Duplicates are only reported if the `parse` succeeds.
    package static func parseRejectingDuplicateKeys<T>(_ data: Data, _ parse: () throws -> T) throws -> T {
        let scan = scanJSONObjectKeys(data)
        if scan == .nulByte {
            throw JSONInputError.nulByte
        }
        let value = try parse()
        if scan == .duplicate {
            throw JSONInputError.duplicateObjectKeys
        }
        return value
    }

    /// Decodes JSON with JSONDecoder, rejecting duplicate object keys the same way as `init(jsonData:)`.
    /// Unlike `init(jsonData:)`, top-level scalars are accepted and numbers are parsed as exact decimals.
    package static func decodeRejectingDuplicateKeys(json data: Data) throws -> RegoValue {
        try decodeRejectingDuplicateKeys(RegoValue.self, json: data)
    }

    /// Decodes `type` with JSONDecoder, rejecting NUL bytes and duplicate object keys.
    package static func decodeRejectingDuplicateKeys<T: Decodable>(_ type: T.Type, json data: Data) throws -> T {
        try parseRejectingDuplicateKeys(data) { try JSONDecoder().decode(T.self, from: data) }
    }
}
