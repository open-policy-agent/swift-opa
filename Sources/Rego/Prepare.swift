import AST
import Foundation
import IR

// prepare prepares bundles for evaluation
func prepare(bundles: [Bundle], store: inout Store) async throws {
    for bundle in bundles {
        let roots = bundle.manifest.roots
        try await store.write(path: StoreKeyPath(["data"]), value: bundle.data)
    }
}
