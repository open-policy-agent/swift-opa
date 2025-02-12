import AST
import Foundation
import IR
import Testing

@testable import Rego

extension Tag {
    @Tag static var compliance: Self
}

private let complianceFilterFlag = "OPA_COMPLIANCE_TESTS"
private let complianceTraceLevelFlag = "OPA_COMPLIANCE_TRACE"

// Feature flag compliance tests, set OPA_COMPLIANCE_TESTS=... to run
func complianceEnabled() -> Bool {
    return ProcessInfo.processInfo.environment[complianceFilterFlag] != nil
}

// Compliance test suite generated from upstream cases
// https://github.com/open-policy-agent/opa/tree/main/v1/test/cases/testdata/v1
// https://github.com/open-policy-agent/opa/tree/97b8572fdc79f6fb433c53aaa013a586dd476615/v1/test/cases/testdata/v1

@Suite("Compliance Tests", .tags(.compliance), .enabled(if: complianceEnabled()), .serialized)
struct ComplianceTests {
    // testFilter is an environment-variable based mechanism for running only
    // conformance tests from files matching the filter.
    // To set a filter, set OPA_COMPLIANCE_TESTS to the filenames to include tests from.
    // (note: filenames must have a .json extension)
    static var testFilter: String? {
        let v = ProcessInfo.processInfo.environment[complianceFilterFlag]
        guard let v else {
            return nil
        }
        if !v.hasSuffix(".json") {
            return nil
        }
        return v
    }

    // Feature flag controlling compliance test trace level [none|full]
    static var complianceTraceLevel: TraceLevel {
        let v = ProcessInfo.processInfo.environment[complianceTraceLevelFlag]
        guard let v else {
            return .none
        }
        return switch v.lowercased() {
        case "full":
            .full
        default:
            .none
        }
    }

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
                // If a filter was set, skip non-matching files
                if let testFilter {
                    if url.lastPathComponent != testFilter {
                        continue
                    }
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
        var data: AST.RegoValue? = .object([:])  // data to test against
        var input: AST.RegoValue? = .object([:])  // parsed input data to use
        var inputTerm: String?  // raw input data (serialized as a string, overrides input)
        var wantDefined: Bool? = false  // expect query result to be defined (or not)
        var wantResult: AST.RegoValue? = .object([:])  // expect query result (overrides defined)
        var wantErrorCode: String?  // expect query error code (overrides result)
        var wantError: String?  // expect query error message (overrides error code)
        var sortBindings: Bool? = false  // indicates that binding values should be treated as sets
        var strictError: Bool? = false  // indicates that the error depends on strict builtin error mode

        var plan: IR.Policy
        var entrypoints: [String]? = []
        var wantPlanResult: AST.RegoValue = .object([:])

        enum CodingKeys: String, CodingKey {
            case note = "note"
            case modules = "modules"
            case data = "data"
            case input = "input"
            case inputTerm = "input_term"
            case wantDefined = "want_defined"
            case wantResult = "want_result"
            case wantErrorCode = "want_error_code"
            case wantError = "want_error"
            case sortBindings = "sort_bindings"
            case strictError = "strict_error"

            case plan = "plan"
            case entrypoints = "entrypoints"
            case wantPlanResult = "want_plan_result"
        }

        enum Error: Swift.Error {
            case decodingFailed(filename: String, error: Swift.Error)
        }
    }

    @Test(arguments: try allCases)
    func testCompliance(tc: TestCase) async throws {
        let store = InMemoryStore(
            initialData: .object([
                .string("data"): tc.data ?? [:]
            ]))
        let engine = Engine(withPolicies: [tc.plan], andStore: store)

        // The logic - ignore query and want.
        // We care about entrypoints and want_plan_result.
        // We will evaluate each entrypoint (as a query) separately,
        // and combine their results into a single result tree.

        let queries = tc.entrypoints?.map(entrypointToQuery) ?? []

        queryLoop: for query in queries {
            print("\t🧬executing \(tc.testDescription) (\(query))")

            let input = tc.input ?? [:]

            let level = ComplianceTests.complianceTraceLevel
            let tracer = BufferedQueryTracer(level: level)

            do {
                let wantError = (tc.wantError != nil) || (tc.wantErrorCode != nil)

                var resultSet: ResultSet

                if wantError {
                    let wantErrorMsg = "expected error \(tc.wantError ?? "") / \(tc.wantErrorCode ?? "")"

                    try await #require(throws: (any Swift.Error).self, "\(wantErrorMsg)") {
                        _ = try await engine.evaluate(query: query, input: input, tracer: tracer)
                    }
                    // TODO does wantError apply to all entrypoints in the tests?
                    continue queryLoop
                } else {
                    resultSet = try await engine.evaluate(query: query, input: input, tracer: tracer)
                }

                // Aggregate the result sets
                try #require(resultSet.count == 1, "expected single result")
                let resultObj: AST.RegoValue = resultSet.first!
                guard case .object(let result) = resultObj else {
                    throw Error.testFailed(reason: "unexpected result type \(resultObj)")
                }
                let innerResult = result[.string("result")] ?? .object([:])
                let translated = translateSetsToArrays(innerResult)  // translate away any sets so we can compare below

                // The test generator (https://github.com/borgeby/opa-compliance-test) will encode each
                // entrypoint expected output into wantPlanResult, transorming the entrypoint to an underscore-delimited key,
                // e.g. opa/example -> data_opa_example
                let key = queryToResultsKey(query)

                guard case .object(let wantPlanResult) = tc.wantPlanResult else {
                    throw Error.testFailed(reason: "unexpected wantPlanResult type \(tc.wantPlanResult)")
                }

                let expected = wantPlanResult[.string(key)]

                try #require(translated == expected, "comparing results for \(query)")
            } catch {
                print("\t❌ \(tc.testDescription) (\(query))")
                tracer.prettyPrint(out: .standardOutput)
                throw error
            }
            print("\t✅ \(tc.testDescription) (\(query))")
        }
    }

    // entrypointToQuery converts from entrypoint "foo/bar/baz" format to query
    // format, e.g. "data.foo.bar.baz", which is what the evaluator expects.
    func entrypointToQuery(_ entrypoint: String) -> String {
        let parts: [Substring] = ["data"] + entrypoint.split(separator: "/")
        return parts.joined(separator: ".")
    }

    func queryToResultsKey(_ entrypoint: String) -> String {
        return entrypoint.replacingOccurrences(of: ".", with: "_")
    }

    // translateSetsToArrays returns the provided RegoValue, translated recursively
    // such that any sets are translated into sorted arrays.
    // This will allow comparing to parsed RegoValues, where sets are not round-tripped.
    func translateSetsToArrays(_ v: AST.RegoValue) -> AST.RegoValue {
        switch v {
        case .array(let arr):
            return .array(arr.map { translateSetsToArrays($0) })

        case .object(let o):
            let newObj: [AST.RegoValue: AST.RegoValue] = o.reduce(
                into: [:],
                { out, e in
                    let k = translateSetsToArrays(e.key)
                    out[k] = translateSetsToArrays(e.value)
                })
            return AST.RegoValue.object(newObj)

        case .set(let s):
            return .array(s.map { translateSetsToArrays($0) }.sorted())

        default:
            return v
        }
    }

    enum Error: Swift.Error {
        case testFailed(reason: String)
    }
}

// Decoding helpers for ComplianceTests.TestCases
extension ComplianceTests.TestCases {
    init(from data: Data, withURL url: URL) throws {
        self = try JSONDecoder().decode(Self.self, from: data)

        // Use last two path components as the filename
        self.filename = url.pathComponents.suffix(from: url.pathComponents.endIndex.advanced(by: -2)).joined(
            separator: "/")
    }
}

extension ComplianceTests.TestURL: CustomTestStringConvertible {
    var testDescription: String { url.lastPathComponent }
}

extension ComplianceTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { "\(filename ?? ""): \(note)" }
}
