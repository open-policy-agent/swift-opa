import Foundation

// MARK: - Static Analysis
//
// This file contains static analysis passes that run after IR decoding to compute
// properties used for optimization during evaluation.

extension Plan {
    /// Compute the maximum local index used in this plan.
    /// This is used to pre-allocate locals arrays to avoid runtime growth.
    mutating func computeMaxLocal() {
        self.maxLocal = Self.computeMaxLocal(blocks: blocks)
    }

    static func computeMaxLocal(blocks: [Block]) -> Int {
        var maxLocal = -1
        for block in blocks {
            maxLocal = max(maxLocal, block.computeMaxLocal())
        }
        return maxLocal
    }
}

extension Func {
    /// Compute the maximum local index used in this function.
    /// Includes params, return var, and all locals used in blocks.
    mutating func computeMaxLocal() {
        var maxLocal = Self.computeMaxLocal(blocks: blocks)

        for param in params {
            maxLocal = max(maxLocal, Int(param))
        }
        maxLocal = max(maxLocal, Int(returnVar))

        self.maxLocal = maxLocal
    }

    static func computeMaxLocal(blocks: [Block]) -> Int {
        var maxLocal = -1
        for block in blocks {
            maxLocal = max(maxLocal, block.computeMaxLocal())
        }
        return maxLocal
    }
}

extension Block {
    func computeMaxLocal() -> Int {
        var maxLocal = -1
        for statement in statements {
            maxLocal = max(maxLocal, statement.computeMaxLocal())
        }
        return maxLocal
    }
}

extension AnyStatement {
    func computeMaxLocal() -> Int {
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
        case .blockStmt(let stmt):
            if let blocks = stmt.blocks {
                for block in blocks {
                    maxLocal = max(maxLocal, block.computeMaxLocal())
                }
            }
        case .breakStmt:
            break
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
        case .nopStmt:
            break
        case .notStmt(let stmt):
            maxLocal = max(maxLocal, stmt.block.computeMaxLocal())
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
            maxLocal = max(maxLocal, stmt.block.computeMaxLocal())
        case .setAddStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.set))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
        case .withStmt(let stmt):
            maxLocal = max(maxLocal, Int(stmt.local))
            maxLocal = max(maxLocal, extractMaxFromOperand(stmt.value))
            maxLocal = max(maxLocal, stmt.block.computeMaxLocal())
        case .unknown:
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
