import AST
import Benchmark
import Foundation
internal import Rego

struct BenchmarkSpec {
    let name: String
    let bundleName: String
    let bundlePath: String
    let query: String
    let input: AST.RegoValue
}

// Bundle paths are relative to the Benchmarks directory
let bundlesPath = "../Tests/RegoTests/TestData/Bundles"

let allBenchmarkSpecs: [BenchmarkSpec] =
    [
        // MARK: - Policy Evaluation
        BenchmarkSpec(
            name: "Simple Policy Evaluation",
            bundleName: "simple",
            bundlePath: "simple-directory-bundle",
            query: "data.app.rbac.allow",
            input: [
                "user": "alice",
                "action": "read",
                "resource": "document123",
            ]
        ),

        // MARK: - Dynamic Calls
        BenchmarkSpec(
            name: "Dynamic Call - Double",
            bundleName: "dynamic",
            bundlePath: "dynamic-call-bundle",
            query: "data.test",
            input: [
                "operation": "double",
                "value": 42,
            ]
        ),
        BenchmarkSpec(
            name: "Dynamic Call - Square",
            bundleName: "dynamic",
            bundlePath: "dynamic-call-bundle",
            query: "data.test",
            input: [
                "operation": "square",
                "value": 42,
            ]
        ),

        // MARK: - Numeric Literals
        BenchmarkSpec(
            name: "Numeric Literals",
            bundleName: "numeric",
            bundlePath: "numeric-literals-bundle",
            query: "data.benchmark.numeric",
            input: [
                "value": 10,
                "bonus": 5.5,
                "multiplier": 2.0,
            ]
        ),

        // MARK: - Collection Building
        BenchmarkSpec(
            name: "Build Literal Array (10 appends)",
            bundleName: "array",
            bundlePath: "array-build-bundle",
            query: "data.benchmark.array.matched",
            input: ["value": "/bin/nomatch"]
        ),
        BenchmarkSpec(
            name: "Build Literal Object (10 inserts)",
            bundleName: "object",
            bundlePath: "object-build-bundle",
            query: "data.benchmark.object.matched",
            input: ["value": "__nomatch__"]
        ),
        BenchmarkSpec(
            name: "Build Literal Set (10 adds)",
            bundleName: "set",
            bundlePath: "set-build-bundle",
            query: "data.benchmark.set.matched",
            input: ["value": "__nomatch__"]
        ),

        // MARK: - Memoization
        BenchmarkSpec(
            name: "Memoization - Overlapping Rules",
            bundleName: "memo",
            bundlePath: "memo-benchmark",
            query: "data.benchmark.memo.result",
            input: ["value": 10]
        ),
    ]
    // MARK: - Array Iteration (parameterized)
    + [
        ("Small (10 items)", 10, 5),
        ("Medium (100 items)", 100, 50),
        ("Large (1000 items)", 1000, 500),
    ].map { (label, count, threshold) in
        BenchmarkSpec(
            name: "Array Iteration - \(label)",
            bundleName: "iteration",
            bundlePath: "array-iteration-bundle",
            query: "data.benchmark.iteration",
            input: [
                "items": .array((1...count).map { .number(RegoNumber(int: Int64($0))) }),
                "threshold": .number(RegoNumber(int: Int64(threshold))),
            ]
        )
    }

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.timeUnits = .nanoseconds

    if let maxDurationStr = ProcessInfo.processInfo.environment["BENCHMARK_MAX_DURATION_SECONDS"],
        let seconds = Int(maxDurationStr)
    {
        Benchmark.defaultConfiguration.maxDuration = .seconds(seconds)
    }

    if let warmupStr = ProcessInfo.processInfo.environment["BENCHMARK_WARMUP_ITERATIONS"],
        let iterations = Int(warmupStr)
    {
        Benchmark.defaultConfiguration.warmupIterations = iterations
    }

    for spec in allBenchmarkSpecs {
        let bundleURL = URL(fileURLWithPath: "\(bundlesPath)/\(spec.bundlePath)")
        Benchmark(
            spec.name,
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .objectAllocCount, .instructions])
        ) { benchmark in
            var engine = OPA.Engine(
                bundlePaths: [OPA.Engine.BundlePath(name: spec.bundleName, url: bundleURL)])
            var preparedQuery: OPA.Engine.PreparedQuery?
            do {
                preparedQuery = try await engine.prepareForEvaluation(query: spec.query)
            } catch {}

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    let result = try await preparedQuery?.evaluate(input: spec.input)
                    blackHole(result)
                } catch {}
            }
            benchmark.stopMeasurement()
        }
    }
}
