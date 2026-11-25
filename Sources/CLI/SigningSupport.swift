#if CLI
    import ArgumentParser
    import Foundation
    import Rego

    // Parse `--signing-alg` values (e.g. RS256) into the Rego algorithm enum. Uppercased
    // so `rs256` and `RS256` both work.
    extension OPA.Bundle.SignatureAlgorithm: ExpressibleByArgument {
        public init?(argument: String) {
            self.init(rawValue: argument.uppercased())
        }

        public static var allValueStrings: [String] { allCases.map(\.rawValue) }
    }

    enum SigningCLIError: Error, CustomStringConvertible {
        case noBundlePath
        case notADirectory(String)
        case keyReadFailed(String)
        case claimsReadFailed(String)
        case signaturesFileMissing(String)

        var description: String {
            switch self {
            case .noBundlePath:
                return "no bundle path provided; specify a bundle directory with -b/--bundle"
            case .notADirectory(let p):
                return "only directory bundles are supported yet: \(p) is not a directory"
            case .keyReadFailed(let p):
                return "could not read key file: \(p)"
            case .claimsReadFailed(let p):
                return "could not read claims file: \(p)"
            case .signaturesFileMissing(let p):
                return "no .signatures.json found in bundle directory: \(p)"
            }
        }
    }

    /// Resolves and validates a single bundle directory from CLI paths. Tarball inputs
    /// are not supported yet.
    func resolveBundleDirectory(_ paths: [String]) throws -> URL {
        guard let first = paths.first else {
            throw SigningCLIError.noBundlePath
        }
        let url = URL(fileURLWithPath: first)
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDir else {
            throw SigningCLIError.notADirectory(first)
        }
        return url
    }

    /// Reads key material: HMAC secret bytes for `HS*`, otherwise a PEM string.
    func loadSigningKey(path: String, algorithm: OPA.Bundle.SignatureAlgorithm) throws
        -> OPA.Bundle.SigningKey
    {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw SigningCLIError.keyReadFailed(path)
        }
        return algorithm.isHMAC ? .hmac(data) : .pem(String(decoding: data, as: UTF8.self))
    }

    func loadVerificationKey(path: String, algorithm: OPA.Bundle.SignatureAlgorithm) throws
        -> OPA.Bundle.VerificationKey
    {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw SigningCLIError.keyReadFailed(path)
        }
        return algorithm.isHMAC ? .hmac(data) : .pem(String(decoding: data, as: UTF8.self))
    }

    /// Emits a not-implemented warning for a flag to stderr.
    func warnFlagUnimplemented(_ flag: String) {
        FileHandle.standardError.write(Data("option `\(flag)` is not implemented.\n".utf8))
    }
#endif
