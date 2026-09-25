import AST
import Foundation
import Testing

@testable import Rego

#if RSASignatures
    import CryptoExtras
#elseif canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

/// End-to-end interop tests against the golang `opa` binary. Gated behind the
/// `SWIFT_OPA_E2E_TESTS` environment variable, which is set by CI and build tooling when
/// `opa` is on PATH, so ordinary `swift test` runs skip them.
///
/// Interop uses clean bundle-relative file names (the portable convention: tarballs and
/// `opa ... -b .` run from inside the bundle directory), which is what our signer always
/// emits.
@Suite("E2E - OPA signature interop")
struct OPAInteropTests {
    typealias Bundle = OPA.Bundle

    static let algorithms: [Bundle.SignatureAlgorithm] = {
        #if RSASignatures
            return [.hs256, .rs256, .es256, .ps256]
        #else
            return [.hs256, .es256]
        #endif
    }()

    static func e2eEnabled() -> Bool {
        ProcessInfo.processInfo.environment["SWIFT_OPA_E2E_TESTS"] == "1"
    }

    // MARK: Helpers

    /// Runs `opa` with `args` in `cwd`, returning the exit status and captured output.
    @discardableResult
    static func runOPA(_ args: [String], cwd: URL) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["opa"] + args
        process.currentDirectoryURL = cwd
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// A workspace with a `bundle/` subdirectory and space for keys/outputs kept
    /// outside the bundle so they are not treated as bundle files.
    struct Workspace {
        let root: URL
        var bundle: URL { root.appendingPathComponent("bundle", isDirectory: true) }
        func cleanup() { try? FileManager.default.removeItem(at: root) }
    }

    static func makeWorkspace() throws -> Workspace {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        let ws = Workspace(root: root)
        try FileManager.default.createDirectory(
            at: ws.bundle.appendingPathComponent("roles"), withIntermediateDirectories: true)
        try Data(#"{"roots":[""],"rego_version":1}"#.utf8).write(
            to: ws.bundle.appendingPathComponent(".manifest"))
        // Number-literal and string edge cases that exercise OPA canonical-JSON parity:
        // 1.0/1e3/big-int must stay verbatim. `<>&/` and non-ASCII stay raw.
        try Data(
            #"{"roles":{"admin":["read","write"]},"nums":[1,2,3.5,1.0,1e3,10000000000000000000],"s":"a<b>&c/д"}"#
                .utf8
        ).write(to: ws.bundle.appendingPathComponent("roles/data.json"))
        try Data("package example\n\ndefault allow := false\n".utf8).write(
            to: ws.bundle.appendingPathComponent("policy.rego"))
        return ws
    }

    struct Material {
        let signing: Bundle.SigningKey
        let verification: Bundle.VerificationKey
        let signingKeyPath: URL
        let verificationKeyPath: URL
    }

    /// Generates key material in-process and writes key files outside the bundle.
    static func material(for algorithm: Bundle.SignatureAlgorithm, in ws: Workspace) throws -> Material {
        let signingKeyPath = ws.root.appendingPathComponent("signing.key")
        let verificationKeyPath = ws.root.appendingPathComponent("verification.key")

        func materialize(
            signing: Bundle.SigningKey, verification: Bundle.VerificationKey, signPEM: String, verifyPEM: String
        )
            throws -> Material
        {
            try Data(signPEM.utf8).write(to: signingKeyPath)
            try Data(verifyPEM.utf8).write(to: verificationKeyPath)
            return Material(
                signing: signing, verification: verification, signingKeyPath: signingKeyPath,
                verificationKeyPath: verificationKeyPath)
        }

        switch algorithm.family {
        case .hmac:
            let secret = "e2e-shared-hmac-secret"
            try Data(secret.utf8).write(to: signingKeyPath)
            try Data(secret.utf8).write(to: verificationKeyPath)
            return Material(
                signing: .hmac(Data(secret.utf8)), verification: .hmac(Data(secret.utf8)),
                signingKeyPath: signingKeyPath, verificationKeyPath: verificationKeyPath)
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
                return try materialize(
                    signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation),
                    signPEM: key.pemRepresentation, verifyPEM: key.publicKey.pemRepresentation)
            #else
                fatalError("RSA key generation requires the RSASignatures trait")
            #endif
        case .ecdsa:
            let key = P256.Signing.PrivateKey()  // ES256
            return try materialize(
                signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation),
                signPEM: key.pemRepresentation, verifyPEM: key.publicKey.pemRepresentation)
        }
    }

    // MARK: our-sign -> opa-verify

    @Test(.enabled(if: OPAInteropTests.e2eEnabled()), arguments: OPAInteropTests.algorithms)
    func ourSignOpaVerify(algorithm: Bundle.SignatureAlgorithm) throws {
        let ws = try Self.makeWorkspace()
        defer { ws.cleanup() }
        let keys = try Self.material(for: algorithm, in: ws)

        let files = try Bundle.signableFiles(inDirectory: ws.bundle)
        let config = try Bundle.sign(files: files, algorithm: algorithm, key: keys.signing)
        try JSONEncoder().encode(config).write(to: ws.bundle.appendingPathComponent(".signatures.json"))

        let result = try Self.runOPA(
            [
                "build", "-b", ".", "--verification-key", keys.verificationKeyPath.path,
                "--signing-alg", algorithm.rawValue, "-o", ws.root.appendingPathComponent("out.tar.gz").path,
            ], cwd: ws.bundle)
        #expect(result.status == 0, "opa failed to verify our \(algorithm.rawValue) signature: \(result.output)")
    }

    // MARK: opa-sign -> our-verify

    @Test(.enabled(if: OPAInteropTests.e2eEnabled()), arguments: OPAInteropTests.algorithms)
    func opaSignOurVerify(algorithm: Bundle.SignatureAlgorithm) throws {
        let ws = try Self.makeWorkspace()
        defer { ws.cleanup() }
        let keys = try Self.material(for: algorithm, in: ws)

        let signResult = try Self.runOPA(
            [
                "sign", "--signing-key", keys.signingKeyPath.path, "--signing-alg", algorithm.rawValue,
                "--bundle", ".", "--output-file-path", ".",
            ], cwd: ws.bundle)
        #expect(signResult.status == 0, "opa sign failed: \(signResult.output)")

        let sigData = try Data(contentsOf: ws.bundle.appendingPathComponent(".signatures.json"))
        let config = try JSONDecoder().decode(Bundle.BundleSignaturesConfig.self, from: sigData)

        let files = try Bundle.signableFiles(inDirectory: ws.bundle)
        try Bundle.verify(files: files, signatures: config, key: keys.verification, algorithm: algorithm)
    }
}
