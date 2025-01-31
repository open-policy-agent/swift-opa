import AST
import ArgumentParser
import Foundation
import Rego

struct EvalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval",
        abstract: "Evaluate a Rego query."
    )

    @Argument(help: "The Rego query to evaluate.") var query: String
    @Option(name: [.short, .customLong("bundle")], help: "Load paths as bundle files or root directories.") var bundles:
        [String]
    @Option(name: [.long], help: "Enable query explanations.") var explain: ExplainLevel = .off
    @Option(name: [.short, .long], help: "set input file path") var inputFile: String?
    @Option(
        name: [.customShort("j"), .customLong("just-use-this-json-string-as-input-plz")], help: "Input JSON string")
    var rawInput: String?

    var inputValue: AST.RegoValue = .object([:])
    var bundlePaths: [Rego.Engine.BundlePath] = []

    enum CodingKeys: String, CodingKey {
        // Skip inputValue until we can make AST.RegoValue actually Decodable
        case bundles
        case explain
        case inputFile
        case query
        case rawInput
    }

    mutating func validate() throws {
        var inputData: Data?

        if inputFile != nil {
            guard rawInput == nil else {
                throw ValidationError("Cannot specify both input file and raw input JSON string")
            }
            do {
                let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: inputFile!))
                inputData = fileHandle.readDataToEndOfFile()
            } catch {
                throw ValidationError("Could not open input file \(inputFile!): \(error)")
            }
        }

        if rawInput != nil {
            guard inputFile == nil else {
                throw ValidationError("Cannot specify both input file and raw input JSON string")
            }
            inputData = rawInput!.data(using: .utf8)!
        }

        if let inputData = inputData {
            do {
                self.inputValue = try AST.RegoValue(fromJson: inputData)
            } catch {
                throw ValidationError("Failed to parse input JSON: \(error)")
            }
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        self.bundlePaths = try bundles.compactMap {
            guard let url = URL(string: $0, relativeTo: cwd) else {
                throw ValidationError("Invalid bundle path: \($0): must be a valid file URL")
            }
            return Rego.Engine.BundlePath(
                name: $0,
                url: url
            )
        }
    }

    mutating func run() async throws {
        // Initialize a Rego.Engine initially configured with our bundles from the CLI options.
        var regoEngine = try Rego.Engine(withBundlePaths: self.bundlePaths)

        // Prepare does as much pre-processing as possible to get ready to evaluate queries.
        // This only needs to be done once when loading the engine and after updating it.
        try await regoEngine.prepare()

        let tracer = tracerForLevel(self.explain)

        let resultSet = try await regoEngine.evaluate(
            query: self.query,
            input: self.inputValue,
            tracer: tracer
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let output = String(data: try encoder.encode(resultSet), encoding: .utf8) else {
            print("Failed to encode result set to JSON string")
            throw ExitCode.failure
        }
        print(output)

        guard let tracer = tracer else {
            return
        }
        print("Trace:")
        tracer.prettyPrint(out: FileHandle.standardOutput)
    }
}

func tracerForLevel(_ level: ExplainLevel) -> Rego.BufferedQueryTracer? {
    return switch level {
    case .full:
        Rego.BufferedQueryTracer(level: .full)
    case .notes:
        Rego.BufferedQueryTracer(level: .note)
    default:
        nil
    }
}

enum ExplainLevel: String, CaseIterable, ExpressibleByArgument {
    case off
    case full
    case notes
}
