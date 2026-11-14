//
//  IR+Decode.swift
//  Decoding/deserializing extensions for IR
//

import Foundation

extension Policy {
    public init(jsonData rawJson: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: rawJson)

        try self.prepareForExecution()
    }

    /// Prepare the policy for execution by running static analysis passes.
    /// This computes properties like maxLocal that are used for optimization.
    public mutating func prepareForExecution() throws {
        // Mutate in place through `self` so the IR stays uniquely referenced.
        // Copying `self.plans` out first would force copy-on-write of the whole tree.
        // maxLocal is computed after renumbering so it reflects the compacted range.
        if self.plans != nil {
            for i in self.plans!.plans.indices {
                self.plans!.plans[i].renumberLocals()
                self.plans!.plans[i].computeMaxLocal()
            }
        }
        if self.funcs?.funcs != nil {
            for i in self.funcs!.funcs!.indices {
                self.funcs!.funcs![i].renumberLocals()
                self.funcs!.funcs![i].computeMaxLocal()
            }
        }

        try self.verifyStaticStrings()
        self.identifyStaticStringNumbers()
    }

    /// Identify which static string indices are used for numeric literals.
    /// This allows IndexedIRPolicy to pre-parse only the strings that are actually numbers.
    mutating func identifyStaticStringNumbers() {
        var indices = Set<Int>()

        if let plans = self.plans {
            for plan in plans.plans {
                plan.identifyStaticStringNumbers(into: &indices)
            }
        }

        if let funcList = self.funcs?.funcs {
            for function in funcList {
                function.identifyStaticStringNumbers(into: &indices)
            }
        }

        self.staticStringNumbers = Array(indices).sorted()
    }
}
