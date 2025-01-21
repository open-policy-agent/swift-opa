import AST
import Foundation

//protocol BundleLoader {
//    func load() async throws -> Bundle
//}
//
// DirectoryLoader is a sequence of BundleFiles over a filesystem directory.
struct DirectoryLoader: Sequence {
    let baseURL: URL

    struct DirectoryIterator: IteratorProtocol {
        var innerIter: (any IteratorProtocol)?
        var fileError: Box<(any Error)?> = .init(nil)

        init(baseURL: URL) {
            // Trick to allow the errorHandler below to retain a reference to the
            // captureError. It can't directly hold a reference to self, so instead self and
            // the current scope share the same underlying error storage.
            // For this to be ok, we need to hope the handler is always called on our same thread.
            var captureError = Box<(any Error)?>(nil)
            self.fileError = captureError

            let enumerator = FileManager.default.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey],
                options: [],
                errorHandler: { (url, error) -> Bool in
                    // Capture the first error if any occur
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
            // If we captured an error earlier, return it and end iteration.
            if let error = self.fileError.value {
                return .failure(error)
            }
            let nextResult = innerIter?.next()
            guard let nextResult else {
                if self.fileError.value != nil {
                    // TODO: Does the errorHandler ever get called after the initial
                    // enumerator is set up?
                    return .failure(self.fileError.value!)
                }

                // Iteration from underlying iterator complete
                return nil
            }

            // TODO
            return .success(BundleFile(path: "", data: Data()))
        }

        enum Err: Error {
            case unknownError
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

class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
