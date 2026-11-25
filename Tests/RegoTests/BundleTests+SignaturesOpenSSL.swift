import AST
import Foundation
import Testing

@testable import Rego

/// Confirms our signing/verification accepts key material produced by the system
/// `openssl` toolchain (not just in-process swift-crypto keys). Gated behind
/// `SWIFT_OPA_OPENSSL_TESTS`, mirroring the SDK's OpenSSL-availability gate.
@Suite("BundleTests - Signatures (OpenSSL keys)")
struct BundleSignatureOpenSSLTests {
    typealias Bundle = OPA.Bundle

    static func opensslEnabled() -> Bool {
        ProcessInfo.processInfo.environment["SWIFT_OPA_OPENSSL_TESTS"] == "1"
    }

    @discardableResult
    static func openssl(_ args: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["openssl"] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        // Drain before waiting to avoid deadlock if output exceeds the pipe buffer.
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus
    }

    static let files: [BundleFile] = [
        BundleSignatureTests.bf(".manifest", #"{"roots":[""],"rego_version":1}"#),
        BundleSignatureTests.bf("data.json", #"{"a":1,"b":[1,2,3]}"#),
        BundleSignatureTests.bf("policy.rego", "package example\nallow := true\n"),
    ]

    /// RSA cases only when the RSASignatures trait is enabled; ECDSA always.
    static let algorithms: [Bundle.SignatureAlgorithm] = {
        #if RSASignatures
            return [.rs256, .es256, .ps256]
        #else
            return [.es256]
        #endif
    }()

    @Test(
        .enabled(if: BundleSignatureOpenSSLTests.opensslEnabled()),
        arguments: BundleSignatureOpenSSLTests.algorithms)
    func signVerifyWithOpenSSLKeys(algorithm: Bundle.SignatureAlgorithm) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let priv = dir.appendingPathComponent("priv.pem")
        let pub = dir.appendingPathComponent("pub.pem")

        switch algorithm.family {
        case .rsaPKCS1, .rsaPSS:
            #expect(
                try Self.openssl([
                    "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", priv.path,
                ]) == 0)
            #expect(try Self.openssl(["rsa", "-in", priv.path, "-pubout", "-out", pub.path]) == 0)
        case .ecdsa:
            #expect(try Self.openssl(["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", priv.path]) == 0)
            #expect(try Self.openssl(["ec", "-in", priv.path, "-pubout", "-out", pub.path]) == 0)
        case .hmac:
            return  // not applicable
        }

        let signingKey = Bundle.SigningKey.pem(try String(contentsOf: priv, encoding: .utf8))
        let verificationKey = Bundle.VerificationKey.pem(try String(contentsOf: pub, encoding: .utf8))

        let config = try Bundle.sign(files: Self.files, algorithm: algorithm, key: signingKey)
        try Bundle.verify(files: Self.files, signatures: config, key: verificationKey, algorithm: algorithm)
    }
}
