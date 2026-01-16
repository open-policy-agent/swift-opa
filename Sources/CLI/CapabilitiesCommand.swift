import ArgumentParser
import Foundation
import Rego

struct CapabilitiesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capabilities",
        abstract: "Output capabilities JSON for supported builtins.",
        shouldDisplay: false
    )

    @Argument(help: "Path to the capabilities.json file")
    var capabilitiesPath: String

    func run() async throws {
        let supportedBuiltins = Set(BuiltinRegistry.getSupportedBuiltinNames())

        guard let capabilitiesData = FileManager.default.contents(atPath: capabilitiesPath) else {
            throw CapabilitiesError.capabilitiesFileNotFound(path: capabilitiesPath)
        }

        guard let capabilitiesDict = try JSONSerialization.jsonObject(with: capabilitiesData) as? [String: Any] else {
            throw CapabilitiesError.invalidCapabilitiesFormat
        }

        guard let builtinsArray = capabilitiesDict["builtins"] as? [[String: Any]] else {
            throw CapabilitiesError.invalidCapabilitiesFormat
        }

        let filteredBuiltins = builtinsArray.filter { builtin in
            guard let name = builtin["name"] as? String else { return false }
            return supportedBuiltins.contains(name)
        }

        var filteredCapabilities = capabilitiesDict
        filteredCapabilities["builtins"] = filteredBuiltins
        filteredCapabilities.removeValue(forKey: "wasm_abi_versions")

        let jsonData = try JSONSerialization.data(
            withJSONObject: filteredCapabilities, options: [.prettyPrinted, .sortedKeys])

        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

enum CapabilitiesError: Error {
    case capabilitiesFileNotFound(path: String)
    case invalidCapabilitiesFormat
}
