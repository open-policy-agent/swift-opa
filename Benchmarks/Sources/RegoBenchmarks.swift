import AST
import Benchmark
import Foundation
internal import Rego

let benchmarks: @Sendable () -> Void = {
    Benchmark(
        "Simple Policy Evaluation",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal])
    ) { benchmark in
        // Setup OPA engine
        var engine = OPA.Engine(
            bundlePaths: [OPA.Engine.BundlePath(name: "simple", url: URL(fileURLWithPath: "../Tests/RegoTests/TestData/Bundles/simple-directory-bundle"))])
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
}