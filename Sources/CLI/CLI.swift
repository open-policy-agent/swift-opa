import ArgumentParser

@main
struct CLIRootCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-rego-cli",
        abstract: "An example command line showing swift-rego in action.",
        subcommands: [EvalCommand.self, BenchCommand.self]
    )
}
