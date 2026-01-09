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
        // Compute maxLocal for all plans
        if var plans = self.plans {
            for i in plans.plans.indices {
                plans.plans[i].computeMaxLocal()
            }
            self.plans = plans
        }

        // Compute maxLocal for all functions
        if var funcs = self.funcs {
            if var funcList = funcs.funcs {
                for i in funcList.indices {
                    funcList[i].computeMaxLocal()
                }
                funcs.funcs = funcList
            }
            self.funcs = funcs
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
