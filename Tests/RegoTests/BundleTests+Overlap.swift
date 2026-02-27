import AST
import Foundation
import Testing

@testable import Rego

// MARK: - Shared fixtures

/// Expected outcome of a single overlap test case.
enum OverlapExpected {
    case noConflict
    case conflict(collidingBundles: Set<String>, messages: Set<String>)
}

/// A single table-driven overlap test case.
struct OverlapTestCase: CustomStringConvertible {
    let name: String
    /// Map of bundle name -> list of root paths declared in that bundle's manifest.
    let bundles: [String: [String]]
    let expected: OverlapExpected

    var description: String { name }
}

// MARK: - Shared helpers

enum OverlapTestSupport {

    /// Parse a `RegoError` produced by overlap detection back into structured pieces
    /// so we can assert on contents rather than exact formatting.
    ///
    /// Expected message format:
    ///   detected overlapping roots in manifests for these bundles: [a, b, c] (msg1, msg2, ...)
    static func parseConflictError(_ message: String) -> (bundles: Set<String>, messages: Set<String>)? {
        guard let lbrack = message.firstIndex(of: "["),
            let rbrack = message.firstIndex(of: "]"),
            let lparen = message.firstIndex(of: "("),
            let rparen = message.lastIndex(of: ")"),
            lbrack < rbrack, lparen < rparen
        else {
            return nil
        }

        let bundlesPart = message[message.index(after: lbrack)..<rbrack]
        let messagesPart = message[message.index(after: lparen)..<rparen]

        return (splitCSV(bundlesPart), splitCSV(messagesPart))
    }

    private static func splitCSV(_ s: Substring) -> Set<String> {
        Set(
            s.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    /// Build the `[String: OPA.Bundle]` dictionary using a caller-supplied builder.
    static func makeBundleSet(
        _ spec: [String: [String]],
        builder: (_ roots: [String]) throws -> OPA.Bundle
    ) throws -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        for (name, roots) in spec {
            out[name] = try builder(roots)
        }
        return out
    }

    /// Run the assertion phase shared by both suites, given a closure that performs
    /// the operation under test (which is expected to throw on conflict).
    static func assertOutcome(
        _ tc: OverlapTestCase,
        run: () async throws -> Void
    ) async {
        switch tc.expected {
        case .noConflict:
            do {
                try await run()
            } catch let error as RegoError {
                #expect(
                    error.code != .bundleRootConflictError,
                    "case \(tc.name): unexpected overlap conflict: \(error.message)"
                )
            } catch {
                Issue.record("case \(tc.name): unexpected non-Rego error: \(error)")
            }

        case .conflict(let expectedBundles, let expectedMessages):
            do {
                try await run()
                Issue.record("case \(tc.name): expected a conflict error but none was thrown")
            } catch let error as RegoError {
                #expect(
                    error.code == .bundleRootConflictError,
                    "case \(tc.name): wrong error code: \(error.code) — \(error.message)"
                )
                guard let parsed = parseConflictError(error.message) else {
                    Issue.record("case \(tc.name): could not parse error message: \(error.message)")
                    return
                }
                #expect(
                    parsed.bundles == expectedBundles,
                    "case \(tc.name): bundles mismatch — got \(parsed.bundles), want \(expectedBundles)"
                )
                #expect(
                    parsed.messages == expectedMessages,
                    "case \(tc.name): messages mismatch — got \(parsed.messages), want \(expectedMessages)"
                )
            } catch {
                Issue.record("case \(tc.name): unexpected error type: \(error)")
            }
        }
    }
}

// MARK: - Shared test cases

/// Cases that don't depend on engine-vs-unit semantics.
/// Includes the empty-root edge cases — those are meaningful at the overlap-check level.
private let baseOverlapCases: [OverlapTestCase] = [

    // --- No-conflict ---
    .init(
        name: "single bundle, single root",
        bundles: ["a": ["foo"]],
        expected: .noConflict),

    .init(
        name: "two bundles, disjoint roots",
        bundles: ["a": ["foo"], "b": ["bar"]],
        expected: .noConflict),

    .init(
        name: "segment-safe non-overlap (a/b vs a/bc)",
        bundles: ["a": ["a/b"], "b": ["a/bc"]],
        expected: .noConflict),

    .init(
        name: "byte-prefix non-overlap (foo vs foobar)",
        bundles: ["a": ["foo"], "b": ["foobar"]],
        expected: .noConflict),

    .init(
        name: "single bundle declaring overlapping roots is allowed",
        bundles: ["a": ["x", "x/y"]],
        expected: .noConflict),

    // --- Identical roots ---
    .init(
        name: "two bundles share an identical root",
        bundles: ["a": ["foo"], "b": ["foo"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["root foo is in multiple bundles"])),

    .init(
        name: "three bundles share an identical root (single message)",
        bundles: ["a": ["foo"], "b": ["foo"], "c": ["foo"]],
        expected: .conflict(
            collidingBundles: ["a", "b", "c"],
            messages: ["root foo is in multiple bundles"])),

    // --- Prefix overlaps ---
    .init(
        name: "ancestor / descendant overlap (a vs a/b)",
        bundles: ["a": ["a"], "b": ["a/b"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["a overlaps a/b"])),

    .init(
        name: "three-level chain across three bundles",
        bundles: ["a": ["a"], "b": ["a/b"], "c": ["a/b/c"]],
        expected: .conflict(
            collidingBundles: ["a", "b", "c"],
            messages: [
                "a overlaps a/b",
                "a overlaps a/b/c",
                "a/b overlaps a/b/c",
            ])),

    // --- Slash normalization ---
    .init(
        name: "leading and trailing slashes normalize to identical root",
        bundles: ["a": ["/a/"], "b": ["a"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["root a is in multiple bundles"])),

    .init(
        name: "leading slash on descendant still detected",
        bundles: ["a": ["a"], "b": ["/a/b"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["a overlaps a/b"])),

    // --- Multi-root bundles ---
    .init(
        name: "multi-root bundles, only one root collides",
        bundles: ["a": ["x", "y"], "b": ["y", "z"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["root y is in multiple bundles"])),

    .init(
        name: "multi-root bundles, multiple distinct collisions",
        bundles: ["a": ["x", "y/z"], "b": ["x", "y"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: [
                "root x is in multiple bundles",
                "y overlaps y/z",
            ])),
]

/// Empty-root cases — only meaningful for the unit-level check; the engine
/// suite skips them because an empty root collides with `data` semantics.
private let emptyRootCases: [OverlapTestCase] = [
    .init(
        name: "empty root in one bundle conflicts with everything else",
        bundles: ["a": [""], "b": ["anything"]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["overlaps anything"])),

    .init(
        name: "two bundles both with empty root",
        bundles: ["a": [""], "b": [""]],
        expected: .conflict(
            collidingBundles: ["a", "b"],
            messages: ["root  is in multiple bundles"])),
]

// MARK: - Unit-level suite

@Suite("Bundle.checkBundlesForOverlap")
struct BundleOverlapTests {

    static let cases: [OverlapTestCase] = baseOverlapCases + emptyRootCases

    @Test("table-driven overlap checks", arguments: cases)
    func runCase(_ tc: OverlapTestCase) async throws {
        let bundleSet = try OverlapTestSupport.makeBundleSet(tc.bundles) { roots in
            try OPA.Bundle(manifest: OPA.Manifest(roots: roots))
        }

        await OverlapTestSupport.assertOutcome(tc) {
            try OPA.Bundle.checkBundlesForOverlap(bundleSet: bundleSet)
        }
    }
}

// MARK: - Engine-level suite

@Suite("Engine bundle overlap tests")
struct BundleOverlapEngineTests {

    /// Engine suite reuses all the base cases. Empty-root cases are excluded
    /// because `""` collides with the engine's own `data` key path semantics
    /// and isn't a meaningful end-to-end scenario.
    static let cases: [OverlapTestCase] = baseOverlapCases

    /// Minimal, self-contained plan.json reused across all fixture bundles so
    /// the engine has at least one plan to load. Doesn't depend on declared roots.
    static let examplePlanJSON: Data = #"""
        {
          "static": {
            "strings": [{"value": "result"}, {"value": "1"}],
            "files":   [{"value": "bar.rego"}]
          },
          "plans": {
            "plans": [{
              "name": "foo/hello",
              "blocks": [{
                "stmts": [
                  {"type":"CallStmt","stmt":{"func":"g0.data.foo.hello","args":[{"type":"local","value":0},{"type":"local","value":1}],"result":2,"file":0,"col":0,"row":0}},
                  {"type":"AssignVarStmt","stmt":{"source":{"type":"local","value":2},"target":3,"file":0,"col":0,"row":0}},
                  {"type":"MakeObjectStmt","stmt":{"target":4,"file":0,"col":0,"row":0}},
                  {"type":"ObjectInsertStmt","stmt":{"key":{"type":"string_index","value":0},"value":{"type":"local","value":3},"object":4,"file":0,"col":0,"row":0}},
                  {"type":"ResultSetAddStmt","stmt":{"value":4,"file":0,"col":0,"row":0}}
                ]
              }]
            }]
          },
          "funcs": {
            "funcs": [{
              "name": "g0.data.foo.hello",
              "params": [0, 1],
              "return": 2,
              "blocks": [
                {"stmts":[
                  {"type":"ResetLocalStmt","stmt":{"target":3,"file":0,"col":1,"row":3}},
                  {"type":"MakeNumberRefStmt","stmt":{"Index":1,"target":4,"file":0,"col":1,"row":3}},
                  {"type":"AssignVarOnceStmt","stmt":{"source":{"type":"local","value":4},"target":3,"file":0,"col":1,"row":3}}
                ]},
                {"stmts":[
                  {"type":"IsDefinedStmt","stmt":{"source":3,"file":0,"col":1,"row":3}},
                  {"type":"AssignVarOnceStmt","stmt":{"source":{"type":"local","value":3},"target":2,"file":0,"col":1,"row":3}}
                ]},
                {"stmts":[
                  {"type":"ReturnLocalStmt","stmt":{"source":2,"file":0,"col":1,"row":3}}
                ]}
              ],
              "path": ["g0", "foo", "hello"]
            }]
          }
        }
        """#.data(using: .utf8)!

    @Test("engine prepareForEvaluation overlap checks", arguments: cases)
    func runCase(_ tc: OverlapTestCase) async throws {
        let bundleSet = try OverlapTestSupport.makeBundleSet(tc.bundles) { roots in
            try OPA.Bundle(
                manifest: OPA.Manifest(roots: roots),
                planFiles: [
                    BundleFile(
                        url: URL(fileURLWithPath: "/plan.json"),
                        data: Self.examplePlanJSON)
                ],
                regoFiles: [],
                data: .object([:])
            )
        }
        var engine = OPA.Engine(bundles: bundleSet)

        await OverlapTestSupport.assertOutcome(tc) {
            _ = try await engine.prepareForEvaluation(query: "data.foo.hello")
        }
    }
}
