import AST
import Foundation

// See BundleSigning.swift for why RSA is gated behind the RSASignatures trait.
#if RSASignatures
    import CryptoExtras
#elseif canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

extension OPA.Bundle {
    /// Compact JWS header. `typ` is informational, `kid` optional.
    struct JWSHeader: Codable {
        var alg: String
        var typ: String?
        var kid: String?
    }

    /// Applies OPA's bundle-activation signature policy, matching the behavior table in
    /// the OPA docs. "Configured to verify" means a verification `key` is supplied.
    ///
    /// | `.signatures.json` present | key configured | result                         |
    /// | -------------------------- | -------------- | ------------------------------ |
    /// | no                         | no             | OK (no verification performed) |
    /// | no                         | yes            | throw (nothing to verify)      |
    /// | yes                        | no             | throw (unverified signed bundle) |
    /// | yes                        | yes            | run full verification          |
    ///
    /// - Parameter signatures: Parsed `.signatures.json`, or `nil`/empty when absent.
    /// - Parameter key: Verification key, or `nil` when not configured to verify.
    public static func verifyIfRequired(
        files: [BundleFile],
        signatures: BundleSignaturesConfig?,
        key: VerificationKey?,
        algorithm: SignatureAlgorithm = .default,
        scope: String? = nil,
        excludeFiles: Set<String> = []
    ) throws(BundleSignatureError) {
        // "Signed" means the `.signatures.json` file is present, even if its signatures
        // array is empty (an empty-but-present file still asserts signing intent, so it
        // must not be silently activated as unsigned).
        let hasSignatures = signatures != nil
        switch (hasSignatures, key) {
        case (false, nil):
            return  // NA: unsigned bundle, verification not configured.
        case (false, .some):
            // Configured to verify, but the bundle carries no signature.
            throw BundleSignatureError.noSignatures
        case (true, nil):
            // Signed bundle, but no key configured: must not activate unverified.
            throw BundleSignatureError.unverifiedSignedBundle
        case (true, .some(let key)):
            try verify(
                files: files, signatures: signatures!, key: key, algorithm: algorithm, scope: scope,
                excludeFiles: excludeFiles)
        }
    }

    /// Verifies a bundle's signature against a set of files, mirroring OPA's steps:
    /// check the JWS signature, confirm the payload's file set matches the bundle
    /// exactly, and confirm each file's hash. Throws ``BundleSignatureError`` on any
    /// failure and returns normally on success.
    ///
    /// - Parameters:
    ///   - files: The bundle files to verify (excluding `.signatures.json`).
    ///   - signatures: Parsed `.signatures.json` contents.
    ///   - key: Verification key material (HMAC secret or PEM public key).
    ///   - algorithm: Expected signing algorithm. The token header must match it.
    ///   - scope: If provided (out-of-band), must equal the payload's `scope`.
    ///   - excludeFiles: File names excluded from the file-set and hash checks.
    ///
    /// - Note: Only the first JWS in `.signatures.json` is verified, matching OPA's
    ///   current single-signature limitation.
    public static func verify(
        files: [BundleFile],
        signatures: BundleSignaturesConfig,
        key: VerificationKey,
        algorithm: SignatureAlgorithm = .default,
        scope: String? = nil,
        excludeFiles: Set<String> = []
    ) throws(BundleSignatureError) {
        guard let token = signatures.signatures.first else {
            throw BundleSignatureError.noSignatures
        }

        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
            let headerData = Data(base64URLNoPad: parts[0]),
            let payloadData = Data(base64URLNoPad: parts[1]),
            let signature = Data(base64URLNoPad: parts[2])
        else {
            throw BundleSignatureError.malformedToken("expected header.payload.signature")
        }

        let header: JWSHeader
        do {
            header = try JSONDecoder().decode(JWSHeader.self, from: headerData)
        } catch {
            throw BundleSignatureError.malformedToken("invalid header JSON")
        }
        guard let headerAlg = SignatureAlgorithm(rawValue: header.alg) else {
            throw BundleSignatureError.unsupportedAlgorithm(header.alg)
        }
        // Reject algorithm substitution: the token must use the expected algorithm.
        guard headerAlg == algorithm else {
            throw BundleSignatureError.algorithmMismatch(expected: algorithm.rawValue, got: header.alg)
        }

        // Signature is over the original (un-decoded) header and payload segments.
        let signingInput = Data((parts[0] + "." + parts[1]).utf8)
        guard try isValidSignature(signature, signingInput: signingInput, algorithm: algorithm, key: key) else {
            throw BundleSignatureError.invalidSignature
        }

        let payload: SignaturePayload
        do {
            payload = try JSONDecoder().decode(SignaturePayload.self, from: payloadData)
        } catch {
            throw BundleSignatureError.malformedToken("invalid payload JSON")
        }

        try checkFilesMatch(files: files, payload: payload, excludeFiles: excludeFiles)

        if let scope {
            guard payload.scope == scope else {
                throw BundleSignatureError.scopeMismatch(expected: scope, got: payload.scope)
            }
        }
    }

    /// Confirms the payload's file set matches the bundle exactly, then re-hashes and
    /// compares each covered file.
    private static func checkFilesMatch(
        files: [BundleFile], payload: SignaturePayload, excludeFiles: Set<String>
    ) throws(BundleSignatureError) {
        let excluded = excludeFiles.union([".signatures.json"])

        var byName: [String: BundleFile] = [:]
        for file in files {
            let name = signatureFileName(file.url)
            // Reject duplicate names so a shadowed file cannot pass verification unchecked.
            guard byName[name] == nil else {
                throw BundleSignatureError.duplicateFile(name)
            }
            byName[name] = file
        }

        let actualNames = Set(byName.keys).subtracting(excluded)
        let payloadNames = Set(payload.files.map(\.name)).subtracting(excluded)
        guard actualNames == payloadNames else {
            let missing = Array(payloadNames.subtracting(actualNames))
            let unexpected = Array(actualNames.subtracting(payloadNames))
            throw BundleSignatureError.fileSetMismatch(missing: missing, unexpected: unexpected)
        }

        for info in payload.files where !excluded.contains(info.name) {
            guard let algorithm = FileHashAlgorithm(rawValue: info.algorithm) else {
                throw BundleSignatureError.unsupportedAlgorithm(info.algorithm)
            }
            guard let file = byName[info.name] else {
                throw BundleSignatureError.fileSetMismatch(missing: [info.name], unexpected: [])
            }
            let actual = try fileDigest(name: info.name, data: file.data, algorithm: algorithm)
            guard actual == info.hash else {
                throw BundleSignatureError.hashMismatch(file: info.name)
            }
        }
    }

    static func isValidSignature(
        _ signature: Data, signingInput: Data, algorithm: SignatureAlgorithm, key: VerificationKey
    ) throws(BundleSignatureError) -> Bool {
        switch algorithm.family {
        case .hmac:
            guard case .hmac(let secret) = key else {
                throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires an HMAC secret")
            }
            let expected = hmacSignature(signingInput, algorithm: algorithm, secret: secret)
            // Fail closed: never treat an empty expected MAC as a match.
            return !expected.isEmpty && constantTimeEquals(expected, signature)
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                guard case .pem(let pem) = key else {
                    throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires a PEM public key")
                }
                return try rsaIsValid(signature, signingInput: signingInput, algorithm: algorithm, pem: pem)
            #else
                throw BundleSignatureError.unsupportedAlgorithm(
                    "\(algorithm.rawValue): RSA algorithms require the RSASignatures package trait")
            #endif
        case .ecdsa:
            guard case .pem(let pem) = key else {
                throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires a PEM public key")
            }
            return try ecdsaIsValid(signature, signingInput: signingInput, algorithm: algorithm, pem: pem)
        }
    }

    #if RSASignatures
        private static func rsaIsValid(
            _ signature: Data, signingInput: Data, algorithm: SignatureAlgorithm, pem: String
        ) throws(BundleSignatureError) -> Bool {
            let key: _RSA.Signing.PublicKey
            do {
                key = try _RSA.Signing.PublicKey(pemRepresentation: pem)
            } catch {
                throw BundleSignatureError.keyParsingFailed("\(error)")
            }
            let padding: _RSA.Signing.Padding = algorithm.family == .rsaPSS ? .PSS : .insecurePKCS1v1_5
            let sig = _RSA.Signing.RSASignature(rawRepresentation: signature)
            switch algorithm {
            case .rs256, .ps256:
                return key.isValidSignature(sig, for: SHA256.hash(data: signingInput), padding: padding)
            case .rs384, .ps384:
                return key.isValidSignature(sig, for: SHA384.hash(data: signingInput), padding: padding)
            case .rs512, .ps512:
                return key.isValidSignature(sig, for: SHA512.hash(data: signingInput), padding: padding)
            default: return false  // unreachable: guarded by family
            }
        }
    #endif

    private static func ecdsaIsValid(
        _ signature: Data, signingInput: Data, algorithm: SignatureAlgorithm, pem: String
    ) throws(BundleSignatureError) -> Bool {
        // Only the public-key parse throws here (mapped to keyParsingFailed). A malformed
        // signature is decoded with `try?` and treated as a plain verification failure.
        do {
            switch algorithm {
            case .es256:
                let key = try P256.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA256.hash(data: signingInput))
            case .es384:
                let key = try P384.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P384.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA384.hash(data: signingInput))
            case .es512:
                let key = try P521.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P521.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA512.hash(data: signingInput))
            default: return false  // unreachable: guarded by family
            }
        } catch {
            throw BundleSignatureError.keyParsingFailed("\(error)")
        }
    }
}

/// Compares two byte buffers with no data-dependent branch or early return (it ORs every
/// XOR difference into an accumulator via non-short-circuiting `reduce`), so timing does
/// not reveal where they first differ. The length check is fine as buffer lengths are not secret.
func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else {
        return false
    }
    return zip(a, b).reduce(into: UInt8(0)) { $0 |= $1.0 ^ $1.1 } == 0
}
