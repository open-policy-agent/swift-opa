import AST
import Benchmark
import Foundation
internal import Rego

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.timeUnits = .nanoseconds

    // Benchmark runs from the Benchmarks directory, so paths are relative to parent
    let simpleBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/simple-directory-bundle")
    let dynamicCallBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/dynamic-call-bundle")
    let arrayIterationBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/array-iteration-bundle")
    let numericLiteralsBundleURL = URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/numeric-literals-bundle")

    Benchmark(
        "Simple Policy Evaluation",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "simple", url: simpleBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.app.rbac.allow")
        } catch {}

        let input: AST.RegoValue = [
            "user": "alice",
            "action": "read",
            "resource": "document123",
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Dynamic Call - Double",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "dynamic", url: dynamicCallBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.test")
        } catch {}

        let input: AST.RegoValue = [
            "operation": "double",
            "value": 42,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Dynamic Call - Square",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "dynamic", url: dynamicCallBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.test")
        } catch {}

        let input: AST.RegoValue = [
            "operation": "square",
            "value": 42,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Array Iteration - Small (10 items)",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "iteration", url: arrayIterationBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.benchmark.iteration")
        } catch {}

        let input: AST.RegoValue = [
            "items": .array((1...10).map { .number($0 as NSNumber) }),
            "threshold": 5,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Array Iteration - Medium (100 items)",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "iteration", url: arrayIterationBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.benchmark.iteration")
        } catch {}

        let input: AST.RegoValue = [
            "items": .array((1...100).map { .number($0 as NSNumber) }),
            "threshold": 50,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Array Iteration - Large (1000 items)",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "iteration", url: arrayIterationBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.benchmark.iteration")
        } catch {}

        let input: AST.RegoValue = [
            "items": .array((1...1000).map { .number($0 as NSNumber) }),
            "threshold": 500,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }

    Benchmark(
        "Numeric Literals",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "numeric", url: numericLiteralsBundleURL)])
        do {
            let preparedQuery = try await engine.prepareForEvaluation(query: "data.benchmark.numeric")
        } catch {}

        let input: AST.RegoValue = [
            "value": 10,
            "bonus": 5.5,
            "multiplier": 2.0,
        ]

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            do {
                let result = try await preparedQuery.evaluate(input: input)
                blackHole(result)
            } catch {}
        }
    }
}
