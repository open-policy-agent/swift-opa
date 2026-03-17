import AST
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

// MARK: - Locals Renumbering
//
// Renumbering compacts sparse local indices into a contiguous range so the
// evaluator can pre-allocate locals storage without wasting slots. The pass is
// designed to be:
//
// - Stable: original indices are remapped in sorted order, so remappings
//   preserve relative ordering.
// - Idempotent: running the pass twice produces the same result as once.
// - A no-op for already-compact plans/funcs. When the mapping is the same
//   as what's already there, no rewrite happens.
//
// Plans treat locals 0 (input) and 1 (data) as reserved. Funcs treat their
// declared params and returnVar as reserved (kept at their original indices),
// since callers reference those positions when invoking the func.

extension Plan {
    public mutating func renumberLocals() {
        let remapping = buildPlanRemapping()
        guard !isIdentity(remapping) else { return }
        for i in blocks.indices {
            blocks[i].walk { statement in
                statement.applyLocalRemapping(remapping)
            }
        }
    }

    private func buildPlanRemapping() -> [Int: Int] {
        var allLocals = Set<Int>()
        for var block in blocks {
            block.walk { statement in
                statement.collectLocals(into: &allLocals)
            }
        }
        // Reserved: 0 (input), 1 (data) are conventionally fixed for plans.
        let reserved: Set<Int> = [0, 1]
        var remapping: [Int: Int] = [:]
        for r in reserved {
            remapping[r] = r
        }
        let sortedNonReserved = allLocals.subtracting(reserved).sorted()
        var nextAvail = 2
        for orig in sortedNonReserved {
            remapping[orig] = nextAvail
            nextAvail += 1
        }
        return remapping
    }

    public mutating func computeMaxLocal() {
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
    public mutating func renumberLocals() {
        let remapping = buildFuncRemapping()
        guard !isIdentity(remapping) else { return }
        for i in blocks.indices {
            blocks[i].walk { statement in
                statement.applyLocalRemapping(remapping)
            }
        }
    }

    private func buildFuncRemapping() -> [Int: Int] {
        var allLocals = Set<Int>()
        for var block in blocks {
            block.walk { statement in
                statement.collectLocals(into: &allLocals)
            }
        }
        // Reserved: params and returnVar are kept at their original indices since
        // callers reference these positions to pass arguments and read the result.
        var reserved: Set<Int> = Set(params.map { Int($0) })
        reserved.insert(Int(returnVar))
        // Reserved are part of the func's used locals even if they don't appear
        // in any statement.
        allLocals.formUnion(reserved)

        var remapping: [Int: Int] = [:]
        for r in reserved {
            remapping[r] = r
        }
        let sortedNonReserved = allLocals.subtracting(reserved).sorted()
        // Fill the lowest indices that aren't reserved.
        var nextAvail = 0
        for orig in sortedNonReserved {
            while reserved.contains(nextAvail) {
                nextAvail += 1
            }
            remapping[orig] = nextAvail
            nextAvail += 1
        }
        return remapping
    }

    public mutating func computeMaxLocal() {
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

private func isIdentity(_ remapping: [Int: Int]) -> Bool {
    for (k, v) in remapping where k != v {
        return false
    }
    return true
}

extension Statement {
    /// Collect every local index referenced by this statement into `locals`.
    /// Does not descend into nested blocks, as Block.walk handles recursion.
    func collectLocals(into locals: inout Set<Int>) {
        switch self {
        case .arrayAppendStmt(let stmt):
            locals.insert(Int(stmt.array))
            collectOperandLocal(stmt.value, into: &locals)
        case .assignIntStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .assignVarStmt(let stmt):
            locals.insert(Int(stmt.target))
            collectOperandLocal(stmt.source, into: &locals)
        case .assignVarOnceStmt(let stmt):
            locals.insert(Int(stmt.target))
            collectOperandLocal(stmt.source, into: &locals)
        case .callStmt(let stmt):
            locals.insert(Int(stmt.result))
            for arg in stmt.args ?? [] {
                collectOperandLocal(arg, into: &locals)
            }
        case .callDynamicStmt(let stmt):
            locals.insert(Int(stmt.result))
            for arg in stmt.args {
                locals.insert(Int(arg))
            }
            for pathOp in stmt.path {
                collectOperandLocal(pathOp, into: &locals)
            }
        case .dotStmt(let stmt):
            locals.insert(Int(stmt.target))
            collectOperandLocal(stmt.source, into: &locals)
            collectOperandLocal(stmt.key, into: &locals)
        case .equalStmt(let stmt):
            collectOperandLocal(stmt.a, into: &locals)
            collectOperandLocal(stmt.b, into: &locals)
        case .isArrayStmt(let stmt):
            collectOperandLocal(stmt.source, into: &locals)
        case .isDefinedStmt(let stmt):
            locals.insert(Int(stmt.source))
        case .isObjectStmt(let stmt):
            collectOperandLocal(stmt.source, into: &locals)
        case .isSetStmt(let stmt):
            collectOperandLocal(stmt.source, into: &locals)
        case .isUndefinedStmt(let stmt):
            locals.insert(Int(stmt.source))
        case .lenStmt(let stmt):
            locals.insert(Int(stmt.target))
            collectOperandLocal(stmt.source, into: &locals)
        case .makeArrayStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .makeNullStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .makeNumberIntStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .makeNumberRefStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .makeObjectStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .makeSetStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .notEqualStmt(let stmt):
            collectOperandLocal(stmt.a, into: &locals)
            collectOperandLocal(stmt.b, into: &locals)
        case .objectInsertStmt(let stmt):
            locals.insert(Int(stmt.object))
            collectOperandLocal(stmt.key, into: &locals)
            collectOperandLocal(stmt.value, into: &locals)
        case .objectInsertOnceStmt(let stmt):
            locals.insert(Int(stmt.object))
            collectOperandLocal(stmt.key, into: &locals)
            collectOperandLocal(stmt.value, into: &locals)
        case .objectMergeStmt(let stmt):
            locals.insert(Int(stmt.a))
            locals.insert(Int(stmt.b))
            locals.insert(Int(stmt.target))
        case .resetLocalStmt(let stmt):
            locals.insert(Int(stmt.target))
        case .resultSetAddStmt(let stmt):
            locals.insert(Int(stmt.value))
        case .returnLocalStmt(let stmt):
            locals.insert(Int(stmt.source))
        case .scanStmt(let stmt):
            locals.insert(Int(stmt.source))
            locals.insert(Int(stmt.key))
            locals.insert(Int(stmt.value))
        case .setAddStmt(let stmt):
            locals.insert(Int(stmt.set))
            collectOperandLocal(stmt.value, into: &locals)
        case .withStmt(let stmt):
            locals.insert(Int(stmt.local))
            collectOperandLocal(stmt.value, into: &locals)
        case .breakStmt, .nopStmt, .blockStmt, .notStmt, .unknown:
            break
        }
    }

    /// Apply a precomputed local-index remapping to every local reference in
    /// this statement. Indices not present in the map are left unchanged.
    /// Does not descend into nested blocks, as Block.walk handles recursion.
    mutating func applyLocalRemapping(_ remapping: [Int: Int]) {
        switch self {
        case .arrayAppendStmt(var stmt):
            stmt.array = Local(remap(Int(stmt.array), remapping))
            remapOperand(&stmt.value, remapping)
            self = .arrayAppendStmt(stmt)
        case .assignIntStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .assignIntStmt(stmt)
        case .assignVarStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            remapOperand(&stmt.source, remapping)
            self = .assignVarStmt(stmt)
        case .assignVarOnceStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            remapOperand(&stmt.source, remapping)
            self = .assignVarOnceStmt(stmt)
        case .callStmt(var stmt):
            stmt.result = Local(remap(Int(stmt.result), remapping))
            if var args = stmt.args {
                for i in args.indices {
                    remapOperand(&args[i], remapping)
                }
                stmt.args = args
            }
            self = .callStmt(stmt)
        case .callDynamicStmt(var stmt):
            stmt.result = Local(remap(Int(stmt.result), remapping))
            for i in stmt.args.indices {
                stmt.args[i] = Local(remap(Int(stmt.args[i]), remapping))
            }
            for i in stmt.path.indices {
                remapOperand(&stmt.path[i], remapping)
            }
            self = .callDynamicStmt(stmt)
        case .dotStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            remapOperand(&stmt.source, remapping)
            remapOperand(&stmt.key, remapping)
            self = .dotStmt(stmt)
        case .equalStmt(var stmt):
            remapOperand(&stmt.a, remapping)
            remapOperand(&stmt.b, remapping)
            self = .equalStmt(stmt)
        case .isArrayStmt(var stmt):
            remapOperand(&stmt.source, remapping)
            self = .isArrayStmt(stmt)
        case .isDefinedStmt(var stmt):
            stmt.source = Local(remap(Int(stmt.source), remapping))
            self = .isDefinedStmt(stmt)
        case .isObjectStmt(var stmt):
            remapOperand(&stmt.source, remapping)
            self = .isObjectStmt(stmt)
        case .isSetStmt(var stmt):
            remapOperand(&stmt.source, remapping)
            self = .isSetStmt(stmt)
        case .isUndefinedStmt(var stmt):
            stmt.source = Local(remap(Int(stmt.source), remapping))
            self = .isUndefinedStmt(stmt)
        case .lenStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            remapOperand(&stmt.source, remapping)
            self = .lenStmt(stmt)
        case .makeArrayStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeArrayStmt(stmt)
        case .makeNullStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeNullStmt(stmt)
        case .makeNumberIntStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeNumberIntStmt(stmt)
        case .makeNumberRefStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeNumberRefStmt(stmt)
        case .makeObjectStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeObjectStmt(stmt)
        case .makeSetStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .makeSetStmt(stmt)
        case .notEqualStmt(var stmt):
            remapOperand(&stmt.a, remapping)
            remapOperand(&stmt.b, remapping)
            self = .notEqualStmt(stmt)
        case .objectInsertStmt(var stmt):
            stmt.object = Local(remap(Int(stmt.object), remapping))
            remapOperand(&stmt.key, remapping)
            remapOperand(&stmt.value, remapping)
            self = .objectInsertStmt(stmt)
        case .objectInsertOnceStmt(var stmt):
            stmt.object = Local(remap(Int(stmt.object), remapping))
            remapOperand(&stmt.key, remapping)
            remapOperand(&stmt.value, remapping)
            self = .objectInsertOnceStmt(stmt)
        case .objectMergeStmt(var stmt):
            stmt.a = Local(remap(Int(stmt.a), remapping))
            stmt.b = Local(remap(Int(stmt.b), remapping))
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .objectMergeStmt(stmt)
        case .resetLocalStmt(var stmt):
            stmt.target = Local(remap(Int(stmt.target), remapping))
            self = .resetLocalStmt(stmt)
        case .resultSetAddStmt(var stmt):
            stmt.value = Local(remap(Int(stmt.value), remapping))
            self = .resultSetAddStmt(stmt)
        case .returnLocalStmt(var stmt):
            stmt.source = Local(remap(Int(stmt.source), remapping))
            self = .returnLocalStmt(stmt)
        case .scanStmt(var stmt):
            stmt.source = Local(remap(Int(stmt.source), remapping))
            stmt.key = Local(remap(Int(stmt.key), remapping))
            stmt.value = Local(remap(Int(stmt.value), remapping))
            self = .scanStmt(stmt)
        case .setAddStmt(var stmt):
            stmt.set = Local(remap(Int(stmt.set), remapping))
            remapOperand(&stmt.value, remapping)
            self = .setAddStmt(stmt)
        case .withStmt(var stmt):
            stmt.local = Local(remap(Int(stmt.local), remapping))
            remapOperand(&stmt.value, remapping)
            self = .withStmt(stmt)
        case .breakStmt, .nopStmt, .blockStmt, .notStmt, .unknown:
            break
        }
    }

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

// MARK: - Renumbering helpers

private func collectOperandLocal(_ operand: Operand, into locals: inout Set<Int>) {
    if case .localIndex(let idx) = operand.value {
        locals.insert(idx)
    }
}

private func remapOperand(_ operand: inout Operand, _ remapping: [Int: Int]) {
    if case .localIndex(let idx) = operand.value {
        operand.value = .localIndex(remap(idx, remapping))
    }
}

private func remap(_ idx: Int, _ remapping: [Int: Int]) -> Int {
    return remapping[idx] ?? idx
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
