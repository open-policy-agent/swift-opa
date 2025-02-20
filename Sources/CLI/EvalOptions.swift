import AST
import ArgumentParser
import Foundation
import Rego

// EvalOptions are common options for evaluating a bundle.
// This is shared by related commands.
struct EvalOptions: ParsableArguments {
    @Argument(help: "The Rego query to evaluate")
    var query: String
    @Option(name: [.short, .customLong("bundle")], help: "Load paths as bundle files or root directories")
    var bundles: [String]
    @Option(name: [.long], help: "Enable query explanations")
    var explain: ExplainLevel = .off
    @Option(name: [.short, .long], help: "set input file path")
    var inputFile: String?
    @Option(
        name: [.customShort("j"), .customLong("just-use-this-json-string-as-input-plz")], help: "Input JSON string")
    var rawInput: String?
    @Flag(name: [.long], help: "treat the first built-in function error encountered as fatal")
    var strictBuiltinErrors: Bool = false

    // Parsed inputs during validation
    var inputValue: AST.RegoValue = .object([:])
    var bundlePaths: [Rego.Engine.BundlePath] = []

    enum CodingKeys: String, CodingKey {
        case inputValue
        case bundles
        case explain
        case inputFile
        case query
        case rawInput
        case strictBuiltinErrors
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
}
