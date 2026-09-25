import AST
import BundleSigningInternals
import Foundation

extension OPA.Bundle {
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
    /// - Parameter signatures: Parsed `.signatures.json`, or `nil` when the file is absent.
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

    /// Verifies a bundle's signature against a set of files, mirroring OPA's steps: check the
    /// JWS signature (delegated to the internals layer, which also rejects algorithm
    /// substitution), confirm the payload's file set matches the bundle exactly, and confirm
    /// each file's hash. Throws ``BundleSignatureError`` on any failure and returns on success.
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

        // The internals layer verifies the JWS signature and enforces header.alg == expected,
        // returning the verified payload bytes. The bundle-level checks happen here.
        let payloadData: Data
        do {
            payloadData = try JWS.verify(token: token, algorithm: algorithm.jws, key: key.jws)
        } catch {
            throw BundleSignatureError(error)
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
}
