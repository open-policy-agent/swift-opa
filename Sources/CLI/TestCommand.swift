import ArgumentParser
import Foundation
import TestRunner

/// `swift-opa-cli test` — runs `test_*` rules found in compiled IR plan bundles.
///
/// Behaves like `opa test`, with the important caveat that swift-opa runs
/// *compiled* IR plans rather than `.rego` source. Test rules must therefore be
/// present in the plan bundle as funcs. OPA includes a test rule when it is
/// reachable from the build's entrypoints. This happens when the test
/// references an entrypoint's rules/data, or when the test's package/rules are
/// entrypoints themselves. Making the test package an entrypoint
/// (`opa build -b <dir> -t plan -e <test-package>`) reliably includes all of its
/// tests, but is not the only way they can end up in the plan.
struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Execute Rego test cases from compiled IR plan bundles.",
        discussion: """
            Searches the given plan bundle paths for rules named test_* (run) and \
            todo_test_* (skipped), generates a plan for each, and evaluates it.

            Note: swift-opa runs compiled IR plans, not .rego source. Test rules \
            must be present in the plan as funcs. They are included when reachable \
            from the build's entrypoints; making the test package an entrypoint \
            (`opa build -b <dir> -t plan -e <test-package>`) reliably includes all \
            of its tests.
            """
    )

    @Argument(help: "Bundle paths (directories) to search for tests.")
    var paths: [String] = []

    // MARK: CLI Options

    @Flag(name: [.customShort("b"), .customLong("bundle")], help: "Load paths as bundles (always on).")
    var bundle: Bool = false

    @Option(name: [.customShort("r"), .customLong("run")], help: "Run only tests matching this regular expression.")
    var run: String?

    @Flag(name: [.short, .long], help: "Verbose output (list every test).")
    var verbose: Bool = false

    @Option(name: [.long], help: "Number of times to repeat each test.")
    var count: Int = 1

    @Flag(
        name: [.customShort("z"), .customLong("exit-zero-on-skipped")],
        help: "Exit with status 0 even when tests are skipped.")
    var exitZeroOnSkipped: Bool = false

    // MARK: Unimplemented Option Stubs

    @Flag(name: [.long], help: .hidden) var bench: Bool = false
    @Flag(name: [.long], help: .hidden) var benchmem: Bool = false
    @Option(name: [.long], help: .hidden) var capabilities: String?
    @Flag(name: [.customShort("c"), .customLong("coverage")], help: .hidden) var coverage: Bool = false
    @Option(name: [.long], help: .hidden) var explain: String?
    @Option(name: [.long], help: .hidden) var format: String?
    @Option(name: [.long], help: .hidden) var ignore: [String] = []
    @Option(name: [.long], help: .hidden) var maxErrors: Int?
    @Option(name: [.short, .long], help: .hidden) var parallel: Int?
    @Option(name: [.long], help: .hidden) var schema: String?
    @Flag(name: [.long], help: .hidden) var sort: Bool = false
    @Option(name: [.customShort("t"), .customLong("target")], help: .hidden) var target: String?
    @Option(name: [.long], help: .hidden) var threshold: Double?
    @Option(name: [.long], help: .hidden) var timeout: String?
    @Flag(name: [.long], help: .hidden) var v0Compatible: Bool = false
    @Option(name: [.long], help: .hidden) var varValues: String?
    @Flag(name: [.long], help: .hidden) var watch: Bool = false

    mutating func run() async throws {
        warnUnimplemented()

        guard !paths.isEmpty else {
            throw ValidationError("no bundle paths provided")
        }

        // Resolve symlinks so the loaded paths match the enumerator's resolved
        // child paths (e.g. /tmp -> /private/tmp on macOS). `URL(fileURLWithPath:)`
        // already resolves relative paths against the current working directory.
        let urls = paths.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() }

        let results = try await TestRunner.run(paths: urls, runFilter: run, count: count)

        if results.isEmpty {
            FileHandle.standardError.write(Data("warning: no tests found under the given paths\n".utf8))
        }

        let report = TestReporter(verbose: verbose).render(results)
        print(report)

        throw exitCode(for: results)
    }

    /// Determines the process exit code, mirroring `opa test`: failures/errors
    /// yield status 2, as do skipped tests, unless `--exit-zero-on-skipped` is set.
    private func exitCode(for results: [TestResult]) -> ExitCode {
        var hasFailure = false
        var hasSkip = false
        for result in results {
            switch result.outcome {
            case .failed, .errored:
                hasFailure = true
            case .skipped:
                hasSkip = true
            case .passed:
                break
            }
        }
        if hasFailure {
            return ExitCode(2)
        }
        if hasSkip && !exitZeroOnSkipped {
            return ExitCode(2)
        }
        return ExitCode.success
    }

    /// Warnings on stderr for any unimplemented flags.
    private func warnUnimplemented() {
        var unimplemented: [String] = []
        if bench { unimplemented.append("--bench") }
        if benchmem { unimplemented.append("--benchmem") }
        if capabilities != nil { unimplemented.append("--capabilities") }
        if coverage { unimplemented.append("--coverage") }
        if explain != nil { unimplemented.append("--explain") }
        if format != nil { unimplemented.append("--format") }
        if !ignore.isEmpty { unimplemented.append("--ignore") }
        if maxErrors != nil { unimplemented.append("--max-errors") }
        if parallel != nil { unimplemented.append("--parallel") }
        if schema != nil { unimplemented.append("--schema") }
        if sort { unimplemented.append("--sort") }
        if target != nil { unimplemented.append("--target") }
        if threshold != nil { unimplemented.append("--threshold") }
        if timeout != nil { unimplemented.append("--timeout") }
        if v0Compatible { unimplemented.append("--v0-compatible") }
        if varValues != nil { unimplemented.append("--var-values") }
        if watch { unimplemented.append("--watch") }

        for flag in unimplemented {
            FileHandle.standardError.write(Data("option `\(flag)` is not implemented.\n".utf8))
        }
    }
}
