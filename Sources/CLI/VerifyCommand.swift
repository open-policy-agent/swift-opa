#if CLI
    import ArgumentParser
    import Foundation
    import Rego

    /// `swift-opa-cli verify` — verifies a signed bundle directory's `.signatures.json`,
    /// mirroring `opa run`/`opa build`'s verification flags. Directory bundles only.
    struct VerifyCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "verify",
            abstract: "Verify a signed bundle directory's .signatures.json.",
            discussion: """
                Checks the JWS signature, confirms the payload's file list matches the bundle \
                exactly, and re-hashes each file. Exits non-zero on any verification failure.

                Note: only directory bundles are supported; .tar.gz inputs are not yet handled.
                """
        )

        @Argument(help: "Bundle directory to verify.")
        var paths: [String] = []

        @Flag(name: [.customShort("b"), .customLong("bundle")], help: "Treat paths as bundles (always on).")
        var bundle: Bool = false

        @Option(name: [.long], help: "Path to the public key (PEM) or HMAC secret used to verify.")
        var verificationKey: String

        @Option(name: [.long], help: "Optional name for the verification key (informational).")
        var verificationKeyId: String?

        @Option(name: [.long], help: "Name of the signing algorithm (default RS256).")
        var signingAlg: OPA.Bundle.SignatureAlgorithm = .default

        @Option(name: [.long], help: "Scope that must match the signature payload's scope.")
        var scope: String?

        @Option(name: [.long], help: "File names to exclude during verification.")
        var excludeFilesVerify: [String] = []

        @Flag(name: [.long], help: "Disable bundle signature verification.")
        var skipVerify: Bool = false

        func run() async throws {
            if skipVerify {
                FileHandle.standardError.write(
                    Data("warning: --skip-verify set; skipping signature verification\n".utf8))
                return
            }

            let dir = try resolveBundleDirectory(paths)
            let key = try loadVerificationKey(path: verificationKey, algorithm: signingAlg)

            let sigURL = dir.appendingPathComponent(".signatures.json", isDirectory: false)
            guard let sigData = FileManager.default.contents(atPath: sigURL.path) else {
                throw SigningCLIError.signaturesFileMissing(dir.path)
            }
            let config = try JSONDecoder().decode(OPA.Bundle.BundleSignaturesConfig.self, from: sigData)

            let files = try OPA.Bundle.signableFiles(inDirectory: dir)
            try OPA.Bundle.verify(
                files: files, signatures: config, key: key, algorithm: signingAlg,
                scope: scope, excludeFiles: Set(excludeFilesVerify))

            print("verification succeeded")
        }
    }
#endif
