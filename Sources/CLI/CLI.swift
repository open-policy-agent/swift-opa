#if CLI
    import ArgumentParser

    @main
    struct CLIRootCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "swift-opa-cli",
            abstract: "An example command line showing swift-opa in action.",
            subcommands: [EvalCommand.self, BenchCommand.self, CapabilitiesCommand.self]
        )
    }
#else
    // The executable is built without its swift-argument-parser dependency when the
    // "CLI" trait is disabled. This stub keeps the target linkable in that configuration.
    @main
    struct CLIRootCommand {
        static func main() {
            print("swift-opa-cli was built without the \"CLI\" trait enabled.")
        }
    }
#endif
