import AST
import Foundation

//protocol BundleLoader {
//    func load() async throws -> Bundle
//}
//
// DirectorySequence is a sequence of BundleFiles over a filesystem directory.
struct DirectorySequence: Sequence {
    let baseURL: URL

    struct DirectoryIterator: IteratorProtocol {
        var innerIter: (any IteratorProtocol)?
        var fileError: Box<(any Error)?> = .init(nil)
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

// DirectoryLoader loads a sequence of OPA bundle files from a directory
//struct DirectoryLoader {
//    let baseURL: URL
//    let validFiles = Set(["data.json", "plan.json", ".manifest"])
//
//    func load() async throws -> AnySequence<Result<BundleFile, Error>> {
//        return AnySequence { () -> AnyIterator<Result<BundleFile, Error>> in
//            var iter = DirectorySequence(baseURL: baseURL).makeIterator()
//
//            return AnyIterator {
//                while(true) {
//                    guard let next = iter.next() else { return nil }
//
//                    switch next {
//                    case .failure(let error):
//                        return .failure(error)
//                    case .success(let url):
//                        if validFiles.contains(url.lastPathComponent) ||  url.pathExtension == "rego" {
//                            return .success(BundleFile(url: url))
//                        }
//                    }
//                }
//            }
//        }
//    }
//}

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

class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
