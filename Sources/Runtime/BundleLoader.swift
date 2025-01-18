//
//  BundleLoader.swift
//

import AST
import Foundation
import IR

protocol BundleLoader {
    func load() async throws -> Bundle
}

// InMemBundleLoader implements BundleLoader over an in-memory bundle representation
struct InMemBundleLoader: BundleLoader {
    let rawPolicy: Data
    let rawData: Data

    func load() async throws -> Bundle {
        let policy = try IR.Policy(fromJson: rawPolicy)
        let data = try AST.RegoValue(fromJson: rawData)

        return Bundle(policy: policy, data: data)
    }
}
