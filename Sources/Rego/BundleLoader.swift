import AST
import Foundation

package struct BundleLoader {
    var bundleFiles: any Sequence<Result<BundleFile, any Swift.Error>>

    init(fromFileSequence files: any Sequence<Result<BundleFile, any Swift.Error>>) {
        self.bundleFiles = files
    }

    // LoadError is defined publicly on OPA.Bundle. This
    // alias keeps the existing unqualified `LoadError.x` references working.
    typealias LoadError = OPA.Bundle.LoadError

    func load() throws -> OPA.Bundle {
        // Unwrap files, throw first error if we encounter one
        let files: [BundleFile] = try bundleFiles.map { try $0.get() }

        // TODO Boo, no fun functional shenanigans :(
        //        var regoFiles: [BundleFile] = files.filter({$0.url.pathExtension == "rego"})
        //        var planFiles: [BundleFile] = files.filter({$0.url.lastPathComponent == "plan.json"})
        //        var manifest: Manifest? = try files.first(where: {$0.url.lastPathComponent == ".manifest"})
        //            .flatMap{ try Manifest(from: $0.data) }

        // TODO how do we know what the root is to ensure that .manifest is at the root?

        var regoFiles: [BundleFile] = []
        var planFiles: [BundleFile] = []
        var manifest: OPA.Manifest?
        var data: AST.RegoValue = AST.RegoValue.object([:])
        var signatures: OPA.Bundle.BundleSignaturesConfig?
        // Original bytes of the signable files (everything except .signatures.json),
        // preserved for signature verification and round-tripping.
        var rawFiles: [BundleFile] = []

        for f in files {
            // .signatures.json is metadata about the other files, not itself signed.
            if f.url.lastPathComponent == ".signatures.json" {
                do {
                    signatures = try JSONDecoder().decode(
                        OPA.Bundle.BundleSignaturesConfig.self, from: f.data)
                } catch {
                    throw LoadError.signaturesParseError(f.url, error)
                }
                continue
            }

            rawFiles.append(f)

            switch f.url.lastPathComponent {
            case ".manifest":
                guard manifest == nil else {
                    // Only allow a single manifest in the bundle
                    throw LoadError.unexpectedManifest(f.url)
                }
                guard f.url.relativePath == ".manifest" else {
                    // Manifest must be at the root of the bundle
                    throw LoadError.unexpectedManifest(f.url)
                }

                manifest = try OPA.Manifest(from: f.data)

            case "data.json":
                // Parse JSON into AST values
                var parsed: AST.RegoValue
                do {
                    parsed = try AST.RegoValue(jsonData: f.data)
                } catch {
                    throw LoadError.dataParseError(f.url, error)
                }

                // Determine the relative path and patch the data into the data tree
                let relPath = f.url.relativePath.split(separator: "/").dropLast().map { String($0) }
                data = data.patch(with: parsed, at: relPath)

            case "plan.json":
                planFiles.append(f)

            default:
                if f.url.pathExtension != "rego" {
                    break
                }
                regoFiles.append(f)
            }
        }

        regoFiles.sort(by: { $0.url.path < $1.url.path })
        planFiles.sort(by: { $0.url.path < $1.url.path })
        rawFiles.sort(by: { $0.url.relativePath < $1.url.relativePath })

        manifest = manifest ?? OPA.Manifest()  // Default manifest if none was provided
        let bundle = try OPA.Bundle(
            manifest: manifest!, planFiles: planFiles, regoFiles: regoFiles, data: data,
            signatures: signatures, raw: rawFiles.isEmpty ? nil : rawFiles)

        // Ensure the bundle's data is contained under the bundle roots.
        try bundle.validate()

        return bundle
    }

    package static func load(fromDirectory url: URL) throws -> OPA.Bundle {
        let files = DirectoryLoader(baseURL: url)
        var bundle = try BundleLoader(fromFileSequence: files).load()
        // `raw` must reflect the full signable set (every file except .signatures.json),
        // not just the recognized bundle files, so round-tripping and signature
        // verification cover files the DirectoryLoader filter drops (e.g. data.yaml,
        // README.md). Signing/verification enumerate the same way (see enumerateFiles).
        bundle.raw = try enumerateFiles(inDirectory: url)
        return bundle
    }

    // Accept either a directory to load a bundle from or a path to an individual file
    // which will be treated as a bundle tarball.
    package static func load(fromFile url: URL) throws -> OPA.Bundle {
        let isDir = (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false
        if isDir {
            return try load(fromDirectory: url)
        }
        throw LoadError.unsupported("only directories can be loaded as bundles")
    }

    /// Enumerates every regular file under a bundle directory, returning bundle files
    /// with bundle-relative URLs and their raw bytes. Unlike ``load(fromDirectory:)``,
    /// this does not filter by kind: it returns the full set of files except
    /// `.signatures.json`, just like OPA does during signing/verification.
    ///
    /// - Note: Every regular file is included, including dotfiles, which matches OPA
    ///   (`opa sign` applies no filter and signs every file). One interop caveat: when
    ///   invoked as `opa sign -b .`, OPA strips a single leading `.` from top-level
    ///   dotfile names (`.hidden` -> `hidden`, `.git/config` -> `git/config`) as an
    ///   artifact of its path handling, except `.manifest`/`.manifest.pb`, which it
    ///   restores. We keep the real names, so signatures for bundles that contain stray
    ///   top-level dotfiles (e.g. a `.git` directory) will not match OPA. Sign clean
    ///   bundle directories.
    ///
    /// - Parameters:
    ///   - baseURL: The bundle directory.
    ///   - excluding: File names (relative path or last component) to skip. Defaults
    ///     to `.signatures.json`.
    static func enumerateFiles(
        inDirectory baseURL: URL, excluding: Set<String> = [".signatures.json"]
    ) throws -> [BundleFile] {
        let base = baseURL.resolvingSymlinksInPath()
        guard
            let enumerator = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: [.isRegularFileKey], options: [])
        else {
            throw LoadError.unsupported("cannot enumerate directory \(base.path)")
        }

        var out: [BundleFile] = []
        for case let fileURL as URL in enumerator {
            let isRegular = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isRegular else {
                continue
            }
            guard let relativeURL = makeRelativeURL(from: base, to: fileURL) else {
                continue
            }
            if excluding.contains(relativeURL.relativePath) || excluding.contains(fileURL.lastPathComponent) {
                continue
            }
            let data = try Data(contentsOf: fileURL)
            out.append(BundleFile(url: relativeURL, data: data))
        }
        out.sort { $0.url.relativePath < $1.url.relativePath }
        return out
    }
}

// DirectoryLoader returns a sequence of OPA bundle files from a directory,
// while filtering out non-bundle-related files.
// I/O errors are propogated as failure cases of the results.
struct DirectoryLoader: Sequence {
    let baseURL: URL
    let keepFiles = Set(["data.json", "plan.json", ".manifest", ".signatures.json"])
    let keepExtensions = Set(["rego"])

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func makeIterator() -> AnyIterator<Result<BundleFile, any Swift.Error>> {
        let iter = DirectorySequence(baseURL: baseURL).lazy.filter({ elem in
            switch elem {
            case .failure:
                return true
            case .success(let bundleFile):
                return keepFiles.contains(bundleFile.url.lastPathComponent)
                    || keepExtensions.contains(bundleFile.url.pathExtension)
            }
            // TODO we need to ensure that .manifest is at the root
        }).map {
            switch $0 {
            case .failure:
                return $0
            case .success(let bundleFile):
                // TODO is there a cool way to limit file sizes we're willing to read?
                let data = Result { try Data(contentsOf: bundleFile.url) }
                guard let data = try? data.get() else {
                    // TODO wrap the underlying error
                    return .failure(
                        NSError(
                            domain: "DirectoryLoader", code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Failed to read file \(bundleFile.url)"
                            ]))
                }
                return .success(BundleFile(url: bundleFile.url, data: data))
            }
        }
        return AnyIterator(iter.makeIterator())
    }
}

// DirectorySequence is a sequence of BundleFiles over a filesystem directory.
private struct DirectorySequence: Sequence {
    let baseURL: URL

    struct DirectoryIterator: IteratorProtocol {
        var baseURL: URL
        var innerIter: (any IteratorProtocol)?
        fileprivate var fileError: Box<(any Swift.Error)?> = .init(nil)
        var done: Bool = false

        init(baseURL: URL) {
            self.baseURL = baseURL

            // Trick to allow the errorHandler below to retain a reference to the
            // captureError. It can't directly hold a reference to self, so instead self and
            // the current scope share the same underlying error storage.
            // For this to be ok, we need to hope the handler is always called on our same thread.
            let captureError = Box<(any Swift.Error)?>(nil)
            self.fileError = captureError

            let enumerator = FileManager.default.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey],
                options: [],
                errorHandler: { (url, error) -> Bool in
                    // Capture errors as they occur, they will be emitted back
                    // to the end-user in next() below.
                    // TODO - associate the url with the error
                    captureError.value = error
                    return false
                }
            )

            guard let enumerator else {
                return
            }
            self.innerIter = enumerator.makeIterator()
        }

        mutating func next() -> Result<BundleFile, Swift.Error>? {
            if done {
                return nil
            }

            // If we captured an error earlier from the inital setup of the enumerator,
            // return it and end iteration.
            if let error = self.fileError.value {
                done = true
                return .failure(error)
            }
            let nextResult = innerIter?.next()
            guard let nextResult else {
                if let error = self.fileError.value {
                    done = true
                    return .failure(error)
                }

                // Iteration from underlying iterator complete
                return nil
            }

            guard let url = nextResult as? URL else {
                done = true
                return .failure(Err.unexpectedType)
            }

            guard let relativeURL = makeRelativeURL(from: baseURL, to: url) else {
                done = true
                return .failure(Err.relativeURLError)
            }

            // TODO
            return .success(BundleFile(url: relativeURL, data: Data()))
        }

        enum Err: Swift.Error {
            case unknownError
            case unexpectedType
            case relativeURLError
        }
    }

    func makeIterator() -> DirectoryIterator {
        return DirectoryIterator(baseURL: baseURL)
    }
}

// makeRelativeURL takes a base URL and a child URL and returns a new URL that is relative to the
// base URL.
// Internally, the URL keeps track of the base and relative portions, and the relative portion can
// be extracted with URL.relativePath.
// This function only works for file:// URLs.
func makeRelativeURL(from base: URL, to child: URL) -> URL? {
    // Only support filesystem URLs
    guard base.isFileURL, child.isFileURL else {
        return nil
    }
    // Compare on symlink-resolved paths so they share a canonical prefix. On macOS the
    // directory enumerator yields /private/var/... while resolvingSymlinksInPath reports
    // /var/..., so resolving both normalizes them. The returned URL is still built from the
    // original `base` to preserve its exact path form for callers.
    let baseComponents = base.resolvingSymlinksInPath().pathComponents
    let childComponents = child.resolvingSymlinksInPath().pathComponents

    if !childComponents.starts(with: baseComponents) {
        // childURL is not an ancestor of baseURL
        return nil
    }

    if baseComponents == childComponents {
        // Both URLs were equal
        return URL(string: ".", relativeTo: base)
    }

    let relativeComponents = childComponents.dropFirst(baseComponents.count)

    // Ensure there is a trailing slash on the baseURL
    // This is apparently necessary, otherwise the last path component will
    // be dropped when we create the new relative URL.
    // See documentation: https://developer.apple.com/documentation/foundation/nsurl/1417949-init
    // specifically:
    // ...you can construct a URL for the file by providing the folder’s URL as the base path
    // (with a trailing slash) and the filename as the string part.
    var absBase = base.absoluteURL
    if absBase.lastPathComponent != "/" {
        absBase = absBase.appendingPathComponent("/")
    }
    return URL(string: relativeComponents.joined(separator: "/"), relativeTo: absBase)
}

private class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
