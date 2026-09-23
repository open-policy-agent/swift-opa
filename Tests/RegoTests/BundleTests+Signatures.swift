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

@Suite("BundleTests - Signatures")
struct BundleSignatureTests {
    typealias Bundle = OPA.Bundle

    // MARK: Fixtures

    private static let bundleBase = URL(fileURLWithPath: "/bundle")

    /// Builds a bundle file with a clean bundle-relative URL (matching the loader).
    static func bf(_ name: String, _ contents: String) -> BundleFile {
        let child = URL(fileURLWithPath: "/bundle/\(name)")
        let rel = makeRelativeURL(from: bundleBase, to: child)!
        return BundleFile(url: rel, data: Data(contents.utf8))
    }

    static let files: [BundleFile] = [
        bf(".manifest", #"{"roots":[""],"rego_version":1}"#),
        bf("data.json", #"{"roles":{"admin":["read","write"]}}"#),
        bf("policy.rego", "package example\n\nallow := true\n"),
    ]

    // MARK: Key material (generated in-process)

    struct KeyPair {
        let signing: Bundle.SigningKey
        let verification: Bundle.VerificationKey
    }

    static func keyPair(for algorithm: Bundle.SignatureAlgorithm) throws -> KeyPair {
        switch algorithm.family {
        case .hmac:
            let secret = Data("this-is-a-shared-hmac-secret-value".utf8)
            return KeyPair(signing: .hmac(secret), verification: .hmac(secret))
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
                return KeyPair(
                    signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation))
            #else
                fatalError("RSA key generation requires the RSASignatures trait")
            #endif
        case .ecdsa:
            switch algorithm {
            case .es256:
                let key = P256.Signing.PrivateKey()
                return KeyPair(
                    signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation))
            case .es384:
                let key = P384.Signing.PrivateKey()
                return KeyPair(
                    signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation))
            default:
                let key = P521.Signing.PrivateKey()
                return KeyPair(
                    signing: .pem(key.pemRepresentation), verification: .pem(key.publicKey.pemRepresentation))
            }
        }
    }

    // MARK: Round-trip for every algorithm

    /// Algorithms exercised here. RSA (RS*/PS*) only when the RSASignatures trait is on.
    static let algorithmsUnderTest: [Bundle.SignatureAlgorithm] = {
        #if RSASignatures
            return Bundle.SignatureAlgorithm.allCases
        #else
            return [.hs256, .hs384, .hs512, .es256, .es384, .es512]
        #endif
    }()

    /// One representative algorithm per family (HMAC, ECDSA), plus RSA only when the
    /// RSASignatures trait is enabled. Used by tests that need per-family coverage.
    static let representativeAlgorithms: [Bundle.SignatureAlgorithm] = {
        #if RSASignatures
            return [.hs256, .rs256, .es256]
        #else
            return [.hs256, .es256]
        #endif
    }()

    @Test(arguments: BundleSignatureTests.algorithmsUnderTest)
    func signVerifyRoundTrip(algorithm: Bundle.SignatureAlgorithm) throws {
        let keys = try Self.keyPair(for: algorithm)
        let config = try Bundle.sign(files: Self.files, algorithm: algorithm, key: keys.signing)

        #expect(config.signatures.count == 1)
        #expect(config.signatures[0].split(separator: ".").count == 3)

        // Should not throw.
        try Bundle.verify(files: Self.files, signatures: config, key: keys.verification, algorithm: algorithm)
    }

    #if !RSASignatures
        @Test
        func rsaAlgorithmsFailGracefullyWhenDisabled() throws {
            // Signing with an RSA alg throws instead of failing to compile.
            #expect(throws: Bundle.BundleSignatureError.self) {
                _ = try Bundle.sign(files: Self.files, algorithm: .rs256, key: .pem("unused"))
            }
            // Verifying an RS256 token also fails at the signature step.
            let token =
                Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8).base64URLNoPad + "."
                + Data(#"{"files":[]}"#.utf8).base64URLNoPad + "." + Data("sig".utf8).base64URLNoPad
            let config = Bundle.BundleSignaturesConfig(signatures: [token])
            #expect(throws: Bundle.BundleSignatureError.self) {
                try Bundle.verify(files: Self.files, signatures: config, key: .pem("unused"), algorithm: .rs256)
            }
        }
    #endif

    // MARK: Negatives

    @Test(arguments: BundleSignatureTests.representativeAlgorithms)
    func wrongKeyFailsVerification(algorithm: Bundle.SignatureAlgorithm) throws {
        let signer = try Self.keyPair(for: algorithm)
        let config = try Bundle.sign(files: Self.files, algorithm: algorithm, key: signer.signing)

        // A genuinely different key. HMAC key material is constant in `keyPair`, so
        // derive a distinct secret here. Asymmetric keys are freshly random per call.
        let wrong: Bundle.VerificationKey
        switch algorithm.family {
        case .hmac:
            wrong = .hmac(Data("a-completely-different-hmac-secret".utf8))
        default:
            wrong = try Self.keyPair(for: algorithm).verification
        }

        #expect(throws: Bundle.BundleSignatureError.invalidSignature) {
            try Bundle.verify(files: Self.files, signatures: config, key: wrong, algorithm: algorithm)
        }
    }

    @Test
    func mutatedFileFailsVerification() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        var mutated = Self.files
        mutated[1] = Self.bf("data.json", #"{"roles":{"admin":["read"]}}"#)  // dropped "write"

        #expect(throws: Bundle.BundleSignatureError.hashMismatch(file: "data.json")) {
            try Bundle.verify(files: mutated, signatures: config, key: keys.verification, algorithm: .hs256)
        }
    }

    @Test
    func extraFileFailsVerification() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        var extra = Self.files
        extra.append(Self.bf("extra.rego", "package extra\n"))

        #expect(throws: Bundle.BundleSignatureError.self) {
            try Bundle.verify(files: extra, signatures: config, key: keys.verification, algorithm: .hs256)
        }
    }

    @Test
    func missingFileFailsVerification() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        let missing = Array(Self.files.dropLast())

        #expect(throws: Bundle.BundleSignatureError.self) {
            try Bundle.verify(files: missing, signatures: config, key: keys.verification, algorithm: .hs256)
        }
    }

    @Test
    func excludedFileIsNotVerified() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        var withExtra = Self.files
        withExtra.append(Self.bf("README.md", "docs"))

        // Excluding the unsigned extra file lets verification pass.
        try Bundle.verify(
            files: withExtra, signatures: config, key: keys.verification, algorithm: .hs256,
            excludeFiles: ["README.md"])
    }

    @Test
    func algorithmMismatchIsRejected() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        // Token header says HS256 but caller expects RS256.
        #expect(throws: Bundle.BundleSignatureError.self) {
            try Bundle.verify(files: Self.files, signatures: config, key: keys.verification, algorithm: .rs256)
        }
    }

    @Test
    func scopeRoundTripAndMismatch() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing, scope: "read")

        // Matching scope verifies.
        try Bundle.verify(
            files: Self.files, signatures: config, key: keys.verification, algorithm: .hs256, scope: "read")

        // Mismatched scope fails.
        #expect(throws: Bundle.BundleSignatureError.self) {
            try Bundle.verify(
                files: Self.files, signatures: config, key: keys.verification, algorithm: .hs256, scope: "write")
        }
    }

    @Test
    func noSignaturesThrows() throws {
        let keys = try Self.keyPair(for: .hs256)
        let empty = Bundle.BundleSignaturesConfig(signatures: [])
        #expect(throws: Bundle.BundleSignatureError.noSignatures) {
            try Bundle.verify(files: Self.files, signatures: empty, key: keys.verification, algorithm: .hs256)
        }
    }

    @Test
    func duplicateFileNameRejected() throws {
        let keys = try Self.keyPair(for: .hs256)

        // Signing rejects duplicate bundle-relative names.
        let dupFiles = [Self.bf("data.json", "{}"), Self.bf("data.json", "{}")]
        #expect(throws: Bundle.BundleSignatureError.duplicateFile("data.json")) {
            _ = try Bundle.sign(files: dupFiles, algorithm: .hs256, key: keys.signing)
        }

        // Verification rejects a duplicate too (a shadowed file must not ride along unchecked).
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)
        let dup = Self.files + [Self.bf("policy.rego", "different")]
        #expect(throws: Bundle.BundleSignatureError.duplicateFile("policy.rego")) {
            try Bundle.verify(files: dup, signatures: config, key: keys.verification, algorithm: .hs256)
        }
    }

    @Test
    func verificationToleratesNonStandardClaims() throws {
        let keys = try Self.keyPair(for: .hs256)
        // A fractional iat (RFC 7519 permits it) and a numeric iss must not break payload
        // decode: the signature is still valid and iat/iss are unused for verification.
        let claims = try AST.RegoValue(jsonData: Data(#"{"iat":1.5,"iss":123}"#.utf8))
        let config = try Bundle.sign(
            files: Self.files, algorithm: .hs256, key: keys.signing, additionalClaims: claims)
        try Bundle.verify(files: Self.files, signatures: config, key: keys.verification, algorithm: .hs256)
    }

    @Test
    func emptySignaturesFileIsTreatedAsSigned() throws {
        let keys = try Self.keyPair(for: .hs256)
        let empty = Bundle.BundleSignaturesConfig(signatures: [])
        // Present-but-empty .signatures.json with no key configured must fail, not activate.
        #expect(throws: Bundle.BundleSignatureError.unverifiedSignedBundle) {
            try Bundle.verifyIfRequired(files: Self.files, signatures: empty, key: nil)
        }
        // With a key it fails because there is no actual signature to check.
        #expect(throws: Bundle.BundleSignatureError.noSignatures) {
            try Bundle.verifyIfRequired(
                files: Self.files, signatures: empty, key: keys.verification, algorithm: .hs256)
        }
        // A truly absent file (nil) with no key is the only "unsigned, OK" case.
        try Bundle.verifyIfRequired(files: Self.files, signatures: nil, key: nil)
    }

    // MARK: OPA bundle-activation behavior table
    //
    // | .signatures.json | configured (key) | result                    |
    // | ---------------- | ---------------- | ------------------------- |
    // | no               | no               | NA (no verification)      |
    // | no               | yes              | fail                      |
    // | yes              | no               | fail                      |
    // | yes              | yes              | depends (verify steps)    |

    @Test("row 1: unsigned bundle, not configured to verify -> NA")
    func tableRowUnsignedNotConfigured() throws {
        // "Unsigned" == no .signatures.json file at all (nil). A present-but-empty file is
        // treated as signed (row 3), covered by emptySignaturesFileIsTreatedAsSigned.
        try Bundle.verifyIfRequired(files: Self.files, signatures: nil, key: nil)
    }

    @Test("row 2: unsigned bundle, configured to verify -> fail")
    func tableRowUnsignedButConfigured() throws {
        let keys = try Self.keyPair(for: .hs256)
        #expect(throws: Bundle.BundleSignatureError.noSignatures) {
            try Bundle.verifyIfRequired(
                files: Self.files, signatures: nil, key: keys.verification, algorithm: .hs256)
        }
        #expect(throws: Bundle.BundleSignatureError.noSignatures) {
            try Bundle.verifyIfRequired(
                files: Self.files, signatures: Bundle.BundleSignaturesConfig(signatures: []),
                key: keys.verification, algorithm: .hs256)
        }
    }

    @Test("row 3: signed bundle, not configured to verify -> fail")
    func tableRowSignedNotConfigured() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)
        #expect(throws: Bundle.BundleSignatureError.unverifiedSignedBundle) {
            try Bundle.verifyIfRequired(files: Self.files, signatures: config, key: nil)
        }
    }

    @Test("row 4: signed bundle, configured to verify -> depends on verification steps")
    func tableRowSignedAndConfigured() throws {
        let keys = try Self.keyPair(for: .hs256)
        let config = try Bundle.sign(files: Self.files, algorithm: .hs256, key: keys.signing)

        // Valid signature verifies.
        try Bundle.verifyIfRequired(
            files: Self.files, signatures: config, key: keys.verification, algorithm: .hs256)

        // Tampered content fails.
        var mutated = Self.files
        mutated[1] = Self.bf("data.json", #"{"roles":{"admin":["read"]}}"#)
        #expect(throws: Bundle.BundleSignatureError.hashMismatch(file: "data.json")) {
            try Bundle.verifyIfRequired(
                files: mutated, signatures: config, key: keys.verification, algorithm: .hs256)
        }
    }

    // MARK: File digest canonicalization

    @Test
    func canonicalJSONPreservesNumberLiteralsAndSortsKeysByBytes() throws {
        // Numbers verbatim (1.0 not 1, 1e3 not 1000, big int intact). Keys sorted by
        // UTF-8 byte order (Z < a < b).
        let out = try CanonicalJSON.canonicalize(
            Data(#"{ "b": 1.0, "a": 1e3, "Z": 10000000000000000000 }"#.utf8))
        #expect(
            String(decoding: out, as: UTF8.self) == #"{"Z":10000000000000000000,"a":1e3,"b":1.0}"#)
    }

    @Test
    func canonicalJSONStringEscaping() throws {
        // `<>&/` and non-ASCII stay raw. A normalizes to A. `\n` stays short-escaped.
        let out = try CanonicalJSON.canonicalize(Data(#"{"k":"a<b>c&d/eA\n"}"#.utf8))
        #expect(String(decoding: out, as: UTF8.self) == #"{"k":"a<b>c&d/eA\n"}"#)
    }

    @Test
    func structuredJSONDigestIsWhitespaceAndOrderIndependent() throws {
        let a = Data(#"{"b":2,"a":1}"#.utf8)
        let b = Data("{\n  \"a\": 1,\n  \"b\": 2\n}".utf8)  // reordered + whitespace
        let da = try Bundle.fileDigest(name: "data.json", data: a)
        let db = try Bundle.fileDigest(name: "data.json", data: b)
        #expect(da == db)
    }

    @Test
    func unstructuredDigestIsOverRawBytes() throws {
        let a = Data("package x\nallow := true\n".utf8)
        let b = Data("package x\nallow  :=  true\n".utf8)  // whitespace differs
        let da = try Bundle.fileDigest(name: "policy.rego", data: a)
        let db = try Bundle.fileDigest(name: "policy.rego", data: b)
        #expect(da != db)
    }

    @Test
    func base64URLRoundTrips() throws {
        let raw = Data((0...255).map { UInt8($0) })
        let encoded = raw.base64URLNoPad
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(Data(base64URLNoPad: encoded) == raw)
    }

    // MARK: Directory round-trip (sign on disk, load, verify, re-encode, verify)

    static func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Signs the bundle directory at `dir` in place, writing `.signatures.json`.
    static func signDirectory(
        _ dir: URL, algorithm: Bundle.SignatureAlgorithm, key: Bundle.SigningKey
    ) throws {
        let files = try Bundle.signableFiles(inDirectory: dir)
        let config = try Bundle.sign(files: files, algorithm: algorithm, key: key)
        let data = try JSONEncoder().encode(config)
        try data.write(to: dir.appendingPathComponent(".signatures.json"), options: .atomic)
    }

    @Test(arguments: BundleSignatureTests.representativeAlgorithms)
    func directoryRoundTrip(algorithm: Bundle.SignatureAlgorithm) throws {
        let keys = try Self.keyPair(for: algorithm)

        // Materialize an in-memory bundle to a directory.
        let dirA = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dirA) }
        let bundle = try OPA.Bundle(
            manifest: OPA.Manifest(roots: [""]),
            regoFiles: [Self.bf("policy.rego", "package example\nallow := true\n")],
            data: .object([.string("roles"): .object([.string("admin"): .array([.string("read")])])]))
        try OPA.Bundle.encodeToDirectory(bundle: bundle, targetURL: dirA)

        // Sign it on disk, then load it back (signatures + raw are populated).
        try Self.signDirectory(dirA, algorithm: algorithm, key: keys.signing)
        let loaded = try OPA.Bundle.decodeFromDirectory(fromDir: dirA)
        let signatures = try #require(loaded.signatures)
        #expect(loaded.raw != nil)

        // Verify against the enumerated on-disk files.
        let filesA = try OPA.Bundle.signableFiles(inDirectory: dirA)
        try OPA.Bundle.verify(files: filesA, signatures: signatures, key: keys.verification, algorithm: algorithm)

        // Re-encode to a fresh directory (byte-faithful via raw) and verify again.
        let dirB = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dirB) }
        try OPA.Bundle.encodeToDirectory(bundle: loaded, targetURL: dirB)
        let reloaded = try OPA.Bundle.decodeFromDirectory(fromDir: dirB)
        let filesB = try OPA.Bundle.signableFiles(inDirectory: dirB)
        try OPA.Bundle.verify(
            files: filesB, signatures: try #require(reloaded.signatures), key: keys.verification,
            algorithm: algorithm)

        // Tampering on disk breaks verification.
        try Data("package example\nallow := false\n".utf8).write(
            to: dirB.appendingPathComponent("policy.rego"), options: .atomic)
        let tampered = try OPA.Bundle.signableFiles(inDirectory: dirB)
        #expect(throws: OPA.Bundle.BundleSignatureError.self) {
            try OPA.Bundle.verify(
                files: tampered, signatures: try #require(reloaded.signatures), key: keys.verification,
                algorithm: algorithm)
        }
    }

    @Test
    func encodeToDirectoryRejectsTraversalPaths() throws {
        #expect(throws: OPA.Bundle.LoadError.self) {
            try validateBundlePathWithinRoot("/../escape")
        }
        // A benign path with interior ".." that stays within root is allowed.
        try validateBundlePathWithinRoot("/a/b/../c")
    }
}
