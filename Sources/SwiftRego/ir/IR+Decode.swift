//
//  IR+Decode.swift
//  Decoding/deserializing extensions for IR
//

import Foundation

extension Policy {
    init(fromJson rawJson: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: rawJson)
    }
}
