import ArgumentParser

@main
struct CLIRootCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-opa-cli",
        abstract: "An example command line showing swift-opa in action.",
        subcommands: [EvalCommand.self, BenchCommand.self, CapabilitiesCommand.self]
    )
}
