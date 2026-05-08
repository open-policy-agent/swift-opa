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
        // Renumber locals in every plan and func to compact contiguous ranges.
        if var plans = self.plans {
            for i in plans.plans.indices {
                plans.plans[i].renumberLocals()
            }
            self.plans = plans
        }
        if var funcs = self.funcs {
            if var funcList = funcs.funcs {
                for i in funcList.indices {
                    funcList[i].renumberLocals()
                }
                funcs.funcs = funcList
            }
            self.funcs = funcs
        }

        // Compute maxLocal after renumbering so the cached value reflects the
        // compacted range used by the evaluator.
        if var plans = self.plans {
            for i in plans.plans.indices {
                plans.plans[i].computeMaxLocal()
            }
            self.plans = plans
        }
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
