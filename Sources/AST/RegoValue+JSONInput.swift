import Foundation

extension RegoValue {
    /// Errors from validating raw JSON before converting it into a RegoValue.
    public enum JSONInputError: Error, Equatable, CustomStringConvertible, LocalizedError {
        /// An object repeats a key, including keys equal after unescaping or Unicode normalization.
        case duplicateObjectKeys
        /// The input contained a NUL byte. Only UTF-8 JSON is supported, as in OPA.
        case nulByte

        public var description: String {
            switch self {
            case .duplicateObjectKeys:
                return "JSON object contains duplicate keys"
            case .nulByte:
                return "JSON input contains a NUL byte (only UTF-8 JSON is supported)"
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
        try parseRejectingDuplicateKeys(data) { try JSONDecoder().decode(RegoValue.self, from: data) }
    }

    /// Throws if raw JSON has a NUL byte or duplicate object keys, for callers that decode it some other way.
    package static func checkForDuplicateKeys(json data: Data) throws {
        switch scanJSONObjectKeys(data) {
        case .unique: return
        case .duplicate: throw JSONInputError.duplicateObjectKeys
        case .nulByte: throw JSONInputError.nulByte
        }
    }
}
