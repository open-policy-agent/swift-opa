import AST
import Foundation
import Testing

@testable import Rego

// JSONObject and the custom decoders are Darwin-only.
#if canImport(Darwin)

    // The custom manifest decoder must decode exactly as the Decodable conformance does.
    @Suite
    struct ManifestJSONObjectTests {
        @Test(arguments: [
            "{}",
            #"{"revision":"r1","roots":["a","b/c"],"rego_version":1,"metadata":{"k":[1,2.5,"x",null,true,{}]}}"#,
            #"{"roots":[]}"#,
            #"{"roots":null}"#,
            #"{"roots":[1]}"#,
            #"{"roots":"a"}"#,
            #"{"revision":null}"#,
            #"{"revision":1}"#,
            #"{"rego_version":0}"#,
            #"{"rego_version":2}"#,
            #"{"rego_version":1.0}"#,
            #"{"rego_version":1.5}"#,
            #"{"rego_version":"1"}"#,
            #"{"rego_version":true}"#,
            #"{"rego_version":null}"#,
            #"{"metadata":null}"#,
            #"{"metadata":"text"}"#,
            #"{"unknown":{"nested":[1,2]}}"#,
            "[]",
            #""manifest""#,
            "null",
        ])
        func decodesLikeJSONDecoder(json: String) {
            let data = Data(json.utf8)
            let expected = Result { try JSONDecoder().decode(OPA.Manifest.self, from: data) }
            let got = Result { try OPA.Manifest(from: data) }
            switch (expected, got) {
            case (.success(let e), .success(let g)):
                #expect(e == g, "\(json)")
            case (.failure, .failure):
                break
            default:
                Issue.record("\(json): JSONDecoder \(expected), JSONObject \(got)")
            }
        }
    }

#endif
