import AST
import Benchmark
import Foundation
internal import Rego

/// Benchmarks comparing the original O(N^2) bundle overlap algorithm
/// ported from OPA against the new O(N log N + K) `checkBundlesForOverlap`
/// implementation.
///
/// Each scenario stresses a different aspect of the algorithms:
///   - disjoint:       best case, no conflicts
///   - identical:      pathological - all bundles share one root
///   - chain:          pathological deep prefix chain -> K = O(N^2) reported conflicts
///   - multi-root:     N-many bundles, M-many roots each, no conflicts
///   - wide fanout:    one ancestor + N descendants -> K = O(N)
let benchmarks: @Sendable () -> Void = {
    // MARK: - Scenario builders

    func disjoint(_ n: Int) -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        for i in 0..<n {
            out["b\(i)"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: ["root\(i)"]))
        }
        return out
    }

    func allIdentical(_ n: Int) -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        for i in 0..<n {
            out["b\(i)"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: ["shared"]))
        }
        return out
    }

    func chain(_ n: Int) -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        var path = "a"
        for i in 0..<n {
            out["b\(i)"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: [path]))
            path += "/x"
        }
        return out
    }

    func disjointMultiRoot(bundleCount n: Int, rootsPerBundle m: Int) -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        for i in 0..<n {
            let roots = (0..<m).map { "bundle\(i)/root\($0)" }
            out["b\(i)"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: roots))
        }
        return out
    }

    func wideFanout(_ n: Int) -> [String: OPA.Bundle] {
        var out: [String: OPA.Bundle] = [:]
        out["umbrella"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: ["a"]))
        for i in 0..<n {
            out["b\(i)"] = try? OPA.Bundle(manifest: OPA.Manifest(roots: ["a/x\(i)"]))
        }
        return out
    }

    // MARK: - Scenario configurations
    //
    // Each tuple is (label, builder). The same fixture is used for both the
    // original and new algorithm benchmarks so the comparison is apples-to-apples.

    let scenarios: [(label: String, build: () -> [String: OPA.Bundle])] = [
        ("disjoint N=10", { disjoint(10) }),
        ("disjoint N=100", { disjoint(100) }),

        ("identical N=10", { allIdentical(10) }),
        ("identical N=100", { allIdentical(100) }),

        ("chain N=10", { chain(10) }),
        ("chain N=100", { chain(100) }),

        ("multi-root N=10 M=10", { disjointMultiRoot(bundleCount: 10, rootsPerBundle: 10) }),
        ("multi-root N=100 M=10", { disjointMultiRoot(bundleCount: 100, rootsPerBundle: 10) }),

        ("wide fanout N=10", { wideFanout(10) }),
        ("wide fanout N=100", { wideFanout(100) }),
    ]

    // MARK: - Benchmark registration

    for scenario in scenarios {
        // Build the bundle set once outside the benchmark closure so fixture
        // construction doesn't pollute the measurement.
        let bundles = scenario.build()

        Benchmark(
            "Overlap [original] \(scenario.label)",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal])
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                // Both algorithms throw on conflict; we want to measure the work,
                // not the throw, so swallow the error.
                _ = try? OPA.Bundle.checkBundlesForOverlapOriginal(bundleSet: bundles)
            }
        }

        Benchmark(
            "Overlap [new]      \(scenario.label)",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal])
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                _ = try? OPA.Bundle.checkBundlesForOverlap(bundleSet: bundles)
            }
        }
    }
}

// The original O(N^2) algorithm's implementation is rendered here for benchmarking purposes.
extension OPA.Bundle {
    /// Checks if two bundle root paths overlap (one contains the other).
    static func rootPathsOverlap(_ pathA: String, _ pathB: String) -> Bool {
        return rootContains(root: pathA, other: pathB) || rootContains(root: pathB, other: pathA)
    }

    /// Checks if any of the root paths contain the given path.
    static func rootPathsContain(_ roots: [String], path: String) -> Bool {
        for root in roots {
            if rootContains(root: root, other: path) {
                return true
            }
        }
        return false
    }

    /// Checks if `root` is a prefix path of `other`.
    /// Optimized to minimize allocations using Substring views.
    static func rootContains(root: String, other: String) -> Bool {
        // Empty root always contains other
        if root.isEmpty {
            return true
        }

        // Fast path: if root is longer than other (by character count),
        // it can't be a prefix (with some edge cases around trailing slashes)
        // This is a heuristic - the segment comparison below is authoritative

        let rootSegments = root.split(separator: "/", omittingEmptySubsequences: false)
        let otherSegments = other.split(separator: "/", omittingEmptySubsequences: false)

        // Handle special case: single empty segment root
        if rootSegments.count == 1 && rootSegments[0].isEmpty {
            return true
        }

        // Root has more segments than other. It can't be a prefix.
        if rootSegments.count > otherSegments.count {
            return false
        }

        // Compare segments. Using zip stops at the shorter sequence.
        for (rootSeg, otherSeg) in zip(rootSegments, otherSegments) {
            if rootSeg != otherSeg {
                return false
            }
        }

        return true
    }

    // checkBundlesForOverlap verifies whether a set of bundles is valid
    // together, in that there are no overlaps of their reserved roots
    // space within the logical data tree.
    // Throws a bundleConflictError if a conflict is detected.
    static func checkBundlesForOverlapOriginal(bundleSet bundles: [String: OPA.Bundle]) throws {
        // Note(philip): The overlap check here is implemented with a
        // straightforward O(N^2) algorithm, same as OPA. In practice,
        // most bundles have few and shallow root path sets.
        var collidingBundles: Set<String> = []
        var conflictSet: Set<String> = []
        for (name, bundle) in bundles.sorted(by: { $0.key < $1.key }) {
            for (otherName, otherBundle) in bundles.sorted(by: { $0.key < $1.key }) {
                if name == otherName {
                    continue  // skip the current bundle.
                }

                for root in bundle.manifest.roots {
                    let rootPath = root.trimmingCharacters(in: ["/"])
                    for otherRoot in otherBundle.manifest.roots {
                        let otherRootPath = otherRoot.trimmingCharacters(in: ["/"])
                        guard OPA.Bundle.rootPathsOverlap(rootPath, otherRootPath) else {
                            continue  // skip non-overlapping paths.
                        }

                        // Record conflicting bundles and paths.
                        collidingBundles.insert(name)
                        collidingBundles.insert(otherName)

                        // Different message required if the roots are same
                        if rootPath == otherRootPath {
                            conflictSet.insert("root \(rootPath) is in multiple bundles")
                        } else {
                            let paths = [rootPath, otherRootPath].sorted()
                            conflictSet.insert("\(paths[0]) overlaps \(paths[1])")
                        }
                    }
                }
            }
        }

        guard collidingBundles.isEmpty && conflictSet.isEmpty else {
            // The benchmark only times the work; the specific error type is not measured.
            struct OverlapError: Error {
                let bundles: [String]
                let messages: [String]
            }
            throw OverlapError(
                bundles: collidingBundles.sorted(),
                messages: conflictSet.sorted()
            )
        }
    }
}
