import AST
import Foundation

// Helpers for encoding a ResultSet

extension ResultSet {
    // jsonString returns a pretty-print encoded representation of the ResultSet.
    public var jsonString: String {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let output = String(data: try encoder.encode(self), encoding: .utf8) else {
                throw RegoValue.RegoEncodingError.invalidUTF8
            }
            return output
        }
    }
}
