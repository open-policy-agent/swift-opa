import AST
import ArgumentParser
import Foundation
import Rego

struct BenchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Benchmark a Rego query"
    )

    @OptionGroup
    var evalOptions: EvalOptions
    @Option(name: [.short, .customLong("count")], help: "iteration count")
    var count: UInt = 10_000

    mutating func run() async throws {
        // Initialize a Rego.Engine initially configured with our bundles from the CLI options.
        var regoEngine = try Rego.OPA.Engine(bundlePaths: self.evalOptions.bundlePaths)

        // Prepare does as much pre-processing as possible to get ready to evaluate queries.
        // This only needs to be done once when loading the engine and after updating it.
        let preparedQuery = try await regoEngine.prepareForEvaluation(query: self.evalOptions.query)

        let report = try await measureAsync(iterations: Int(count)) {
            let _ = try await preparedQuery.evaluate(
                input: self.evalOptions.inputValue,
                strictBuiltins: self.evalOptions.strictBuiltinErrors
            )
        }

        // <name> <iterations> <value> <unit> [<value> <unit>...]
        // https://go.googlesource.com/proposal/+/master/design/14313-benchmark-format.md
        print(report.formatted(.gobench))
    }
}
