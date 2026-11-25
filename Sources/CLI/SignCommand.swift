#if CLI
    import AST
    import ArgumentParser
    import Foundation
    import Rego

    /// `swift-opa-cli sign` — generates a `.signatures.json` for a bundle directory,
    /// mirroring `opa sign`. swift-opa currently supports directory bundles only.
    struct SignCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sign",
            abstract: "Generate a bundle signature (.signatures.json) for a bundle directory.",
            discussion: """
                Hashes every file in the bundle directory (except .signatures.json), wraps the \
                hashes in a signed JWS, and writes a .signatures.json file. Mirrors `opa sign`.

                Note: only directory bundles are supported; .tar.gz inputs are not yet handled.
                """
        )

        @Argument(help: "Bundle directory to sign.")
        var paths: [String] = []

        @Flag(name: [.customShort("b"), .customLong("bundle")], help: "Treat paths as bundles (always on).")
        var bundle: Bool = false

        @Option(name: [.long], help: "Path to the private key (PEM) or HMAC secret used for signing.")
        var signingKey: String

        @Option(name: [.long], help: "Name of the signing algorithm (default RS256).")
        var signingAlg: OPA.Bundle.SignatureAlgorithm = .default

        @Option(name: [.long], help: "Path to a JSON file of additional claims (e.g. scope, keyid, iat).")
        var claimsFile: String?

        @Option(
            name: [.customShort("o"), .customLong("output-file-path")],
            help: "Directory to write .signatures.json into (default \".\").")
        var outputFilePath: String = "."

        // MARK: Unimplemented Option Stubs

        @Option(name: [.long], help: .hidden) var signingPlugin: String?

        mutating func run() async throws {
            warnUnimplemented()

            let dir = try resolveBundleDirectory(paths)
            let key = try loadSigningKey(path: signingKey, algorithm: signingAlg)

            var claims: AST.RegoValue = .object([:])
            if let claimsFile {
                guard let data = FileManager.default.contents(atPath: claimsFile) else {
                    throw SigningCLIError.claimsReadFailed(claimsFile)
                }
                claims = try AST.RegoValue(jsonData: data)
                guard case .object = claims else {
                    throw ValidationError("claims file must contain a JSON object: \(claimsFile)")
                }
            }

            let files = try OPA.Bundle.signableFiles(inDirectory: dir)
            let config = try OPA.Bundle.sign(
                files: files, algorithm: signingAlg, key: key, additionalClaims: claims)

            let outDir = URL(fileURLWithPath: outputFilePath, isDirectory: true)
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            let outURL = outDir.appendingPathComponent(".signatures.json", isDirectory: false)
            try JSONEncoder().encode(config).write(to: outURL, options: .atomic)
        }

        private func warnUnimplemented() {
            if signingPlugin != nil {
                warnFlagUnimplemented("--signing-plugin")
            }
        }
    }
#endif
