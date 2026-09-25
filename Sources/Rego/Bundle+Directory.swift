import AST
import Foundation

// Dependency-free directory read/write for bundles. Tarball (.tar.gz) support is
// intentionally omitted here to avoid needing a compression library dependency.

extension OPA.Bundle {
    /// Errors raised while loading or writing a bundle.
    public enum LoadError: Swift.Error {
        case unexpectedManifest(URL)
        case unexpectedData(URL)
        case manifestParseError(URL, Swift.Error)
        case dataParseError(URL, Swift.Error)
        case signaturesParseError(URL, Swift.Error)
        case dataEscapedRoot
        case unsupported(String)
        case unsafeBundlePath(String)
    }

    /// Loads a bundle from a directory. Reads `.manifest`, `data.json`, `plan.json`,
    /// `*.rego`, and `.signatures.json`, and preserves the original file bytes in
    /// ``OPA/Bundle/raw``.
    public static func decodeFromDirectory(fromDir: URL) throws -> OPA.Bundle {
        try BundleLoader.load(fromDirectory: fromDir)
    }

    /// Enumerates all signable files under a bundle directory (every regular file
    /// except `.signatures.json`), with bundle-relative URLs and raw bytes. This is
    /// the set that signing and verification operate over, matching OPA.
    public static func signableFiles(
        inDirectory url: URL, excluding: Set<String> = [".signatures.json"]
    ) throws -> [BundleFile] {
        try BundleLoader.enumerateFiles(inDirectory: url, excluding: excluding)
    }

    /// Writes a bundle to a directory (creating intermediate directories).
    ///
    /// When the bundle carries its original bytes (``OPA/Bundle/raw``), those files
    /// are written verbatim so the on-disk layout and hashes round-trip exactly.
    /// Otherwise the bundle is reconstructed from its manifest, data, rego, and plan
    /// files. A `.signatures.json` is (re)written whenever the bundle has signatures.
    ///
    /// Every write is checked to stay within `targetURL` to guard against path
    /// traversal from crafted bundle paths.
    ///
    /// - Note: When `raw == nil`, the bundle has to be reconstructed from its in-memory
    ///   representation, and will write a single `data.json` file to the bundle's root,
    ///   and will re-encode other structured files, so it will not be byte-accurate to
    ///   the original bundle in many cases. This can break signatures when the original
    ///   bundle split data across several `data.json` files. Bundles loaded through normal
    ///   means always have `raw` populated, and can be safely round-tripped with signatures.
    public static func encodeToDirectory(bundle: OPA.Bundle, targetURL: URL) throws {
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        let base = targetURL.standardizedFileURL

        func write(_ data: Data, toRelative relativePath: String) throws {
            var rel = relativePath
            while rel.hasPrefix("/") {
                rel.removeFirst()
            }
            // Lexical traversal check, then a resolved-path containment check.
            try validateBundlePathWithinRoot("/" + rel)
            let dest = targetURL.appendingPathComponent(rel, isDirectory: false).standardizedFileURL
            guard dest.path == base.path || dest.path.hasPrefix(base.path + "/") else {
                throw LoadError.unsafeBundlePath(relativePath)
            }
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: dest, options: .atomic)
        }

        if let raw = bundle.raw, !raw.isEmpty {
            for file in raw {
                try write(file.data, toRelative: signatureFileName(file.url))
            }
        } else {
            try write(try JSONEncoder().encode(bundle.manifest), toRelative: ".manifest")
            try write(try JSONEncoder().encode(bundle.data), toRelative: "data.json")
            for file in bundle.planFiles + bundle.regoFiles {
                try write(file.data, toRelative: signatureFileName(file.url))
            }
        }

        if let signatures = bundle.signatures {
            try write(try JSONEncoder().encode(signatures), toRelative: ".signatures.json")
        }
    }
}

/// Verifies that a bundle-relative path does not escape the bundle root via `..`
/// traversal. The check is purely lexical so it cannot be fooled by a
/// partially-written directory tree.
///
/// - Parameter path: A bundle-relative path with a leading `/`.
func validateBundlePathWithinRoot(_ path: String) throws {
    var depth = 0
    for segment in path.split(separator: "/", omittingEmptySubsequences: true) {
        switch segment {
        case ".":
            continue
        case "..":
            depth -= 1
            if depth < 0 {
                throw OPA.Bundle.LoadError.unsafeBundlePath(path)
            }
        default:
            depth += 1
        }
    }
}
