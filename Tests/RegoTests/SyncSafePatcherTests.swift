import AST
import Bytecode
import Testing

@testable import Rego

@Suite struct SyncSafePatcherTests {

    // MARK: - Helpers

    private func makePolicy(
        plans: [Plan] = [],
        functions: [Bytecode.Function] = [],
        strings: [String] = [],
        bytecode: ContiguousArray<UInt8> = []
    ) -> Bytecode.Policy {
        Bytecode.Policy(
            strings: strings,
            numbers: [],
            functions: functions,
            plans: plans,
            bytecode: bytecode
        )
    }

    private func singlePlan(offset: Int = 0, size: Int) -> Plan {
        Plan(
            name: "test",
            maxLocal: 0,
            bytecodeOffset: offset,
            bytecodeSize: size,
            blocks: [(offset: offset, size: size, syncSafe: false)]
        )
    }

    private func syncRegistry() -> BuiltinRegistry {
        .defaultRegistry
    }

    private func registryWithAsyncBuiltin(name: String) throws -> BuiltinRegistry {
        try BuiltinRegistry.merging(customBuiltins: [name: { _, _ in .null }])
    }

    private func readWord(_ bc: ContiguousArray<UInt8>, at offset: Int) -> UInt32 {
        bc.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    }

    // MARK: - plan.syncSafe

    @Test func testEmptyPlanIsSyncSafe() {
        // A plan with no instructions is trivially sync-safe.
        var enc = Encoder()
        enc.appendHeader(.nop, payloadLength: 0)
        let p = makePolicy(plans: [singlePlan(size: enc.bytes.count)], bytecode: enc.bytes)
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        #expect(patched.plans[0].syncSafe == true)
        #expect(patched.plans[0].blocks[0].syncSafe == true)
    }

    @Test func testPlanWithOnlySyncBuiltinsIsSyncSafe() throws {
        // A call to "plus" (sync builtin) should leave the plan sync-safe.
        var enc = Encoder()
        enc.appendHeader(.call, payloadLength: 12)
        enc.appendLocal(0)  // result
        enc.appendUInt32(0x8000_0000 | 0)  // builtin flag | string index 0
        enc.appendUInt32(0)  // 0 args
        let p = makePolicy(
            plans: [singlePlan(size: enc.bytes.count)],
            strings: ["plus"],
            bytecode: enc.bytes
        )
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        #expect(patched.plans[0].syncSafe == true)
    }

    @Test func testPlanWithAsyncBuiltinIsNotSyncSafe() throws {
        // A call to "custom.async" (async-only builtin) must mark the plan unsafe.
        var enc = Encoder()
        enc.appendHeader(.call, payloadLength: 12)
        enc.appendLocal(0)
        enc.appendUInt32(0x8000_0000 | 0)  // builtin flag | string index 0
        enc.appendUInt32(0)
        let p = makePolicy(
            plans: [singlePlan(size: enc.bytes.count)],
            strings: ["custom.async"],
            bytecode: enc.bytes
        )
        let registry = try registryWithAsyncBuiltin(name: "custom.async")
        let patched = SyncSafePatcher.patch(policy: p, builtins: registry)
        #expect(patched.plans[0].syncSafe == false)
    }

    @Test func testPlanWithCallDynamicIsNotSyncSafe() {
        // callDynamic is always async-unsafe.
        var enc = Encoder()
        enc.appendHeader(.callDynamic, payloadLength: 8)
        enc.appendLocal(0)  // result
        enc.appendUInt32(0)  // pathCount = 0
        let p = makePolicy(plans: [singlePlan(size: enc.bytes.count)], bytecode: enc.bytes)
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        #expect(patched.plans[0].syncSafe == false)
    }

    // MARK: - User function propagation

    @Test func testSyncSafeFunctionCallMarksPlanSafe() {
        // A user function whose body contains only nop is sync-safe;
        // the plan calling it should also be sync-safe.
        var fnEnc = Encoder()
        fnEnc.appendHeader(.nop, payloadLength: 0)
        let fnOffset = 0
        let fnSize = fnEnc.bytes.count

        var planEnc = Encoder()
        planEnc.appendHeader(.call, payloadLength: 12)
        planEnc.appendLocal(0)
        planEnc.appendUInt32(0)  // user func index 0 (bit 31 clear)
        planEnc.appendUInt32(0)

        var bc = fnEnc.bytes
        let planOffset = bc.count
        bc.append(contentsOf: planEnc.bytes)

        let fn = Bytecode.Function(
            name: "f", path: [], params: [], returnVar: Local(0), maxLocal: 0,
            bytecodeOffset: fnOffset, bytecodeSize: fnSize,
            blocks: [(offset: fnOffset, size: fnSize)]
        )
        let p = makePolicy(
            plans: [singlePlan(offset: planOffset, size: planEnc.bytes.count)],
            functions: [fn],
            bytecode: bc
        )
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        #expect(patched.plans[0].syncSafe == true)
    }

    @Test func testAsyncFunctionCallMarksPlanUnsafe() throws {
        // A user function that calls an async builtin is async-unsafe;
        // the plan calling it must also be marked unsafe.
        var fnEnc = Encoder()
        fnEnc.appendHeader(.call, payloadLength: 12)
        fnEnc.appendLocal(0)
        fnEnc.appendUInt32(0x8000_0000 | 0)  // builtin "custom.async"
        fnEnc.appendUInt32(0)
        let fnOffset = 0
        let fnSize = fnEnc.bytes.count

        var planEnc = Encoder()
        planEnc.appendHeader(.call, payloadLength: 12)
        planEnc.appendLocal(0)
        planEnc.appendUInt32(0)  // user func index 0
        planEnc.appendUInt32(0)

        var bc = fnEnc.bytes
        let planOffset = bc.count
        bc.append(contentsOf: planEnc.bytes)

        let fn = Bytecode.Function(
            name: "f", path: [], params: [], returnVar: Local(0), maxLocal: 0,
            bytecodeOffset: fnOffset, bytecodeSize: fnSize,
            blocks: [(offset: fnOffset, size: fnSize)]
        )
        let p = makePolicy(
            plans: [singlePlan(offset: planOffset, size: planEnc.bytes.count)],
            functions: [fn],
            strings: ["custom.async"],
            bytecode: bc
        )
        let registry = try registryWithAsyncBuiltin(name: "custom.async")
        let patched = SyncSafePatcher.patch(policy: p, builtins: registry)
        #expect(patched.plans[0].syncSafe == false)
    }

    // MARK: - Sync bits in bytecode

    @Test func testBlock1HeaderBitSetWhenSyncSafe() {
        // A block1 whose body has only nop should get bit 30 set.
        var enc = Encoder()
        let block1PC = enc.offset
        enc.appendHeader(.block1, payloadLength: 4)  // body = 4 bytes
        enc.appendHeader(.nop, payloadLength: 0)  // body content
        let p = makePolicy(plans: [singlePlan(size: enc.bytes.count)], bytecode: enc.bytes)
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        let word = readWord(patched.bytecode, at: block1PC)
        #expect(word & 0x4000_0000 != 0, "bit 30 should be set on sync-safe block1")
    }

    @Test func testBlock1HeaderBitClearedWhenAsyncUnsafe() throws {
        // A block1 whose body calls an async builtin should NOT get bit 30 set.
        var enc = Encoder()
        let block1PC = enc.offset
        let bodySize: UInt32 = 16  // call instruction: header(4)+result(4)+funcIdx(4)+argCount(4)
        enc.appendHeader(.block1, payloadLength: bodySize)
        enc.appendHeader(.call, payloadLength: 12)
        enc.appendLocal(0)
        enc.appendUInt32(0x8000_0000 | 0)
        enc.appendUInt32(0)
        let p = makePolicy(
            plans: [singlePlan(size: enc.bytes.count)],
            strings: ["custom.async"],
            bytecode: enc.bytes
        )
        let registry = try registryWithAsyncBuiltin(name: "custom.async")
        let patched = SyncSafePatcher.patch(policy: p, builtins: registry)
        let word = readWord(patched.bytecode, at: block1PC)
        #expect(word & 0x4000_0000 == 0, "bit 30 should NOT be set on async-unsafe block1")
    }

    @Test func testCallFuncIndexBitSetWhenFunctionSyncSafe() {
        // When a user function is sync-safe, bit 30 of its encodedFuncIndex should be set.
        var fnEnc = Encoder()
        fnEnc.appendHeader(.nop, payloadLength: 0)
        let fnOffset = 0
        let fnSize = fnEnc.bytes.count

        var planEnc = Encoder()
        planEnc.appendHeader(.call, payloadLength: 12)
        planEnc.appendLocal(0)
        let funcIdxOffset = planEnc.offset
        planEnc.appendUInt32(0)  // user func index 0
        planEnc.appendUInt32(0)

        var bc = fnEnc.bytes
        let planOffset = bc.count
        bc.append(contentsOf: planEnc.bytes)

        let fn = Bytecode.Function(
            name: "f", path: [], params: [], returnVar: Local(0), maxLocal: 0,
            bytecodeOffset: fnOffset, bytecodeSize: fnSize,
            blocks: [(offset: fnOffset, size: fnSize)]
        )
        let p = makePolicy(
            plans: [singlePlan(offset: planOffset, size: planEnc.bytes.count)],
            functions: [fn],
            bytecode: bc
        )
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        let funcIdxWord = readWord(patched.bytecode, at: planOffset + funcIdxOffset)
        #expect(funcIdxWord & 0x4000_0000 != 0, "bit 30 should be set on sync-safe user function call")
    }

    @Test func testBlockSubBlockBitSetWhenSyncSafe() {
        // A block instruction whose sub-block contains only nop should get bit 31 in its size field.
        var enc = Encoder()
        let blockPC = enc.offset
        // block: numBlocks=1, then {offset:4, size:4} where size is after the block header
        let subBlockOffset = 4 + 4 + 8  // header(4) + numBlocks(4) + descriptor(8)
        let subBlockSize = 4  // one nop
        enc.appendHeader(.block, payloadLength: 4 + 8)  // numBlocks(4) + 1×{off,size}(8)
        enc.appendUInt32(1)  // numBlocks = 1
        enc.appendUInt32(UInt32(subBlockOffset))
        enc.appendUInt32(UInt32(subBlockSize))
        enc.appendHeader(.nop, payloadLength: 0)  // sub-block content
        let p = makePolicy(plans: [singlePlan(size: enc.bytes.count)], bytecode: enc.bytes)
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        // sub-block size field is at: header(4)+numBlocks(4)+offset(4) = offset 12
        let sizeWord = readWord(patched.bytecode, at: blockPC + 12)
        #expect(sizeWord & 0x8000_0000 != 0, "bit 31 should be set on sync-safe block sub-block size")
    }

    // MARK: - Compact opcodes

    @Test func testPlanWithOnlyCompactOpcodesIsSyncSafe() {
        // Compact opcodes (isDefined1, resetLocal1, returnLocal1) pack their operand into the
        // header length field; the patcher must advance pc by exactly 4, not ps+length.
        var enc = Encoder()
        enc.appendHeader(.isDefined1, payloadLength: 0)
        enc.appendHeader(.resetLocal1, payloadLength: 1)
        enc.appendHeader(.returnLocal1, payloadLength: 2)
        let p = makePolicy(plans: [singlePlan(size: enc.bytes.count)], bytecode: enc.bytes)
        let patched = SyncSafePatcher.patch(policy: p, builtins: syncRegistry())
        #expect(patched.plans[0].syncSafe == true)
        #expect(patched.plans[0].blocks[0].syncSafe == true)
    }

    @Test func testCompactOpcodePCAdvanceIsCorrect() throws {
        // isDefined1 with local index 12: the "length" field holds 12.
        // If the patcher mistakenly uses pc = ps+length it jumps 16 bytes ahead,
        // skips the async call, and wrongly marks the block sync-safe.
        var enc = Encoder()
        enc.appendHeader(.isDefined1, payloadLength: 12)  // compact: local 12, 4 bytes total
        enc.appendHeader(.call, payloadLength: 12)
        enc.appendLocal(0)
        enc.appendUInt32(0x8000_0000 | 0)  // builtin "custom.async"
        enc.appendUInt32(0)
        let p = makePolicy(
            plans: [singlePlan(size: enc.bytes.count)],
            strings: ["custom.async"],
            bytecode: enc.bytes
        )
        let registry = try registryWithAsyncBuiltin(name: "custom.async")
        let patched = SyncSafePatcher.patch(policy: p, builtins: registry)
        #expect(patched.plans[0].syncSafe == false)
    }
}
