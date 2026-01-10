import Foundation

// MARK: - IR Errors

public struct IRValidationError: Error {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

// MARK: - Static Analysis
//
// This file contains static analysis passes that run after IR decoding to compute
// properties used for optimization during evaluation.

// MARK: - IR Walker

extension Block {
    mutating func walk(_ visitStatement: (inout Statement) throws -> Void) rethrows {
        for i in statements.indices {
            try statements[i].walk(visitStatement)
        }
    }
}

extension Statement {
    mutating func walk(_ visitStatement: (inout Statement) throws -> Void) rethrows {
        try visitStatement(&self)

        switch self {
        case .blockStmt(var stmt):
            if var blocks = stmt.blocks {
                for i in blocks.indices {
                    try blocks[i].walk(visitStatement)
                }
                stmt.blocks = blocks
            }
            self = .blockStmt(stmt)

        case .notStmt(var stmt):
            try stmt.block.walk(visitStatement)
            self = .notStmt(stmt)

        case .scanStmt(var stmt):
            try stmt.block.walk(visitStatement)
            self = .scanStmt(stmt)

        case .withStmt(var stmt):
            try stmt.block.walk(visitStatement)
            self = .withStmt(stmt)

        default:
            break
        }
    }
}

extension Plan {
    mutating func computeMaxLocal() {
        var maxLocal = -1
        for i in blocks.indices {
            blocks[i].walk { statement in
                maxLocal = max(maxLocal, statement.maxLocalUsed())
            }
        }
        self.maxLocal = maxLocal
    }
}

extension Func {
    mutating func computeMaxLocal() {
        var maxLocal = -1

        for i in blocks.indices {
            blocks[i].walk { statement in
                maxLocal = max(maxLocal, statement.maxLocalUsed())
            }
        }

        for param in params {
            maxLocal = max(maxLocal, Int(param))
        }
        maxLocal = max(maxLocal, Int(returnVar))

        self.maxLocal = maxLocal
    }
}

extension Statement {
    func maxLocalUsed() -> Int {
        var maxLocal = -1

        switch self {
        case .arrayAppendStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.array))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .assignIntStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .assignVarStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .assignVarOnceStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .callStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.result))
            if let args = stmt.args {
                for arg in args {
                    maxLocal = max(maxLocal, extractMaxFromOperand(arg))
                }
            }
        case .callDynamicStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.result))
            for arg in stmt.args {
                maxLocal = max(maxLocal, Int(arg))
            }
            for pathOp in stmt.path {
                maxLocal = max(maxLocal, extractMaxFromOperand(pathOp))
            }
        case .dotStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.key))
        case .equalStmt(let stmt):
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.a))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.b))
        case .isArrayStmt(let stmt):
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .isDefinedStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.source))
        case .isObjectStmt(let stmt):
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .isSetStmt(let stmt):
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .isUndefinedStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.source))
        case .lenStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.source))
        case .makeArrayStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .makeNullStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .makeNumberIntStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .makeNumberRefStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .makeObjectStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .makeSetStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .notEqualStmt(let stmt):
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.a))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.b))
        case .objectInsertStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.object))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.key))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .objectInsertOnceStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.object))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.key))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .objectMergeStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.a))
            maxLocal = max(maxLocal, Int(stmt.b))
            maxLocal = max(maxLocal, Int(stmt.target))
        case .resetLocalStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.target))
        case .resultSetAddStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.value))
        case .returnLocalStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.source))
        case .scanStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.source))
            maxLocal = max(maxLocal, Int(stmt.key))
            maxLocal = max(maxLocal, Int(stmt.value))
        case .setAddStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.set))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .withStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.local))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .breakStmt, .nopStmt, .blockStmt, .notStmt, .unknown:
            break
        }

        return maxLocal
    }

    private func extractMaxFromOperand(_ operand: Operand) -> Int {
        switch operand.value {
        case .localIndex(let idx):
            return idx
        default:
            return -1
        }
    }
}

// MARK: - Static String Resolution

extension Policy {
    func verifyStaticStrings() throws {
        if let plans = self.plans {
            for plan in plans.plans {
                try plan.verifyStaticStrings(staticData: self.staticData)
            }
        }

        if let funcList = self.funcs?.funcs {
            for function in funcList {
                try function.verifyStaticStrings(staticData: self.staticData)
            }
        }
    }
}

extension Plan {
    func verifyStaticStrings(staticData: Static?) throws {
        for var block in blocks {
            try block.walk { statement in
                try statement.verifyStaticStrings(staticData: staticData)
            }
        }
    }
}

extension Func {
    func verifyStaticStrings(staticData: Static?) throws {
        for var block in blocks {
            try block.walk { statement in
                try statement.verifyStaticStrings(staticData: staticData)
            }
        }
    }
}

extension Statement {
    func verifyStaticStrings(staticData: Static?) throws {
        switch self {
        case .arrayAppendStmt(let stmt):
            try stmt.value.verifyStaticString(staticData: staticData)
        case .assignVarStmt(let stmt):
            try stmt.source.verifyStaticString(staticData: staticData)
        case .assignVarOnceStmt(let stmt):
            try stmt.source.verifyStaticString(staticData: staticData)
        case .callStmt(let stmt):
            if let args = stmt.args {
                for arg in args {
                    try arg.verifyStaticString(staticData: staticData)
                }
            }
        case .dotStmt(let stmt):
            try stmt.source.verifyStaticString(staticData: staticData)
            try stmt.key.verifyStaticString(staticData: staticData)
        case .equalStmt(let stmt):
            try stmt.a.verifyStaticString(staticData: staticData)
            try stmt.b.verifyStaticString(staticData: staticData)
        case .lenStmt(let stmt):
            try stmt.source.verifyStaticString(staticData: staticData)
        case .makeNumberRefStmt(let stmt):
            guard let strings = staticData?.strings else {
                throw IRValidationError("missing static strings data")
            }
            let idx = Int(stmt.index)
            guard idx >= 0 && idx < strings.count else {
                throw IRValidationError(
                    "invalid string index in MakeNumberRefStmt: \(idx) (valid range: 0..<\(strings.count))"
                )
            }
        case .notEqualStmt(let stmt):
            try stmt.a.verifyStaticString(staticData: staticData)
            try stmt.b.verifyStaticString(staticData: staticData)
        case .objectInsertOnceStmt(let stmt):
            try stmt.key.verifyStaticString(staticData: staticData)
            try stmt.value.verifyStaticString(staticData: staticData)
        case .objectInsertStmt(let stmt):
            try stmt.key.verifyStaticString(staticData: staticData)
            try stmt.value.verifyStaticString(staticData: staticData)
        case .setAddStmt(let stmt):
            try stmt.value.verifyStaticString(staticData: staticData)
        case .withStmt(let stmt):
            if let pathIndices = stmt.path {
                guard let strings = staticData?.strings else {
                    throw IRValidationError("missing static strings data")
                }
                for idx in pathIndices {
                    let index = Int(idx)
                    guard index >= 0 && index < strings.count else {
                        throw IRValidationError(
                            "invalid string index in WithStmt path: \(index) (valid range: 0..<\(strings.count))"
                        )
                    }
                }
            }
            try stmt.value.verifyStaticString(staticData: staticData)
        default:
            break
        }
    }
}

extension Operand {
    func verifyStaticString(staticData: Static?) throws {
        if case .stringIndex(let idx) = self.value {
            guard let strings = staticData?.strings else {
                throw IRValidationError("missing static strings data")
            }
            guard idx >= 0 && idx < strings.count else {
                throw IRValidationError(
                    "invalid string index in Operand: \(idx) (valid range: 0..<\(strings.count))"
                )
            }
        }
    }
}

// MARK: - Number Index Identification

extension Plan {
    func identifyStaticStringNumbers(into indices: inout Set<Int>) {
        for var block in blocks {
            block.walk { statement in
                statement.identifyStaticStringNumbers(into: &indices)
            }
        }
    }
}

extension Func {
    func identifyStaticStringNumbers(into indices: inout Set<Int>) {
        for var block in blocks {
            block.walk { statement in
                statement.identifyStaticStringNumbers(into: &indices)
            }
        }
    }
}

extension Statement {
    func identifyStaticStringNumbers(into indices: inout Set<Int>) {
        if case .makeNumberRefStmt(let stmt) = self {
            indices.insert(Int(stmt.index))
        }
    }
}
