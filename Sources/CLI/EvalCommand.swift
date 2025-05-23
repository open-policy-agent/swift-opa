import AST
import ArgumentParser
import Foundation
import Rego

struct EvalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval",
        abstract: "Evaluate a Rego query"
    )

    @OptionGroup
    var evalOptions: EvalOptions

    mutating func run() async throws {
        // Initialize a Rego.Engine initially configured with our bundles from the CLI options.
        var regoEngine = Rego.OPA.Engine(bundlePaths: self.evalOptions.bundlePaths)

        let tracer = tracerForLevel(self.evalOptions.explain)

        // Prepare does as much pre-processing as possible to get ready to evaluate queries.
        // This only needs to be done once when loading the engine and after updating it. These
        // PreparedQuery's can be re-used.
        let preparedQuery = try await regoEngine.prepareForEvaluation(query: self.evalOptions.query)

        let resultSet = try await preparedQuery.evaluate(
            input: self.evalOptions.inputValue,
            tracer: tracer,
            strictBuiltins: self.evalOptions.strictBuiltinErrors
        )

        // Serialize and output the response
        let output = try resultSet.jsonString
        print(output)

        guard let tracer = tracer else {
            return
        }
        print("Trace:")
        tracer.prettyPrint(to: FileHandle.standardOutput)
    }
}

func tracerForLevel(_ level: ExplainLevel) -> OPA.Trace.BufferedQueryTracer? {
    return switch level {
    case .full:
        OPA.Trace.BufferedQueryTracer(level: .full)
    case .notes:
        OPA.Trace.BufferedQueryTracer(level: .note)
    default:
        nil
    }
}

enum ExplainLevel: String, CaseIterable, ExpressibleByArgument {
    case off
    case full
    case notes
}
