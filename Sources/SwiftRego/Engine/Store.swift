//
//  Store.swift
//  SwiftRego
//
//  Created by Oren Shomron on 1/17/25.
//
protocol Store {
    func read(path: StoreKeyPath) async throws -> Ast.RegoValue
    func write(path: StoreKeyPath, value: Ast.RegoValue) async throws
}

struct StoreKeyPath {
    let segments: [String]
}
