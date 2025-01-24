import AST
import Foundation

struct BundleLoader {
    var bundleFiles: any Sequence<Result<BundleFile, any Error>>
    
    init(fromFileSequence files: any Sequence<Result<BundleFile, any Error>>) {
        self.bundleFiles = files
    }
    
    public enum LoadError: Error {
        case unexpectedManifest(URL)
        case unexpectedData(URL)
        case manifestParseError(URL, Error)
        case dataParseError(URL, Error)
    }
    
    func load() throws -> Bundle {
        // Unwrap files, throw first error if we encounter one
        let files: [BundleFile] = try bundleFiles.map{ try $0.get() }
        
        // TODO Boo, no fun functional shenanigans :(
        //        var regoFiles: [BundleFile] = files.filter({$0.url.pathExtension == "rego"})
        //        var planFiles: [BundleFile] = files.filter({$0.url.lastPathComponent == "plan.json"})
        //        var manifest: Manifest? = try files.first(where: {$0.url.lastPathComponent == ".manifest"})
        //            .flatMap{ try Manifest(from: $0.data) }
        
        // TODO how do we know what the root is to ensure that .manifest is at the root?
        
        var regoFiles: [BundleFile] = []
        var planFiles: [BundleFile] = []
        var manifest: Manifest?
        var data: AST.RegoValue?
        
        for f in files {
            switch f.url.lastPathComponent {
            case ".manifest":
                guard manifest == nil else {
                    throw LoadError.unexpectedManifest(f.url)
                }
                manifest = try Manifest(from: f.data)
                
            case "data.json":
                guard data == nil else {
                    // TODO - just for now, support only a single data file per-bundle
                    throw LoadError.unexpectedData(f.url)
                }
                do {
                    data = try AST.RegoValue(fromJson: f.data)
                } catch {
                    throw LoadError.dataParseError(f.url, error)
                }
                
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

        manifest = manifest ?? Manifest() // Default manifest if none was provided
        data = data ?? AST.RegoValue.object([:]) // Default data if none was provided
        return Bundle(manifest: manifest!, planFiles: planFiles, regoFiles: regoFiles, data: data!)
    }
    
    public static func load(fromDirectory url: URL) throws -> Bundle {
        let files = DirectoryLoader(baseURL: url)
        return try BundleLoader(fromFileSequence: files).load()
    }
}

// DirectoryLoader returns a sequence of OPA bundle files from a directory,
// while filtering out non-bundle-related files.
// I/O errors are propogated as failure cases of the results.
struct DirectoryLoader: Sequence {
    let baseURL: URL
    let keepFiles = Set(["data.json", "plan.json", ".manifest"])
    let keepExtensions = Set(["rego"])

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func makeIterator() -> AnyIterator<Result<BundleFile, any Error>> {
        let iter = DirectorySequence(baseURL: baseURL).lazy.filter({ elem in
            switch elem {
            case .failure:
                return true
            case .success(let bundleFile):
                return keepFiles.contains(bundleFile.url.lastPathComponent)
                    || keepExtensions.contains(bundleFile.url.pathExtension)
            }
            // TODO we need to ensure that .manifest is at the root
        }).map{
            switch $0 {
            case .failure:
                return $0
            case .success(let bundleFile):
                // TODO is there a cool way to limit file sizes we're willing to read?
                let data = Result{ try Data(contentsOf: bundleFile.url) }
                guard let data = try? data.get() else {
                    // TODO wrap the underlying error
                    return .failure(NSError(domain: "DirectoryLoader", code: 1, userInfo: [NSLocalizedDescriptionKey : "Failed to read file \(bundleFile.url)"]))
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
        var innerIter: (any IteratorProtocol)?
        fileprivate var fileError: Box<(any Error)?> = .init(nil)
        var done: Bool = false

        init(baseURL: URL) {
            // Trick to allow the errorHandler below to retain a reference to the
            // captureError. It can't directly hold a reference to self, so instead self and
            // the current scope share the same underlying error storage.
            // For this to be ok, we need to hope the handler is always called on our same thread.
            let captureError = Box<(any Error)?>(nil)
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
        mutating func next() -> Result<BundleFile, Error>? {
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

            // TODO
            return .success(BundleFile(url: url, data: Data()))
        }

        enum Err: Error {
            case unknownError
            case unexpectedType
        }
    }

    func makeIterator() -> DirectoryIterator {
        return DirectoryIterator(baseURL: baseURL)
    }
}

// InMemBundleLoader implements BundleLoader over an in-memory bundle representation
//struct InMemBundleLoader: BundleLoader {
//    let rawPolicy: Data
//    let rawData: Data
//
//    func load() async throws -> Bundle {
//        // TODO
//        return Bundle(
//            manifest: Manifest(
//                revision: "",
//                roots: [],
//                regoVersion: .regoV1,
//                metadata: [:]
//            ),
//            planFiles: [],
//            data: AST.RegoValue.object([:])
//        )
//        //        let policy = try IR.Policy(fromJson: rawPolicy)
//        //        let data = try AST.RegoValue(fromJson: rawData)
//        //
//        //        return Bundle(policy: policy, data: data)
//    }
//}

//struct Rego: Sequence {
//
//}

private class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
