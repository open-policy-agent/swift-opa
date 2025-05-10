import AST
import Foundation
import IR
import Rego

public struct ComplianceTesting {
    // Compliance test suite generated from upstream cases
    // https://github.com/open-policy-agent/opa/tree/main/v1/test/cases/testdata/v1
    // https://github.com/open-policy-agent/opa/tree/97b8572fdc79f6fb433c53aaa013a586dd476615/v1/test/cases/testdata/v1

    public struct TestCases: Codable {
        public var filename: String?
        public var cases: [ComplianceTestCase]

        init(from data: Data, withURL url: URL) throws {
            self = try JSONDecoder().decode(Self.self, from: data)

            // Use last two path components as the filename
            self.filename = url.pathComponents.suffix(from: url.pathComponents.endIndex.advanced(by: -2)).joined(
                separator: "/"
            )
        }

        init(filename: String?, cases: [ComplianceTestCase]) {
            self.filename = filename
            self.cases = cases
        }

        // filtered returns a new TestCases, with its cases filtered by predicate
        func filtered(_ predicate: (ComplianceTestCase) -> Bool) -> TestCases {
            return .init(
                filename: self.filename,
                cases: self.cases.filter(predicate)
            )
        }
    }

    // ComplianceTestCase is the serialized model that the upstream compliance test tooling
    // generates. Each one of these potentially contains >1 entrypoint, which we'll treat
    // as a distinct IRTestCase.
    public struct ComplianceTestCase: Codable, Sendable {
        public var filename: String?  // name of file that case was loaded from
        public var note: String  // globally unique identifier for this test case
        public var query: String = ""  // policy query to execute
        public var modules: [String]?  // policies to test against
        public var data: AST.RegoValue? = .object([:])  // data to test against
        public var input: AST.RegoValue? = .object([:])  // parsed input data to use
        public var inputTerm: String?  // raw input data (serialized as a string, overrides input)
        public var wantDefined: Bool? = false  // expect query result to be defined (or not)
        public var wantResult: AST.RegoValue? = .object([:])  // expect query result (overrides defined)
        public var wantErrorCode: String?  // expect query error code (overrides result)
        public var wantError: String?  // expect query error message (overrides error code)
        public var sortBindings: Bool? = false  // indicates that binding values should be treated as sets
        public var strictError: Bool? = false  // indicates that the error depends on strict builtin error mode

        public var plan: IR.Policy
        public var entrypoints: [String]? = []
        public var wantPlanResult: AST.RegoValue = .object([:])

        public enum CodingKeys: String, CodingKey {
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

        public enum Error: Swift.Error {
            case decodingFailed(filename: String, error: Swift.Error)
        }
    }

    // IRTestCase represents a single IR evaluation (ie, entrypoint) within a ComplianceTestCase
    // which shares a single source "topdown" test case.
    public struct IRTestCase: Sendable {
        public var entrypoint: String
        public var expected: RegoValue?
        public var base: ComplianceTestCase

        public init(entrypoint: String, expected: RegoValue? = nil, base: ComplianceTestCase) {
            self.entrypoint = entrypoint
            self.expected = expected
            self.base = base
        }

        public var description: String {
            return "\(self.base.filename ?? ""): \(self.base.note) -> \(self.entrypoint)"
        }
    }

    public struct TestConfig {
        public let knownIssues: [KnownIssue]
        public let skipKnownIssues: Bool
        public let sourceURL: URL
        public let traceLevel: OPA.Trace.Level
        public let testFilter: TestFilter

        public init(
            knownIssues: [KnownIssue] = [],
            skipKnownIssues: Bool = false,
            sourceURL: URL,
            testFilter: String? = nil,
            traceLevel: OPA.Trace.Level = .none
        ) throws {
            self.knownIssues = knownIssues
            self.skipKnownIssues = skipKnownIssues
            self.sourceURL = sourceURL
            self.testFilter = try TestFilter(from: testFilter ?? "")
            self.traceLevel = traceLevel
        }
    }

    public struct ComplianceTestURL {
        public let url: URL
    }

    // filteredTestDescriptors is the root of our test case pipeline - it returns the (filtered)
    // urls for files containing relevant test cases.
    private static func filteredTestDescriptors(_ config: TestConfig) throws -> [ComplianceTestURL] {
        let index = try CaseIndex.load(fromURL: config.sourceURL.appending(path: "TestData/index.json"))
        return index.filter(withFilter: config.testFilter, andBase: config.sourceURL).map { ComplianceTestURL(url: $0) }
    }

    // casesFromAllFiles returns the (filtered) relevant test cases
    private static func casesFromAllFiles(_ config: TestConfig) throws -> [TestCases] {
        var out: [TestCases] = []
        for url in try filteredTestDescriptors(config).map({ $0.url }) {
            let raw = try Data(contentsOf: url)

            do {
                let parsed = try TestCases(from: raw, withURL: url)

                // Optionally filter out any cases that don't match our configured pattern
                let filtered = parsed.filtered { testCase in
                    guard let pattern = config.testFilter.note else {
                        return true
                    }
                    return testCase.note.contains(pattern)
                }

                out.append(filtered)
            } catch {
                throw ComplianceTestCase.Error.decodingFailed(
                    filename: url.pathComponents.suffix(from: url.pathComponents.endIndex.advanced(by: -2)).joined(
                        separator: "/"
                    ),
                    error: error
                )
            }
        }
        return out
    }

    // allCases flattens out all the cases nested within all the TestCases
    // across all the conformance test files.
    public static func loadAllTestCases(_ config: TestConfig) throws -> [IRTestCase] {
        return try casesFromAllFiles(config).flatMap {
            let filename = $0.filename

            // Splice in the filename to each of the TestCase instances
            let cases = try $0.cases.compactMap {
                var tc = $0
                tc.filename = filename

                // Split the test case up into IRTestCases for each entrypoint defined.
                // This requires pulling out the extected value from the parent test case results.
                let eps = tc.entrypoints ?? []
                guard eps.count == 1 else {
                    throw Error.loadFailed(
                        reason:
                            "Expected exactly one entrypoint per test case, but found \(eps.count) in \(filename ?? "<unknown>")"
                    )
                }

                guard let entrypoint = tc.entrypoints?.first else {
                    throw Error.loadFailed(
                        reason:
                            "Expected exactly one entrypoint per test case, but found \(eps.count) in \(filename ?? "<unknown>")"
                    )
                }

                return IRTestCase(entrypoint: entrypoint, expected: tc.wantPlanResult, base: tc)
            }
            return cases
        }
    }

    public struct IRTestResult {
        public var testCase: IRTestCase
        public var error: Error?
        public var trace: OPA.Trace.BufferedQueryTracer?
        public var knownIssue: String?
    }

    public static func runTest(config: TestConfig, _ tc: IRTestCase) async -> IRTestResult {
        var testResult = IRTestResult(testCase: tc)

        for knownIssue in config.knownIssues {
            // TODO: we should stash these regex's somewhere else.. temporary (or not?) we just remake them each test case
            do {
                let regex = try Regex(knownIssue.tests)
                if try regex.firstMatch(in: tc.description) != nil {
                    testResult.knownIssue = knownIssue.reason
                    if config.skipKnownIssues {
                        testResult.error = Error.skipped(reason: knownIssue.reason)
                        return testResult
                    }
                    break
                }
            } catch {
                // ignore the regex error, the test will probably fail
            }
        }

        let store = OPA.InMemoryStore(
            initialData: .object([
                .string("data"): tc.base.data ?? [:]
            ])
        )

        var engine = OPA.Engine(policies: [tc.base.plan], store: store)

        // The logic - ignore query and want.
        // We care about entrypoints and want_plan_result, which have been teased out to
        // top level fields of the IRTestCase.
        // We do however care about the various error flags/states specified on
        // the base ComplianceTestCase.

        let query = entrypointToQuery(tc.entrypoint)
        let tracer = OPA.Trace.BufferedQueryTracer(level: config.traceLevel)
        let wantError = (tc.base.wantError != nil) || (tc.base.wantErrorCode != nil)
        let wantErrorMsg = "expected error \(tc.base.wantError ?? "") / \(tc.base.wantErrorCode ?? "")"

        // Input comes in two flavors. We have the "input" which is JSON and already parsed, and we have
        // "input_term" which is raw Rego. Because we can't parse Rego yet we're likely not going to pass
        // the test (tracking them separately with known issues in the config).
        // As a short-term (lol) hack, we'll try to parse it as JSON, if it succeeds we use it. A bunch
        // of the "input_term"'s appear to be conformant to JSON so it gets us a little further on testing.
        var input = tc.base.input ?? .undefined
        if let inputTerm = tc.base.inputTerm {
            let jsonData = inputTerm.data(using: .utf8)!
            do {
                input = try JSONDecoder().decode(RegoValue.self, from: jsonData)
            } catch {
                // ignore the error..
            }
        }

        // Leave it up to the caller to ignore the trace output
        // TODO: We probably want to wire in like a log stream/output thing and dump the trace in to.
        // There seems to be some missing trick to get the output into a string buffer using Pipe, so
        // for now we just send along the whole tracer.
        testResult.trace = tracer

        do {
            let actualResult = try await engine.prepareForEvaluation(query: query).evaluate(
                input: input,
                tracer: tracer,
                strictBuiltins: tc.base.strictError ?? false
            )

            guard !wantError else {
                // Wanted an error but got none
                testResult.error = Error.testFailed(reason: wantErrorMsg + " but got no error")
                return testResult
            }

            // AST.RegoValue is higher-fidelity than what can be represented in the JSON of our test expectations.
            // Specifically, sets do not exist in JSON, and will be represented as arrays. Additionally, JSON
            // only supports strings as keys, so any non-string key would need to be stringified.
            // Handle all these conversions, as well as sorting of top-level arrays ({"x": [0, 1, 2]}) if
            // required by the test case.
            let arr: [AST.RegoValue] = try actualResult.sorted().map { bindings in
                try simplifyRegoToJson(bindings, sortTopLevel: tc.base.sortBindings ?? false)
            }
            let translated: AST.RegoValue = .array(arr)

            guard let expected = tc.expected else {
                throw Error.noResultExpectations
            }

            guard case .array(let expectedArray) = expected else {
                throw Error.unexpectedExpectedResultType(got: expected.typeName, want: "array")
            }

            let expectedSorted: RegoValue = .array(expectedArray.sorted())

            guard expectedSorted == translated else {
                testResult.error = Error.testAssertionFailed(expected: expectedSorted, actual: translated)
                return testResult
            }
            // success
        } catch {
            guard wantError else {
                // Got an error we didn't expect
                testResult.error = Error.testFailed(
                    reason: "unexpected evaluation error: \(String(describing: error))",
                    error: error
                )
                return testResult
            }
            // TODO: Validate what error we got?
            // success
        }

        return testResult
    }

    // entrypointToQuery converts from entrypoint "foo/bar/baz" format to query
    // format, e.g. "data.foo.bar.baz", which is what the evaluator expects.
    static func entrypointToQuery(_ entrypoint: String) -> String {
        let parts: [Substring] = ["data"] + entrypoint.split(separator: "/")
        return parts.joined(separator: ".")
    }

    // simplifyRegoToJson returns the provided RegoValue, translated recursively
    // such that sets are translated into sorted arrays, non-string keys are stringified,
    // and if requested, arrays at the top level (or children of a top-level object)
    // are sorted.
    // This will allow comparing to JSON-sourced RegoValues (our test expectations),
    // which are lower fidelity than the full spectrum of what RegoValue can represent.
    static func simplifyRegoToJson(_ v: AST.RegoValue, sortTopLevel: Bool = false) throws -> AST.RegoValue {
        switch v {
        case .array(let arr):
            var arr = try arr.map { try simplifyRegoToJson($0) }
            if sortTopLevel {
                arr.sort()
            }
            return .array(arr)

        case .object(let o):
            let newObj: [AST.RegoValue: AST.RegoValue] = try o.reduce(
                into: [:],
                { out, e in
                    // If we should be sorting top-level bindings, pass that along
                    // to values of the top level object that are arrays.
                    let valueIsArray = if case .array = e.value { true } else { false }
                    let sortNextLevel = sortTopLevel && valueIsArray
                    let k = try String(e.key)  // Stringify potentially non-string keys
                    out[.string(k)] = try simplifyRegoToJson(e.value, sortTopLevel: sortNextLevel)
                }
            )
            return AST.RegoValue.object(newObj)

        case .set(let s):
            return .array(try s.map { try simplifyRegoToJson($0) }.sorted())

        default:
            return v
        }
    }

    public enum Error: Swift.Error {
        case loadFailed(reason: String)
        case skipped(reason: String)
        case testFailed(reason: String, error: Swift.Error? = nil)
        case testAssertionFailed(expected: RegoValue, actual: RegoValue)
        case translationFailed(reason: String)
        case noResultExpectations
        case unexpectedExpectedResultType(got: String, want: String)
    }
}
