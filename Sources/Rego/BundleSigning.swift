import AST
import Foundation

// Base crypto (HMAC/SHA/ECDSA) comes from CryptoKit on Apple, else swift-crypto's Crypto.
// RSA (RS*/PS*) lives in swift-crypto's CryptoExtras, which is linked only when the
// RSASignatures trait is enabled. When it is off, RS*/PS* fail at runtime rather than forcing
// the BoringSSL-backed CryptoExtras dependency on every consumer. CryptoExtras re-exports
// Crypto, so importing it alone (when enabled) also provides HMAC/SHA/ECDSA and avoids a
// duplicate-symbol ambiguity. (The RSA type is still spelled `_RSA`.)
#if RSASignatures
    import CryptoExtras
#elseif canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

#if YAML
    import Yams
#endif

extension OPA.Bundle {
    /// JWS algorithm used to sign a bundle's `.signatures.json` token. Raw values
    /// are the JWS `alg` header names, matching OPA.
    public enum SignatureAlgorithm: String, Sendable, CaseIterable, Codable {
        case hs256 = "HS256"
        case hs384 = "HS384"
        case hs512 = "HS512"
        case rs256 = "RS256"
        case rs384 = "RS384"
        case rs512 = "RS512"
        case es256 = "ES256"
        case es384 = "ES384"
        case es512 = "ES512"
        case ps256 = "PS256"
        case ps384 = "PS384"
        case ps512 = "PS512"

        /// OPA's default signing algorithm.
        public static let `default`: SignatureAlgorithm = .rs256

        enum Family { case hmac, rsaPKCS1, rsaPSS, ecdsa }
        var family: Family {
            switch self {
            case .hs256, .hs384, .hs512: return .hmac
            case .rs256, .rs384, .rs512: return .rsaPKCS1
            case .ps256, .ps384, .ps512: return .rsaPSS
            case .es256, .es384, .es512: return .ecdsa
            }
        }

        /// True for the HMAC (`HS*`) families, whose key is a shared secret rather
        /// than a PEM-encoded asymmetric key.
        public var isHMAC: Bool { family == .hmac }
    }

    /// Hashing algorithm recorded per-file in a signature payload. Raw values match
    /// OPA's `algorithm` field names.
    public enum FileHashAlgorithm: String, Sendable, Codable {
        case sha256 = "SHA-256"
        case sha384 = "SHA-384"
        case sha512 = "SHA-512"

        public static let `default`: FileHashAlgorithm = .sha256
    }

    /// One entry in a signature payload's `files` list.
    public struct SignedFileInfo: Sendable, Hashable, Codable {
        public var name: String
        public var hash: String
        public var algorithm: String

        public init(name: String, hash: String, algorithm: String) {
            self.name = name
            self.hash = hash
            self.algorithm = algorithm
        }
    }

    /// Decoded JWS payload of a bundle signature. Only `files` is required. `scope`,
    /// `keyid`, `iat`, and `iss` are decoded best-effort, so an authentic token is not
    /// rejected over informational claims (per OPA, `iat`/`iss` are unused for verification,
    /// and RFC 7519 permits e.g. a fractional `iat`).
    public struct SignaturePayload: Sendable, Hashable, Codable {
        public var files: [SignedFileInfo]
        public var scope: String?
        public var keyid: String?
        public var iat: Int64?
        public var iss: String?

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            files = try c.decode([SignedFileInfo].self, forKey: .files)
            scope = (try? c.decodeIfPresent(String.self, forKey: .scope)) ?? nil
            keyid = (try? c.decodeIfPresent(String.self, forKey: .keyid)) ?? nil
            iat = (try? c.decodeIfPresent(Int64.self, forKey: .iat)) ?? nil
            iss = (try? c.decodeIfPresent(String.self, forKey: .iss)) ?? nil
        }
    }

    /// Key material for signing. HMAC families take a shared secret. Asymmetric
    /// families take a PEM-encoded private key.
    public enum SigningKey: Sendable {
        case hmac(Data)
        case pem(String)
    }

    /// Key material for verification. HMAC families take the shared secret.
    /// Asymmetric families take a PEM-encoded public key.
    public enum VerificationKey: Sendable {
        case hmac(Data)
        case pem(String)
    }

    public enum BundleSignatureError: Swift.Error, Equatable, CustomStringConvertible {
        case noSignatures
        case unverifiedSignedBundle
        case malformedToken(String)
        case unsupportedAlgorithm(String)
        case algorithmMismatch(expected: String, got: String)
        case keyMismatch(String)  // key type doesn't match the algorithm family
        case invalidSignature
        case fileSetMismatch(missing: [String], unexpected: [String])
        case hashMismatch(file: String)
        case scopeMismatch(expected: String?, got: String?)
        case keyParsingFailed(String)
        case invalidFile(name: String, message: String)
        case duplicateFile(String)

        public var description: String {
            switch self {
            case .noSignatures:
                return "no signatures found in .signatures.json"
            case .unverifiedSignedBundle:
                return "bundle is signed (.signatures.json present) but no verification key was configured"
            case .malformedToken(let m):
                return "malformed signature token: \(m)"
            case .unsupportedAlgorithm(let a):
                return "unsupported algorithm: \(a)"
            case .algorithmMismatch(let e, let g):
                return "algorithm mismatch: expected \(e), token uses \(g)"
            case .keyMismatch(let m):
                return "key does not match algorithm: \(m)"
            case .invalidSignature:
                return "signature verification failed"
            case .fileSetMismatch(let missing, let unexpected):
                return
                    "bundle files do not match signature: missing \(missing.sorted()), unexpected \(unexpected.sorted())"
            case .hashMismatch(let f):
                return "hash mismatch for file: \(f)"
            case .scopeMismatch(let e, let g):
                return "scope mismatch: expected \(e ?? "<none>"), token has \(g ?? "<none>")"
            case .keyParsingFailed(let m):
                return "failed to parse key: \(m)"
            case .invalidFile(let name, let message):
                return "cannot hash file \(name): \(message)"
            case .duplicateFile(let name):
                return "duplicate bundle file name: \(name)"
            }
        }
    }
}

// MARK: - File hashing

extension OPA.Bundle {
    /// Computes the hex digest of a single file per OPA's rules: structured files
    /// (JSON/YAML) are parsed and re-serialized with recursively sorted keys before
    /// hashing. All other files are hashed over their raw bytes.
    public static func fileDigest(
        name: String, data: Data, algorithm: FileHashAlgorithm = .default
    ) throws(BundleSignatureError) -> String {
        let bytes = try canonicalizedBytes(name: name, data: data)
        return digestHex(bytes, algorithm)
    }

    /// Builds a `SignedFileInfo` list for a set of bundle files. Throws on duplicate
    /// bundle-relative names so a shadowed file cannot ride along unsigned.
    public static func signedFileInfos(
        for files: [BundleFile], algorithm: FileHashAlgorithm = .default
    ) throws(BundleSignatureError) -> [SignedFileInfo] {
        var seen = Set<String>()
        var infos: [SignedFileInfo] = []
        infos.reserveCapacity(files.count)
        for file in files {
            let name = signatureFileName(file.url)
            guard seen.insert(name).inserted else {
                throw BundleSignatureError.duplicateFile(name)
            }
            let hash = try fileDigest(name: name, data: file.data, algorithm: algorithm)
            infos.append(SignedFileInfo(name: name, hash: hash, algorithm: algorithm.rawValue))
        }
        return infos
    }

    /// The bundle-relative name used in a signature payload (no leading slash).
    static func signatureFileName(_ url: URL) -> String {
        var s = url.relativePath
        while s.hasPrefix("/") {
            s.removeFirst()
        }
        return s
    }

    static func canonicalizedBytes(name: String, data: Data) throws(BundleSignatureError) -> Data {
        let lower = name.lowercased()
        // OPA treats JSON files and the root `.manifest` as structured: parse and
        // re-serialize into OPA's canonical form (sorted keys, verbatim number literals)
        // before hashing. Only the exact root `.manifest` is special-cased (matching OPA);
        // other `*.manifest` files are hashed raw.
        if lower.hasSuffix(".json") || name == ".manifest" {
            do {
                return try CanonicalJSON.canonicalize(data)
            } catch {
                throw BundleSignatureError.invalidFile(name: name, message: "\(error)")
            }
        }
        #if YAML
            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
                // Best-effort: YAML -> JSON via RegoValue, then canonicalize. Number-literal
                // fidelity is limited by RegoValue for YAML inputs.
                do {
                    let value = try YAMLDecoder().decode(
                        AST.RegoValue.self, from: String(decoding: data, as: UTF8.self))
                    return try CanonicalJSON.canonicalize(canonicalJSON(value))
                } catch {
                    throw BundleSignatureError.invalidFile(name: name, message: "\(error)")
                }
            }
        #endif
        return data
    }

    /// JSONEncoder-based canonical JSON (sorted keys, no slash escaping) used for the JWS
    /// header/payload and as the YAML-to-JSON intermediate. Structured-file *hashing* uses
    /// the byte-accurate `CanonicalJSON.canonicalize` instead (see `canonicalizedBytes`).
    static func canonicalJSON(_ v: AST.RegoValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .throw
        return try encoder.encode(v)
    }

    static func digestHex(_ data: Data, _ algorithm: FileHashAlgorithm) -> String {
        switch algorithm {
        case .sha256: return Data(SHA256.hash(data: data)).hexEncoded
        case .sha384: return Data(SHA384.hash(data: data)).hexEncoded
        case .sha512: return Data(SHA512.hash(data: data)).hexEncoded
        }
    }
}

// MARK: - Signing

extension OPA.Bundle {
    /// Signs a set of bundle files, producing a ``BundleSignaturesConfig`` containing
    /// a single compact JWS token (mirroring `opa sign`).
    public static func sign(
        files: [BundleFile],
        algorithm: SignatureAlgorithm = .default,
        fileHashAlgorithm: FileHashAlgorithm = .default,
        key: SigningKey,
        keyID: String? = nil,
        scope: String? = nil,
        additionalClaims: AST.RegoValue = .object([:])
    ) throws -> BundleSignaturesConfig {
        let infos = try signedFileInfos(for: files, algorithm: fileHashAlgorithm)
        let token = try generateSignedToken(
            files: infos, algorithm: algorithm, key: key, keyID: keyID, scope: scope,
            additionalClaims: additionalClaims)
        return BundleSignaturesConfig(signatures: [token], customPlugin: nil)
    }

    /// Builds a compact JWS token over a signature payload.
    public static func generateSignedToken(
        files: [SignedFileInfo],
        algorithm: SignatureAlgorithm = .default,
        key: SigningKey,
        keyID: String? = nil,
        scope: String? = nil,
        additionalClaims: AST.RegoValue = .object([:])
    ) throws -> String {
        let headerData = try encodeHeader(algorithm: algorithm, keyID: keyID)
        let payloadData = try encodePayload(
            files: files, scope: scope, keyID: keyID, additionalClaims: additionalClaims)

        let signingInput = Data((headerData.base64URLNoPad + "." + payloadData.base64URLNoPad).utf8)
        let signature = try computeSignature(signingInput, algorithm: algorithm, key: key)

        return headerData.base64URLNoPad + "." + payloadData.base64URLNoPad + "." + signature.base64URLNoPad
    }

    private static func encodeHeader(algorithm: SignatureAlgorithm, keyID: String?) throws -> Data {
        var obj: [AST.RegoValue: AST.RegoValue] = [
            .string("alg"): .string(algorithm.rawValue),
            .string("typ"): .string("JWT"),
        ]
        if let keyID {
            obj[.string("kid")] = .string(keyID)
        }
        return try canonicalJSON(.object(obj))
    }

    private static func encodePayload(
        files: [SignedFileInfo], scope: String?, keyID: String?, additionalClaims: AST.RegoValue
    ) throws -> Data {
        var obj: [AST.RegoValue: AST.RegoValue] = {
            if case .object(let o) = additionalClaims { return o }
            return [:]
        }()
        obj[.string("files")] = .array(
            files.map { info in
                .object([
                    .string("name"): .string(info.name),
                    .string("hash"): .string(info.hash),
                    .string("algorithm"): .string(info.algorithm),
                ])
            })
        if let scope {
            obj[.string("scope")] = .string(scope)
        }
        if let keyID {
            obj[.string("keyid")] = .string(keyID)
        }
        return try canonicalJSON(.object(obj))
    }

    static func computeSignature(
        _ signingInput: Data, algorithm: SignatureAlgorithm, key: SigningKey
    ) throws -> Data {
        switch algorithm.family {
        case .hmac:
            guard case .hmac(let secret) = key else {
                throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires an HMAC secret")
            }
            return hmacSignature(signingInput, algorithm: algorithm, secret: secret)
        case .rsaPKCS1, .rsaPSS:
            #if RSASignatures
                guard case .pem(let pem) = key else {
                    throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires a PEM private key")
                }
                return try rsaSignature(signingInput, algorithm: algorithm, pem: pem)
            #else
                throw BundleSignatureError.unsupportedAlgorithm(
                    "\(algorithm.rawValue): RSA algorithms require the RSASignatures package trait")
            #endif
        case .ecdsa:
            guard case .pem(let pem) = key else {
                throw BundleSignatureError.keyMismatch("\(algorithm.rawValue) requires a PEM private key")
            }
            return try ecdsaSignature(signingInput, algorithm: algorithm, pem: pem)
        }
    }

    /// Non-throwing HMAC over the signing input. Internal so verification can reuse it
    /// and compare in constant time without a throwing/optional path.
    static func hmacSignature(
        _ input: Data, algorithm: SignatureAlgorithm, secret: Data
    ) -> Data {
        let symmetricKey = SymmetricKey(data: secret)
        switch algorithm {
        case .hs256: return Data(HMAC<SHA256>.authenticationCode(for: input, using: symmetricKey))
        case .hs384: return Data(HMAC<SHA384>.authenticationCode(for: input, using: symmetricKey))
        case .hs512: return Data(HMAC<SHA512>.authenticationCode(for: input, using: symmetricKey))
        default: return Data()  // unreachable: guarded by family
        }
    }

    #if RSASignatures
        private static func rsaSignature(
            _ input: Data, algorithm: SignatureAlgorithm, pem: String
        ) throws -> Data {
            let key: _RSA.Signing.PrivateKey
            do {
                key = try _RSA.Signing.PrivateKey(pemRepresentation: pem)
            } catch {
                throw BundleSignatureError.keyParsingFailed("\(error)")
            }
            let padding: _RSA.Signing.Padding = algorithm.family == .rsaPSS ? .PSS : .insecurePKCS1v1_5
            switch algorithm {
            case .rs256, .ps256:
                return try key.signature(for: SHA256.hash(data: input), padding: padding).rawRepresentation
            case .rs384, .ps384:
                return try key.signature(for: SHA384.hash(data: input), padding: padding).rawRepresentation
            case .rs512, .ps512:
                return try key.signature(for: SHA512.hash(data: input), padding: padding).rawRepresentation
            default: return Data()  // unreachable: guarded by family
            }
        }
    #endif

    private static func ecdsaSignature(
        _ input: Data, algorithm: SignatureAlgorithm, pem: String
    ) throws -> Data {
        do {
            switch algorithm {
            case .es256:
                let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
                return try key.signature(for: SHA256.hash(data: input)).rawRepresentation
            case .es384:
                let key = try P384.Signing.PrivateKey(pemRepresentation: pem)
                return try key.signature(for: SHA384.hash(data: input)).rawRepresentation
            case .es512:
                let key = try P521.Signing.PrivateKey(pemRepresentation: pem)
                return try key.signature(for: SHA512.hash(data: input)).rawRepresentation
            default: return Data()  // unreachable: guarded by family
            }
        } catch let error as BundleSignatureError {
            throw error
        } catch {
            throw BundleSignatureError.keyParsingFailed("\(error)")
        }
    }
}

// MARK: - base64url (no padding), for JWS segments

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
