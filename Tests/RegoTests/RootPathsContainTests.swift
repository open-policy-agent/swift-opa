import Foundation
import Testing

@testable import Rego

@Suite
struct RootPathsContainTests {
    struct TestCase {
        let description: String
        let roots: [String]
        let path: String
        let expected: Bool
    }

    static var allTests: [TestCase] {
        return [
            // Empty root cases
            TestCase(description: "empty roots list", roots: [], path: "foo/bar", expected: false),
            TestCase(description: "empty-string root owns all paths", roots: [""], path: "foo/bar", expected: true),
            TestCase(description: "slash root is empty", roots: ["/"], path: "foo/bar", expected: true),
            TestCase(description: "empty root with empty path", roots: [""], path: "", expected: true),
            // Exact match
            TestCase(description: "exact match", roots: ["foo"], path: "foo", expected: true),
            TestCase(description: "exact nested match", roots: ["foo/bar"], path: "foo/bar", expected: true),
            // Prefix match
            TestCase(description: "root prefixes path", roots: ["foo"], path: "foo/bar", expected: true),
            TestCase(
                description: "deep root prefixes deeper path", roots: ["foo/bar"], path: "foo/bar/baz", expected: true),
            // Non-match: segment-aware (the OPA invariant)
            TestCase(
                description: "segment-aware: foo not a prefix of foobar", roots: ["foo"], path: "foobar",
                expected: false),
            TestCase(description: "deeper root, shorter path", roots: ["foo/bar"], path: "foo", expected: false),
            TestCase(
                description: "sibling segment doesn't match", roots: ["foo/bar"], path: "foo/baz", expected: false),
            // Multi-root: at least one matches
            TestCase(description: "multi-root, second matches", roots: ["a", "b"], path: "b/c", expected: true),
            TestCase(description: "multi-root, none match", roots: ["a", "b"], path: "c/d", expected: false),
            // Slash trimming on roots and paths.
            TestCase(description: "leading slash on root", roots: ["/foo"], path: "foo/bar", expected: true),
            TestCase(description: "trailing slash on root", roots: ["foo/"], path: "foo/bar", expected: true),
            TestCase(description: "leading slash on path", roots: ["foo"], path: "/foo/bar", expected: true),
            TestCase(description: "trailing slash on path", roots: ["foo"], path: "foo/bar/", expected: true),
            // Segment-aware non-match across a "/" boundary.
            TestCase(
                description: "/a/b/c vs root /ab/c is not a match", roots: ["/ab/c"], path: "/a/b/c",
                expected: false),
            // Empty path against a non-empty root.
            TestCase(description: "non-empty root with empty path", roots: ["foo"], path: "", expected: false),
            // Empty root entry mixed in with a non-empty one.
            TestCase(
                description: "multi-root with empty root entry matches anything", roots: ["a", ""],
                path: "z/y/x", expected: true),
        ]
    }

    @Test(arguments: allTests)
    func testRootPathsContain(tc: TestCase) {
        #expect(OPA.Bundle.rootPathsContain(tc.roots, tc.path) == tc.expected, "\(tc.description)")
    }
}

extension RootPathsContainTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
