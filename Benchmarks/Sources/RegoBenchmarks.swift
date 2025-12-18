import AST
import Benchmark
import Foundation
internal import Rego

let benchmarks: @Sendable () -> Void = {
    let simpleBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/simple-directory-bundle")
    let dynamicCallBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/dynamic-call-bundle")

    Benchmark(
        "Simple Policy Evaluation",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "simple", url: simpleBundleURL)])
        let preparedQuery = try! await engine.prepareForEvaluation(query: "data.app.rbac.allow")

        let input: AST.RegoValue = [
            "user": "alice",
            "action": "read",
            "resource": "document123",
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let result = try! await preparedQuery.evaluate(input: input)
            blackHole(result)
        }
    }

    Benchmark(
        "Dynamic Call - Double",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "dynamic", url: dynamicCallBundleURL)])
        let preparedQuery = try! await engine.prepareForEvaluation(query: "data.test")

        let input: AST.RegoValue = [
            "operation": "double",
            "value": 42,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let result = try! await preparedQuery.evaluate(input: input)
            blackHole(result)
        }
    }

    Benchmark(
        "Dynamic Call - Square",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "dynamic", url: dynamicCallBundleURL)])
        let preparedQuery = try! await engine.prepareForEvaluation(query: "data.test")

        let input: AST.RegoValue = [
            "operation": "square",
            "value": 42,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let result = try! await preparedQuery.evaluate(input: input)
            blackHole(result)
        }
    }
}
