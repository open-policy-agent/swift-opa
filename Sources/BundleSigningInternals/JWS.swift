import Foundation

// Base crypto (HMAC/SHA/ECDSA) comes from CryptoKit on Apple, else swift-crypto's Crypto.
// RSA (RS*/PS*) lives in swift-crypto's CryptoExtras, linked only when the RSASignatures trait
// is enabled. When off, RSA algorithms throw at runtime. CryptoExtras re-exports Crypto, so
// importing it alone (when enabled) also provides HMAC/SHA/ECDSA. (The RSA type is spelled `_RSA`.)
#if RSASignatures
    import CryptoExtras
#elseif canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

/// Cryptographic family of a JWS algorithm.
public enum JWSFamily: Sendable { case hmac, rsaPKCS1, rsaPSS, ecdsa }

/// Digest used by a JWS algorithm.
public enum JWSHash: Sendable { case sha256, sha384, sha512 }

/// A JWS algorithm: its `alg` header name plus the crypto parameters to sign/verify with.
public struct JWSAlgorithm: Sendable {
    public let name: String  // JWS "alg" header value, e.g. "RS256"
    public let family: JWSFamily
    public let hash: JWSHash

    public init(name: String, family: JWSFamily, hash: JWSHash) {
        self.name = name
        self.family = family
        self.hash = hash
    }
}

/// Key material. HMAC uses a shared secret. Asymmetric families use a PEM-encoded key.
public enum JWSKey: Sendable {
    case hmac(Data)
    case pem(String)
}

public enum JWSError: Swift.Error, Equatable {
    case unsupportedAlgorithm(String)
    case algorithmMismatch(expected: String, got: String)
    case keyMismatch(String)
    case keyParsingFailed(String)
    case signingFailed(String)
    case invalidSignature
    case malformedToken(String)
}

/// Compact JWS (RFC 7515) signing/verification over raw payload bytes.
///
/// This is deliberately decoupled from OPA bundle types (it deals only in bytes, algorithm
/// descriptors, and key material) so the whole JWS mechanism can be reimplemented — e.g. via a
/// JWT library — without touching the public bundle-signing API in the Rego module.
public enum JWS {
    /// Signs `payload` bytes, producing a compact JWS token.
    public static func sign(payload: Data, algorithm: JWSAlgorithm, keyID: String?, key: JWSKey)
        throws(JWSError) -> String
    {
        let header = try encodeHeader(algorithm: algorithm, keyID: keyID)
        let signingInput = Data((header.base64URLNoPad + "." + payload.base64URLNoPad).utf8)
        let signature = try computeSignature(signingInput, algorithm: algorithm, key: key)
        return header.base64URLNoPad + "." + payload.base64URLNoPad + "." + signature.base64URLNoPad
    }

    /// Verifies a compact JWS token and returns the verified payload bytes. Enforces that the
    /// token header's `alg` equals `algorithm.name`, rejecting algorithm substitution.
    public static func verify(token: String, algorithm: JWSAlgorithm, key: JWSKey)
        throws(JWSError) -> Data
    {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
            let headerData = Data(base64URLNoPad: parts[0]),
            let payloadData = Data(base64URLNoPad: parts[1]),
            let signature = Data(base64URLNoPad: parts[2])
        else {
            throw .malformedToken("expected header.payload.signature")
        }

        let headerAlg: String
        do {
            headerAlg = try JSONDecoder().decode(Header.self, from: headerData).alg
        } catch {
            throw .malformedToken("invalid header JSON")
        }
        // A header alg that is not one of the recognized JWS algorithms is reported as
        // unsupported; a recognized-but-different alg is an algorithm-substitution mismatch.
        guard headerAlg == algorithm.name else {
            if recognizedAlgorithmNames.contains(headerAlg) {
                throw .algorithmMismatch(expected: algorithm.name, got: headerAlg)
            }
            throw .unsupportedAlgorithm(headerAlg)
        }

        // Signature is over the original (un-decoded) header and payload segments.
        let signingInput = Data((parts[0] + "." + parts[1]).utf8)
        guard try isValidSignature(signature, signingInput: signingInput, algorithm: algorithm, key: key) else {
            throw .invalidSignature
        }
        return payloadData
    }

    /// Hex digest of `data` under the given hash.
    public static func digest(_ data: Data, hash: JWSHash) -> String {
        switch hash {
        case .sha256: return hexEncode(Data(SHA256.hash(data: data)))
        case .sha384: return hexEncode(Data(SHA384.hash(data: data)))
        case .sha512: return hexEncode(Data(SHA512.hash(data: data)))
        }
    }

    /// Standard JWS `alg` names this implementation recognizes. Support may still be gated
    /// at signing/verification time (e.g. RSA behind the RSASignatures trait).
    static let recognizedAlgorithmNames: Set<String> = [
        "HS256", "HS384", "HS512",
        "RS256", "RS384", "RS512",
        "ES256", "ES384", "ES512",
        "PS256", "PS384", "PS512",
    ]
}

// MARK: - Header

extension JWS {
    private struct Header: Codable {
        let alg: String
        var typ: String? = "JWT"
        var kid: String?
    }

    private static func encodeHeader(algorithm: JWSAlgorithm, keyID: String?) throws(JWSError) -> Data {
        let header = Header(alg: algorithm.name, typ: "JWT", kid: keyID)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(header)
        } catch {
            throw .malformedToken("failed to encode header: \(error)")
        }
    }
}

// MARK: - Signing

extension JWS {
    static func computeSignature(_ signingInput: Data, algorithm: JWSAlgorithm, key: JWSKey)
        throws(JWSError) -> Data
    {
        switch algorithm.family {
        case .hmac:
            guard case .hmac(let secret) = key else {
                throw .keyMismatch("\(algorithm.name) requires an HMAC secret")
            }
            return hmacSignature(signingInput, hash: algorithm.hash, secret: secret)
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                guard case .pem(let pem) = key else {
                    throw .keyMismatch("\(algorithm.name) requires a PEM private key")
                }
                return try rsaSignature(signingInput, algorithm: algorithm, pem: pem)
            #else
                throw .unsupportedAlgorithm("\(algorithm.name): RSA algorithms require the RSASignatures package trait")
            #endif
        case .ecdsa:
            guard case .pem(let pem) = key else {
                throw .keyMismatch("\(algorithm.name) requires a PEM private key")
            }
            return try ecdsaSignature(signingInput, algorithm: algorithm, pem: pem)
        }
    }

    /// Non-throwing HMAC over the signing input (reused by verification for constant-time compare).
    static func hmacSignature(_ input: Data, hash: JWSHash, secret: Data) -> Data {
        let symmetricKey = SymmetricKey(data: secret)
        switch hash {
        case .sha256: return Data(HMAC<SHA256>.authenticationCode(for: input, using: symmetricKey))
        case .sha384: return Data(HMAC<SHA384>.authenticationCode(for: input, using: symmetricKey))
        case .sha512: return Data(HMAC<SHA512>.authenticationCode(for: input, using: symmetricKey))
        }
    }

    private static func ecdsaSignature(_ input: Data, algorithm: JWSAlgorithm, pem: String)
        throws(JWSError) -> Data
    {
        // Key parsing failures and signing failures are reported distinctly.
        switch algorithm.hash {
        case .sha256:
            let key: P256.Signing.PrivateKey
            do { key = try P256.Signing.PrivateKey(pemRepresentation: pem) } catch {
                throw .keyParsingFailed("\(error)")
            }
            do { return try key.signature(for: SHA256.hash(data: input)).rawRepresentation } catch {
                throw .signingFailed("\(error)")
            }
        case .sha384:
            let key: P384.Signing.PrivateKey
            do { key = try P384.Signing.PrivateKey(pemRepresentation: pem) } catch {
                throw .keyParsingFailed("\(error)")
            }
            do { return try key.signature(for: SHA384.hash(data: input)).rawRepresentation } catch {
                throw .signingFailed("\(error)")
            }
        case .sha512:
            let key: P521.Signing.PrivateKey
            do { key = try P521.Signing.PrivateKey(pemRepresentation: pem) } catch {
                throw .keyParsingFailed("\(error)")
            }
            do { return try key.signature(for: SHA512.hash(data: input)).rawRepresentation } catch {
                throw .signingFailed("\(error)")
            }
        }
    }

    #if RSASignatures
        private static func rsaSignature(_ input: Data, algorithm: JWSAlgorithm, pem: String)
            throws(JWSError) -> Data
        {
            let key: _RSA.Signing.PrivateKey
            do {
                key = try _RSA.Signing.PrivateKey(pemRepresentation: pem)
            } catch {
                throw .keyParsingFailed("\(error)")
            }
            let padding: _RSA.Signing.Padding = algorithm.family == .rsaPSS ? .PSS : .insecurePKCS1v1_5
            do {
                switch algorithm.hash {
                case .sha256:
                    return try key.signature(for: SHA256.hash(data: input), padding: padding).rawRepresentation
                case .sha384:
                    return try key.signature(for: SHA384.hash(data: input), padding: padding).rawRepresentation
                case .sha512:
                    return try key.signature(for: SHA512.hash(data: input), padding: padding).rawRepresentation
                }
            } catch {
                throw .signingFailed("\(error)")
            }
        }
    #endif
}

// MARK: - Verification

extension JWS {
    static func isValidSignature(
        _ signature: Data, signingInput: Data, algorithm: JWSAlgorithm, key: JWSKey
    ) throws(JWSError) -> Bool {
        switch algorithm.family {
        case .hmac:
            guard case .hmac(let secret) = key else {
                throw .keyMismatch("\(algorithm.name) requires an HMAC secret")
            }
            let expected = hmacSignature(signingInput, hash: algorithm.hash, secret: secret)
            // Fail closed: never treat an empty expected MAC as a match.
            return !expected.isEmpty && constantTimeEquals(expected, signature)
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                guard case .pem(let pem) = key else {
                    throw .keyMismatch("\(algorithm.name) requires a PEM public key")
                }
                return try rsaIsValid(signature, signingInput: signingInput, algorithm: algorithm, pem: pem)
            #else
                throw .unsupportedAlgorithm("\(algorithm.name): RSA algorithms require the RSASignatures package trait")
            #endif
        case .ecdsa:
            guard case .pem(let pem) = key else {
                throw .keyMismatch("\(algorithm.name) requires a PEM public key")
            }
            return try ecdsaIsValid(signature, signingInput: signingInput, algorithm: algorithm, pem: pem)
        }
    }

    private static func ecdsaIsValid(
        _ signature: Data, signingInput: Data, algorithm: JWSAlgorithm, pem: String
    ) throws(JWSError) -> Bool {
        // Only the public-key parse throws here (mapped to keyParsingFailed). A malformed
        // signature is decoded with `try?` and treated as a plain verification failure.
        do {
            switch algorithm.hash {
            case .sha256:
                let key = try P256.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA256.hash(data: signingInput))
            case .sha384:
                let key = try P384.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P384.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA384.hash(data: signingInput))
            case .sha512:
                let key = try P521.Signing.PublicKey(pemRepresentation: pem)
                guard let sig = try? P521.Signing.ECDSASignature(rawRepresentation: signature) else {
                    return false
                }
                return key.isValidSignature(sig, for: SHA512.hash(data: signingInput))
            }
        } catch {
            throw .keyParsingFailed("\(error)")
        }
    }

    #if RSASignatures
        private static func rsaIsValid(
            _ signature: Data, signingInput: Data, algorithm: JWSAlgorithm, pem: String
        ) throws(JWSError) -> Bool {
            let key: _RSA.Signing.PublicKey
            do {
                key = try _RSA.Signing.PublicKey(pemRepresentation: pem)
            } catch {
                throw .keyParsingFailed("\(error)")
            }
            let padding: _RSA.Signing.Padding = algorithm.family == .rsaPSS ? .PSS : .insecurePKCS1v1_5
            let sig = _RSA.Signing.RSASignature(rawRepresentation: signature)
            switch algorithm.hash {
            case .sha256:
                return key.isValidSignature(sig, for: SHA256.hash(data: signingInput), padding: padding)
            case .sha384:
                return key.isValidSignature(sig, for: SHA384.hash(data: signingInput), padding: padding)
            case .sha512:
                return key.isValidSignature(sig, for: SHA512.hash(data: signingInput), padding: padding)
            }
        }
    #endif
}

// MARK: - Helpers

/// Constant-time comparison with no data-dependent branch or early return (it ORs every XOR
/// difference into an accumulator via non-short-circuiting `reduce`), so timing does not reveal
/// where the buffers first differ. The length check is fine as buffer lengths are not secret.
func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else {
        return false
    }
    return zip(a, b).reduce(into: UInt8(0)) { $0 |= $1.0 ^ $1.1 } == 0
}

private func hexEncode(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

extension Data {
    /// URL-safe base64 without padding, as required for JWS compact serialization.
    var base64URLNoPad: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes URL-safe base64 (padded or unpadded).
    init?(base64URLNoPad string: String) {
        var s =
            string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder != 0 {
            s += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: s)
    }
}
