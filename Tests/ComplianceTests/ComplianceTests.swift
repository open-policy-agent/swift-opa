import AST
import Foundation
import IR
import Testing

@testable import Rego

extension Tag {
    @Tag static var compliance: Self
}

// Compliance test suite generated from upstream cases
// https://github.com/open-policy-agent/opa/tree/main/v1/test/cases/testdata/v1
// https://github.com/open-policy-agent/opa/tree/97b8572fdc79f6fb433c53aaa013a586dd476615/v1/test/cases/testdata/v1

@Suite("Compliance Tests", .tags(.compliance))
struct ComplianceTests {
    static var testDescriptors: [TestURL] {
        get throws {
            let enumerator = FileManager.default.enumerator(
                at: Bundle.module.resourceURL!,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey])
            var files: [URL] = []
            for entry in enumerator! {
                guard let url = entry as? URL else {
                    continue
                }
                guard url.lastPathComponent.hasSuffix(".json") else {
                    continue
                }
                // TODO DELETEME filtering out everything except what we want to debug
                guard url.lastPathComponent == "test-example-1070.json" /*"test-functions-0990.json"*/ else {
                    continue
                }
                files.append(url)
            }

            return files.map { TestURL(url: $0) }
        }
    }

    static var casesFromAllFiles: [TestCases] {
        get throws {
            var out: [TestCases] = []
            for url in try testDescriptors.map({ $0.url }) {
                let raw = try Data(contentsOf: url)

                do {
                    let parsed = try TestCases(from: raw, withURL: url)
                    out.append(parsed)
                } catch {
                    throw TestCase.Error.decodingFailed(
                        filename: url.pathComponents.suffix(from: url.pathComponents.endIndex.advanced(by: -2)).joined(
                            separator: "/"),
                        error: error)
                }
            }
            return out
        }
    }

    // allCases flattens out all the cases nested within all the TestCases
    // across all the conformance test files.
    static var allCases: [TestCase] {
        get throws {
            try casesFromAllFiles.flatMap {
                let filename = $0.filename
                let cases = $0.cases

                // Splice in the filename to each of the TestCase instances
                return cases.map {
                    var withFilename = $0
                    withFilename.filename = filename
                    return withFilename
                }
            }
        }
    }

    // TestURL wraps our test arguments to make their descriptions pretty
    struct TestURL {
        var url: URL
    }

    struct TestCases: Codable {
        var filename: String?
        let cases: [TestCase]
    }

    struct TestCase: Codable {
        var filename: String?  // name of file that case was loaded from
        var note: String  // globally unique identifier for this test case
        var query: String = ""  // policy query to execute
        var modules: [String]?  // policies to test against
        var data: AST.RegoValue = .object([:])  // data to test against
        var input: AST.RegoValue = .object([:])  // parsed input data to use
        var inputTerm: String?  // raw input data (serialized as a string, overrides input)
        var wantDefined: Bool? = false  // expect query result to be defined (or not)
        var wantResult: AST.RegoValue = .object([:])  // expect query result (overrides defined)
        var wantErrorCode: String?  // expect query error code (overrides result)
        var wantError: String?  // expect query error message (overrides error code)
        var sortBindings: Bool? = false  // indicates that binding values should be treated as sets
        var strictError: Bool? = false  // indicates that the error depends on strict builtin error mode

        var plan: IR.Policy
        var entrypoints: [String]? = []
        var wantPlanResult: AST.RegoValue = .object([:])

        enum CodingKeys: String, CodingKey {
            case note
            case modules
            case inputTerm
            case wantDefined
            case wantErrorCode
            case wantError
            case sortBindings
            case strictError

            case plan
            case entrypoints
        }
    }

    @Test(arguments: try allCases.lazy.prefix(10))
    func testCompliance(tc: TestCase) async throws {
        let store = InMemoryStore(
            initialData: .object([
                .string("data"): tc.data
            ]))
        let engine = Engine(withPolicies: [tc.plan], andStore: store)

        // The logic - ignore query and want.
        // We care about entrypoints and want_plan_result.
        // We will evaluate each entrypoint (as a query) separately,
        // and combine their results into a single result tree.

        let queries = tc.entrypoints?.map(entrypointToQuery) ?? []

        var allResults: AST.RegoValue = .object([:])
        for query in queries {
            let wantError = (tc.wantError != nil) || (tc.wantErrorCode != nil)

            var resultSet: ResultSet
            if wantError {
                let wantErrorMsg = "expected error \(tc.wantError ?? "") / \(tc.wantErrorCode ?? "")"

                try await #require(throws: (any Swift.Error).self, "\(wantErrorMsg)") {
                    let _ = try await engine.evaluate(query: query, input: tc.input)
                }
                // TODO do we need to verify errors for _all_ entrypoints?
                return
            } else {
                resultSet = try await engine.evaluate(query: query, input: tc.input)
            }

            // Aggregate the result sets
            try #require(resultSet.count == 1, "expected single result")
            let resultObj: AST.RegoValue = resultSet.first!
            guard case .object(let result) = resultObj else {
                throw Error.testFailed
            }
            let innerResult = result[.string("result")] ?? .object([:])

            // TODO this part isn't quite right, we need to transform data.ex to data_ex in the aggregate resultset. Or something.
            allResults = allResults.patch(with: innerResult, at: ["__all__"])
        }

        // allResults should have everything merged under __all__ now:
        print("allResults: \(allResults)")
    }

    // entrypointToQuery converts from entrypoint "foo/bar/baz" format to query
    // format, e.g. "data.foo.bar.baz", which is what the evaluator expects.
    func entrypointToQuery(_ entrypoint: String) -> String {
        let parts: [Substring] = ["data"] + entrypoint.split(separator: "/")
        return parts.joined(separator: ".")
    }

    enum Error: Swift.Error {
        case testFailed
    }
}

extension ComplianceTests.TestCases {
    init(from data: Data, withURL url: URL) throws {
        var cases: [ComplianceTests.TestCase] = []

        // We need to round-trip each case to access its Raw representation
        let d = try JSONSerialization.jsonObject(with: data, options: [])
        guard let jsonDict = d as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON format")
            )
        }

        let casesArray = jsonDict["cases"] as? [Any]
        guard let casesArray else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "expected 'cases' array")
            )
        }

        for c in casesArray {
            // *sigh* round-trip back to Data
            let caseData = try JSONSerialization.data(withJSONObject: c, options: [])

            let tc = try ComplianceTests.TestCase(from: caseData)
            cases.append(tc)
        }

        // Use last two path components as the filename
        self.filename = url.pathComponents.suffix(from: url.pathComponents.endIndex.advanced(by: -2)).joined(
            separator: "/")
        self.cases = cases
    }
}

// Decoding initializers for ComplianceTests.TestCase
extension ComplianceTests.TestCase {
    init(from data: Data) throws {
        // Multi-phase decoding
        self = try JSONDecoder().decode(Self.self, from: data)

        let d = try JSONSerialization.jsonObject(with: data, options: [])

        guard let jsonDict = d as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON format"))
        }

        if let dataTree = jsonDict["data"] {
            self.data = try AST.RegoValue(from: dataTree)
        }

        if let inputTree = jsonDict["input"] {
            self.input = try AST.RegoValue(from: inputTree)
        }

        if let wantPlanResult = jsonDict["want_plan_result"] {
            self.wantPlanResult = try AST.RegoValue(from: wantPlanResult)
        }
    }

    enum Error: Swift.Error {
        case decodingFailed(filename: String, error: Swift.Error)
    }
}

extension ComplianceTests.TestURL: CustomTestStringConvertible {
    var testDescription: String { url.lastPathComponent }
}

extension ComplianceTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { "\(filename ?? ""): \(note)" }
}
