import Bytecode

/// Patches sync-safety bits directly into a bytecode policy's instruction stream.
///
/// This is a one-time load-time transformation.
///
/// After patching:
/// - `block1`, `not`, `scan`, `with` instruction headers have bit 30 set when sync-safe
/// - `block` sub-block size fields have bit 31 set when sync-safe
/// - `call` user-function `encodedFuncIndex` fields have bit 30 set when sync-safe
/// - `Plan.blocks` triples have `syncSafe` set per-block; `Plan.syncSafe` is set when all
///   blocks in the plan are sync-safe, enabling plan-level dispatch
///
/// The VM hot loop reads these bits directly from already-decoded words.
struct SyncSafePatcher {

    static func patch(policy: Bytecode.Policy, builtins: BuiltinRegistry) -> Bytecode.Policy {

        // ── Phase 1: top-down function sync-safety analysis with memoization ───
        // Recursion is not supported in Rego, so the call graph is a DAG and a
        // single top-down pass with memoization is sufficient.
        var fnSafe = [Bool?](repeating: nil, count: policy.functions.count)

        func analyzeFn(_ idx: Int) -> Bool {
            if let cached = fnSafe[idx] { return cached }
            let fn = policy.functions[idx]
            let safe = fn.blocks.allSatisfy {
                isBlockSyncSafe(
                    bytecode: policy.bytecode, strings: policy.strings,
                    offset: $0.offset, size: $0.size,
                    functionSyncSafe: { analyzeFn($0) }, builtins: builtins
                )
            }
            fnSafe[idx] = safe
            return safe
        }

        for i in policy.functions.indices { _ = analyzeFn(i) }
        let fnSafeLookup: (Int) -> Bool = { idx in idx < fnSafe.count && fnSafe[idx] == true }

        // ── Phase 2: walk all reachable blocks and write sync bits in-place ───
        var bc = policy.bytecode  // value-copy; COW triggers only on mutation
        var worklist: [(offset: Int, size: Int)] = []
        var visited = Set<Int>()

        for plan in policy.plans {
            for block in plan.blocks { worklist.append((offset: block.offset, size: block.size)) }
        }
        for fn in policy.functions {
            for block in fn.blocks { worklist.append(block) }
        }

        while let work = worklist.popLast() {
            guard visited.insert(work.offset).inserted else { continue }
            let nested = patchBlock(
                bytecode: &bc, strings: policy.strings,
                offset: work.offset, size: work.size,
                functionSyncSafe: fnSafeLookup, builtins: builtins
            )
            worklist.append(contentsOf: nested)
        }

        // ── Phase 3: embed syncSafe into each Plan block tuple ────────────────
        let patchedPlans = policy.plans.map { plan in
            let patchedBlocks = plan.blocks.map { block in
                let syncSafe = isBlockSyncSafe(
                    bytecode: bc, strings: policy.strings,
                    offset: block.offset, size: block.size,
                    functionSyncSafe: fnSafeLookup, builtins: builtins
                )
                return (offset: block.offset, size: block.size, syncSafe: syncSafe)
            }
            return Plan(
                name: plan.name,
                maxLocal: plan.maxLocal,
                bytecodeOffset: plan.bytecodeOffset,
                bytecodeSize: plan.bytecodeSize,
                blocks: patchedBlocks,
                syncSafe: patchedBlocks.allSatisfy { $0.syncSafe }
            )
        }

        return Policy(
            strings: policy.strings,
            numbers: policy.numbers,
            functions: policy.functions,
            plans: patchedPlans,
            bytecode: bc,
            builtinFuncs: policy.builtinFuncs
        )
    }

    // MARK: - Block patching

    /// Writes sync bits for all nesting instructions in the given block region.
    /// Returns nested (offset, size) pairs for sub-blocks found (to be added to the worklist).
    private static func patchBlock(
        bytecode: inout ContiguousArray<UInt8>,
        strings: [String],
        offset: Int,
        size: Int,
        functionSyncSafe: (Int) -> Bool,
        builtins: BuiltinRegistry
    ) -> [(offset: Int, size: Int)] {
        var nested: [(offset: Int, size: Int)] = []
        var pc = offset
        let end = offset + size

        while pc < end {
            let word = bytecode.withUnsafeBytes { $0.load(fromByteOffset: pc, as: UInt32.self) }
            let opcodeRaw = UInt8((word >> 24) & 0x3F)
            let length = Int(word & 0xFFFFFF)
            let ps = pc + 4  // payload start

            guard let opcode = Opcode(rawValue: opcodeRaw) else { break }
            if opcode.isCompact {
                pc += 4
                continue
            }

            switch opcode {
            case .block1, .not:
                // Body is the entire payload: [ps, ps+length)
                let safe = isBlockSyncSafe(
                    bytecode: bytecode, strings: strings,
                    offset: ps, size: length,
                    functionSyncSafe: functionSyncSafe, builtins: builtins
                )
                if safe {
                    writeWord(&bytecode, at: pc, value: word | 0x4000_0000)
                }
                nested.append((ps, length))

            case .scan:
                // Body starts after [source:4][key:4][value:4]
                if length > 12 {
                    let bodyOffset = ps + 12
                    let bodySize = length - 12
                    let safe = isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: bodyOffset, size: bodySize,
                        functionSyncSafe: functionSyncSafe, builtins: builtins
                    )
                    if safe {
                        writeWord(&bytecode, at: pc, value: word | 0x4000_0000)
                    }
                    nested.append((bodyOffset, bodySize))
                }

            case .with:
                // [local:4][value operand:4][pathCount:4][pathIndices:4*n][body...]
                let pathCount = Int(
                    bytecode.withUnsafeBytes {
                        $0.load(fromByteOffset: ps + 8, as: UInt32.self)
                    })
                let bodyOffset = ps + 12 + pathCount * 4
                let bodySize = length - 12 - pathCount * 4
                if bodySize > 0 {
                    let safe = isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: bodyOffset, size: bodySize,
                        functionSyncSafe: functionSyncSafe, builtins: builtins
                    )
                    if safe {
                        writeWord(&bytecode, at: pc, value: word | 0x4000_0000)
                    }
                    nested.append((bodyOffset, bodySize))
                }

            case .block:
                // [numBlocks:4][{offset:4, size:4}...]
                let n = Int(
                    bytecode.withUnsafeBytes {
                        $0.load(fromByteOffset: ps, as: UInt32.self)
                    })
                for i in 0..<n {
                    let bOff = Int(
                        bytecode.withUnsafeBytes {
                            $0.load(fromByteOffset: ps + 4 + i * 8, as: UInt32.self)
                        })
                    let bSizeRaw = bytecode.withUnsafeBytes {
                        $0.load(fromByteOffset: ps + 4 + i * 8 + 4, as: UInt32.self)
                    }
                    let bSize = Int(bSizeRaw & 0x7FFF_FFFF)  // mask off any pre-existing sync bit
                    let safe = isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: bOff, size: bSize,
                        functionSyncSafe: functionSyncSafe, builtins: builtins
                    )
                    if safe {
                        writeWord(&bytecode, at: ps + 4 + i * 8 + 4, value: bSizeRaw | 0x8000_0000)
                    }
                    nested.append((bOff, bSize))
                }

            case .call:
                // [result:4][encodedFuncIndex:4][argCount:4][args...]
                let rawFuncIdx = bytecode.withUnsafeBytes {
                    $0.load(fromByteOffset: ps + 4, as: UInt32.self)
                }
                if rawFuncIdx & 0x8000_0000 == 0 {
                    // User function: set bit 30 if sync-safe
                    let funcIdx = Int(rawFuncIdx & 0x3FFF_FFFF)
                    if functionSyncSafe(funcIdx) {
                        writeWord(&bytecode, at: ps + 4, value: rawFuncIdx | 0x4000_0000)
                    }
                }

            default:
                break
            }

            pc = ps + length
        }

        return nested
    }

    // MARK: - Sync-safety check

    /// Returns `true` if the bytecode region `[offset, offset+size)` is safe to
    /// execute on the synchronous path.  Recurses into inline sub-blocks.
    ///
    /// Masks off sync bits when reading sub-block sizes and funcIndex fields so
    /// that this function is safe to call on partially-patched bytecode.
    private static func isBlockSyncSafe(
        bytecode: ContiguousArray<UInt8>,
        strings: [String],
        offset: Int,
        size: Int,
        functionSyncSafe: (Int) -> Bool,
        builtins: BuiltinRegistry
    ) -> Bool {
        var pc = offset
        let end = offset + size
        while pc < end {
            let word = bytecode.withUnsafeBytes { $0.load(fromByteOffset: pc, as: UInt32.self) }
            let opcodeRaw = UInt8((word >> 24) & 0x3F)
            let length = Int(word & 0xFFFFFF)
            let ps = pc + 4
            guard let opcode = Opcode(rawValue: opcodeRaw) else { return false }
            if opcode.isCompact {
                pc += 4
                continue
            }
            switch opcode {
            case .callDynamic:
                return false  // runtime-resolved target: conservatively async-unsafe
            case .call:
                let rawFuncIdx = bytecode.withUnsafeBytes {
                    $0.load(fromByteOffset: ps + 4, as: UInt32.self)
                }
                if rawFuncIdx & 0x8000_0000 != 0 {
                    // Builtin: require a sync implementation
                    let stringIdx = Int(rawFuncIdx & 0x7FFF_FFFF)
                    guard stringIdx < strings.count else { return false }
                    if builtins.syncLookup(strings[stringIdx]) == nil { return false }
                } else {
                    let funcIdx = Int(rawFuncIdx & 0x3FFF_FFFF)  // mask sync bit
                    if !functionSyncSafe(funcIdx) { return false }
                }
            case .block:
                let n = Int(
                    bytecode.withUnsafeBytes {
                        $0.load(fromByteOffset: ps, as: UInt32.self)
                    })
                for i in 0..<n {
                    let bOffset = Int(
                        bytecode.withUnsafeBytes {
                            $0.load(fromByteOffset: ps + 4 + i * 8, as: UInt32.self)
                        })
                    let bSize = Int(
                        bytecode.withUnsafeBytes {
                            $0.load(fromByteOffset: ps + 4 + i * 8 + 4, as: UInt32.self)
                        } & 0x7FFF_FFFF)  // mask sync bit
                    if !isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: bOffset, size: bSize,
                        functionSyncSafe: functionSyncSafe, builtins: builtins)
                    {
                        return false
                    }
                }
            case .block1, .not:
                if !isBlockSyncSafe(
                    bytecode: bytecode, strings: strings,
                    offset: ps, size: length,
                    functionSyncSafe: functionSyncSafe, builtins: builtins)
                {
                    return false
                }
            case .scan:
                if length > 12 {
                    if !isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: ps + 12, size: length - 12,
                        functionSyncSafe: functionSyncSafe, builtins: builtins)
                    {
                        return false
                    }
                }
            case .with:
                let pathCount = Int(
                    bytecode.withUnsafeBytes {
                        $0.load(fromByteOffset: ps + 8, as: UInt32.self)
                    })
                let bodyOffset = ps + 12 + pathCount * 4
                let bodySize = length - 12 - pathCount * 4
                if bodySize > 0 {
                    if !isBlockSyncSafe(
                        bytecode: bytecode, strings: strings,
                        offset: bodyOffset, size: bodySize,
                        functionSyncSafe: functionSyncSafe, builtins: builtins)
                    {
                        return false
                    }
                }
            default:
                break  // all other opcodes are inherently sync-safe
            }
            pc = ps + length
        }
        return true
    }

    // MARK: - Helpers

    @inline(__always)
    private static func writeWord(_ bytecode: inout ContiguousArray<UInt8>, at offset: Int, value: UInt32) {
        bytecode.withUnsafeMutableBytes {
            $0.storeBytes(of: value, toByteOffset: offset, as: UInt32.self)
        }
    }
}
