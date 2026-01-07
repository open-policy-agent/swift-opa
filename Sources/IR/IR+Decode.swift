//
//  IR+Decode.swift
//  Decoding/deserializing extensions for IR
//

import Foundation

extension Policy {
    public init(jsonData rawJson: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: rawJson)

        self.prepareForExecution()
    }

    /// Prepare the policy for execution by running static analysis passes.
    /// This computes properties like maxLocal that are used for optimization.
    mutating func prepareForExecution() {
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
    }
}
