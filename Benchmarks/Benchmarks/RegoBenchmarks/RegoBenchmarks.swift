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
            name: "Build Literal Object (100 inserts)",
            bundleName: "object100",
            bundlePath: "object-build-100-bundle",
            query: "data.benchmark.object100.matched",
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

/// Loads a bundle directory's `.manifest`, root `plan.json`, and optional root `data.json` into memory.
/// This is specialized to flat bundle structures like the ones the prepare benchmarks use,
/// and may not work on other bundle structures.
func loadPlanBundle(at url: URL) -> OPA.Bundle {
    do {
        let manifest = try OPA.Manifest(from: Data(contentsOf: url.appending(path: ".manifest")))
        let planURL = url.appending(path: "plan.json")
        let planFile = BundleFile(url: planURL, data: try Data(contentsOf: planURL))
        var data: AST.RegoValue = .object([:])
        let dataURL = url.appending(path: "data.json")
        if FileManager.default.fileExists(atPath: dataURL.path) {
            data = try JSONDecoder().decode(AST.RegoValue.self, from: Data(contentsOf: dataURL))
        }
        return try OPA.Bundle(manifest: manifest, planFiles: [planFile], data: data)
    } catch {
        fatalError("bundle load failed: \(error)")
    }
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
            let engine = OPA.Engine(
                bundlePaths: [OPA.Engine.BundlePath(name: spec.bundleName, url: bundleURL)])
            var preparedQuery: OPA.Engine.PreparedQuery?
            do {
                preparedQuery = try await engine.preparePolicySet().query(spec.query)
            } catch { fatalError("prepare failed: \(error)") }

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    let result = try await preparedQuery?.evaluate(input: spec.input)
                    blackHole(result)
                } catch {}
            }
            benchmark.stopMeasurement()
        }

        Benchmark(
            "\(spec.name) (sync)",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .objectAllocCount, .instructions])
        ) { benchmark in
            let engine = OPA.Engine(
                bundlePaths: [OPA.Engine.BundlePath(name: spec.bundleName, url: bundleURL)])
            let preparedQuery: OPA.Engine.PreparedQuery
            do {
                preparedQuery = try await engine.preparePolicySet().query(spec.query)
            } catch { fatalError("prepare failed: \(error)") }

            benchmark.startMeasurement()
            if preparedQuery.supportsSyncEvaluation {
                for _ in benchmark.scaledIterations {
                    do {
                        let eval: () throws -> ResultSet = { try preparedQuery.evaluate(input: spec.input) }
                        blackHole(try eval())
                    } catch {}
                }
            }
            benchmark.stopMeasurement()
        }

        Benchmark(
            "\(spec.name) (async, no sync opts)",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .objectAllocCount, .instructions])
        ) { benchmark in
            var engine = OPA.Engine(
                bundlePaths: [OPA.Engine.BundlePath(name: spec.bundleName, url: bundleURL)])
            engine.optimizeAsync = false
            var preparedQuery: OPA.Engine.PreparedQuery?
            do {
                preparedQuery = try await engine.preparePolicySet().query(spec.query)
            } catch { fatalError("prepare failed: \(error)") }

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

    // MARK: - Query Preparation
    // Compares preparing N queries one at a time against preparing a policy
    // set once and deriving N queries from it. Bundles are loaded up front, so
    // only preparation is measured.
    let prepareQueryCount = 10
    for spec in allBenchmarkSpecs where ["simple", "memo"].contains(spec.bundleName) {
        let bundleURL = URL(fileURLWithPath: "\(bundlesPath)/\(spec.bundlePath)")

        Benchmark(
            "Prepare \(prepareQueryCount) Queries - prepareForEvaluation (\(spec.bundleName))",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .instructions])
        ) { benchmark in
            let bundle = loadPlanBundle(at: bundleURL)
            var engine = OPA.Engine(bundles: [spec.bundleName: bundle])

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    for _ in 0..<prepareQueryCount {
                        blackHole(try await engine.prepareForEvaluation(query: spec.query))
                    }
                } catch { fatalError("prepare failed: \(error)") }
            }
            benchmark.stopMeasurement()
        }

        Benchmark(
            "Prepare \(prepareQueryCount) Queries - preparePolicySet (\(spec.bundleName))",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .instructions])
        ) { benchmark in
            let bundle = loadPlanBundle(at: bundleURL)
            let engine = OPA.Engine(bundles: [spec.bundleName: bundle])

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    let policySet = try await engine.preparePolicySet()
                    for _ in 0..<prepareQueryCount {
                        blackHole(try policySet.query(spec.query))
                    }
                } catch { fatalError("prepare failed: \(error)") }
            }
            benchmark.stopMeasurement()
        }

        // Compares re-preparing a policy set against swapping its bundle data.
        Benchmark(
            "Replace Bundle Data - preparePolicySet (\(spec.bundleName))",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .instructions])
        ) { benchmark in
            let bundle = loadPlanBundle(at: bundleURL)
            let engine = OPA.Engine(bundles: [spec.bundleName: bundle])

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    blackHole(try await engine.preparePolicySet())
                } catch { fatalError("prepare failed: \(error)") }
            }
            benchmark.stopMeasurement()
        }

        Benchmark(
            "Replace Bundle Data - replacingData (\(spec.bundleName))",
            configuration: .init(metrics: [.wallClock, .mallocCountTotal, .instructions])
        ) { benchmark in
            let bundle = loadPlanBundle(at: bundleURL)
            let policySet: OPA.PreparedPolicySet
            do {
                policySet = try await OPA.Engine(bundles: [spec.bundleName: bundle]).preparePolicySet()
            } catch { fatalError("prepare failed: \(error)") }

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    blackHole(try await policySet.replacingData(bundles: [spec.bundleName: bundle.data]))
                } catch { fatalError("replacing data failed: \(error)") }
            }
            benchmark.stopMeasurement()
        }
    }
}
