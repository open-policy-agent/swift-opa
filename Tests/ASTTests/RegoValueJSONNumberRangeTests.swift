import Foundation
import Testing

@testable import AST

// Doubles too large or too small to convert to Decimal are rejected, instead of loading as a NaN.
@Suite
struct RegoValueJSONNumberRangeTests {
    @Test(arguments: [
        "[1e300]", "[-1e300]", "[1.7976931348623157e308]", "[1e160]", "[5e-324]", "[1e-200]",
        #"{"a":{"b":[1,1e300]}}"#, "[[[1e300]]]",
    ])
    func jsonDataRejectsOutOfRange(json: String) {
        #expect(throws: RegoValue.JSONInputError.numberOutOfRange) {
            try RegoValue(jsonData: Data(json.utf8))
        }
    }

    @Test(arguments: ["[1e100]", "[-1e100]", "[1e-100]", "[0.1]", "[1.5]", "[9223372036854775807]"])
    func jsonDataAcceptsInRange(json: String) throws {
        guard case .array(let a) = try RegoValue(jsonData: Data(json.utf8)), case .number(let n) = a.first else {
            Issue.record("\(json) did not parse to a number")
            return
        }
        #expect(!n.decimalValue.isNaN)
    }

    // JSONSerialization underflows this to 0 before conversion, so it is accepted.
    @Test
    func jsonDataAcceptsUnderflowToZero() throws {
        #expect(try RegoValue(jsonData: Data("[1e-400]".utf8)) == [0])
    }

    #if canImport(Darwin)
        // Manifest metadata is converted from JSONObject members this way.
        @Test
        func jsonObjectMemberRejectsOutOfRange() {
            #expect(throws: RegoValue.JSONInputError.numberOutOfRange) {
                try JSONObject(JSONObject.parse(Data(#"{"v":{"x":[1e300]}}"#.utf8))).decode("v", JSONConvert.regoValue)
            }
        }

        @Test
        func jsonObjectMemberAcceptsInRange() throws {
            let v = try JSONObject(JSONObject.parse(Data(#"{"v":[1e100]}"#.utf8))).decode("v", JSONConvert.regoValue)
            #expect(v != .null)
        }
    #endif

    // json.unmarshal and json.is_valid parse with JSONDecoder, which already rejects these.
    @Test
    func jsonDecoderPathAlsoRejects() {
        #expect(throws: (any Error).self) {
            try RegoValue.decodeRejectingDuplicateKeys(json: Data("[1e300]".utf8))
        }
    }
}
