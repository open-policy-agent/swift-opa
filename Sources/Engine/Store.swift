//
//  Store.swift
//  SwiftRego
//
//  Created by Oren Shomron on 1/17/25.
//
import AST

protocol Store {
    func read(path: StoreKeyPath) async throws -> AST.RegoValue
    func write(path: StoreKeyPath, value: AST.RegoValue) async throws
}

struct StoreKeyPath {
    let segments: [String]
}
