import AST
import Foundation
import Testing

@testable import Bytecode
@testable import IR

@Suite struct BytecodeConverterTests {

    // MARK: - Helpers

    // Read a little-endian UInt32 from a ContiguousArray<UInt8>
    private func readLE32(_ bytes: ContiguousArray<UInt8>, at i: Int) -> UInt32 {
        UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
    }

    // Read a little-endian Int64 from a ContiguousArray<UInt8>
    private func readLE64(_ bytes: ContiguousArray<UInt8>, at i: Int) -> Int64 {
        let lo = UInt64(readLE32(bytes, at: i))
        let hi = UInt64(readLE32(bytes, at: i + 4))
        return Int64(bitPattern: lo | hi << 32)
    }

    // Read a decoded operand at a byte offset
    private func readOperand(_ bytes: ContiguousArray<UInt8>, at i: Int) -> EncodedOperand {
        EncodedOperand.decode(from: Data(bytes), at: i).0
    }

    // Wrap one statement in a minimal single-block plan and convert it
    private func convert(
        stmt: IR.Statement, staticStrings: [String] = [], staticStringNumbers: [Int] = [], funcs: [IR.Func] = []
    ) throws -> Bytecode.Policy {
        var policy = IR.Policy(
            staticData: staticStrings.isEmpty
                ? nil
                : IR.Static(
                    strings: staticStrings.map { IR.ConstString(value: $0) }
                ),
            plans: IR.Plans(plans: [
                IR.Plan(name: "test", blocks: [IR.Block(statements: [stmt])])
            ]),
            funcs: funcs.isEmpty ? nil : IR.Funcs(funcs: funcs)
        )
        policy.staticStringNumbers = staticStringNumbers
        return try Converter.convert(policy)
    }

    // MARK: - String Table Tests

    @Test func testStringTableBuilder() throws {
        var builder = StringTableBuilder()

        let idx1 = builder.intern("hello")
        let idx2 = builder.intern("world")
        let idx3 = builder.intern("hello")  // Duplicate

        #expect(idx1 == 0)
        #expect(idx2 == 1)
        #expect(idx3 == 0)  // Should return same index
        #expect(builder.count == 2)
        #expect(builder.table == ["hello", "world"])
    }

    // MARK: - Operand Conversion Tests

    @Test func testConvertLocalOperand() throws {
        var context = ConversionContext()
        let operand = IR.Operand(type: .local, value: .localIndex(42))

        let encoded = try context.convertOperand(operand)

        #expect(encoded.type == OperandType.local)
        #expect(encoded.value == 42)
    }

    @Test func testConvertBoolOperand() throws {
        var context = ConversionContext()
        let operand = IR.Operand(type: .bool, value: .bool(true))

        let encoded = try context.convertOperand(operand)

        #expect(encoded.type == OperandType.bool)
        #expect(encoded.value == 1)
    }

    @Test func testConvertStringIndexOperand() throws {
        var context = ConversionContext()
        let operand = IR.Operand(type: .stringIndex, value: .stringIndex(10))

        let encoded = try context.convertOperand(operand)

        #expect(encoded.type == OperandType.stringIndex)
        #expect(encoded.value == 10)
    }

    // MARK: - Compact Opcode Tests

    @Test func testConvertBreak() throws {
        let bc = try convert(stmt: .breakStmt(IR.BreakStatement(index: 3)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .break1)
        #expect(header.length == 3)  // index stored in length field
    }

    @Test func testConvertIsDefined() throws {
        let bc = try convert(stmt: .isDefinedStmt(IR.IsDefinedStatement(source: 7)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .isDefined1)
        #expect(header.length == 7)  // source local index in length field
    }

    @Test func testConvertIsUndefined() throws {
        let bc = try convert(stmt: .isUndefinedStmt(IR.IsUndefinedStatement(source: 4)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .isUndefined1)
        #expect(header.length == 4)
    }

    @Test func testConvertResetLocal() throws {
        let bc = try convert(stmt: .resetLocalStmt(IR.ResetLocalStatement(target: 5)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .resetLocal1)
        #expect(header.length == 5)
    }

    @Test func testConvertResultSetAdd() throws {
        let bc = try convert(stmt: .resultSetAddStmt(IR.ResultSetAddStatement(value: 6)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .resultSetAdd1)
        #expect(header.length == 6)
    }

    @Test func testConvertReturnLocal() throws {
        let bc = try convert(stmt: .returnLocalStmt(IR.ReturnLocalStatement(source: 2)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .returnLocal1)
        #expect(header.length == 2)
    }

    @Test func testConvertAssignVarCompact() throws {
        // Both target and source fit in 12 bits → assignVar1
        let bc = try convert(
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .local, value: .localIndex(3)),
                    target: 5
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .assignVar1)
        // packed = target<<12 | source = 5<<12 | 3 = 0x5003
        #expect(header.length == (5 << 12) | 3)
    }

    @Test func testConvertAssignVarNonCompact() throws {
        // Non-local source (bool) → full assignVar
        let bc = try convert(
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .bool, value: .bool(false)),
                    target: 1
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .assignVar)
        #expect(header.length == 8)  // target(4) + operand(4)
        // target local at offset 4
        #expect(readOperand(bc.bytecode, at: 4).value == 1)
        // bool operand at offset 8
        let boolOp = readOperand(bc.bytecode, at: 8)
        #expect(boolOp.type == .bool)
        #expect(boolOp.value == 0)  // false
    }

    // MARK: - Statement Conversion Tests

    @Test func testConvertArrayAppend() throws {
        let bc = try convert(
            stmt: .arrayAppendStmt(
                IR.ArrayAppendStatement(
                    array: 2,
                    value: IR.Operand(type: .local, value: .localIndex(3))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .arrayAppend)
        #expect(header.length == 8)  // array local(4) + operand(4)
        // array local at offset 4
        #expect(readOperand(bc.bytecode, at: 4).value == 2)
        // value operand at offset 8
        let valOp = readOperand(bc.bytecode, at: 8)
        #expect(valOp.type == .local)
        #expect(valOp.value == 3)
    }

    @Test func testConvertAssignInt() throws {
        let bc = try convert(stmt: .assignIntStmt(IR.AssignIntStatement(value: 42, target: 0)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .assignInt)
        #expect(header.length == 12)  // int64(8) + local(4)
        #expect(readLE64(bc.bytecode, at: 4) == 42)
        #expect(readOperand(bc.bytecode, at: 12).value == 0)
    }

    @Test func testConvertAssignVarOnce() throws {
        let bc = try convert(
            stmt: .assignVarOnceStmt(
                IR.AssignVarOnceStatement(
                    source: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    target: 1
                )),
            staticStrings: ["hello"]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .assignVarOnce)
        #expect(header.length == 8)  // target local(4) + source operand(4)
        // target is written first
        #expect(readOperand(bc.bytecode, at: 4).value == 1)
        let srcOp = readOperand(bc.bytecode, at: 8)
        #expect(srcOp.type == .stringIndex)
        #expect(srcOp.value == 0)
    }

    @Test func testConvertDot() throws {
        let bc = try convert(
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    target: 4
                )),
            staticStrings: ["mykey"]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .dot)
        #expect(header.length == 12)  // source(4) + key(4) + target(4)
        let src = readOperand(bc.bytecode, at: 4)
        #expect(src.type == .local)
        #expect(src.value == 2)
        let key = readOperand(bc.bytecode, at: 8)
        #expect(key.type == .stringIndex)
        #expect(key.value == 0)
        #expect(readOperand(bc.bytecode, at: 12).value == 4)
    }

    @Test func testConvertEqual() throws {
        let bc = try convert(
            stmt: .equalStmt(
                IR.EqualStatement(
                    a: IR.Operand(type: .local, value: .localIndex(2)),
                    b: IR.Operand(type: .bool, value: .bool(true))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .equal)
        #expect(header.length == 8)  // a(4) + b(4)
        let a = readOperand(bc.bytecode, at: 4)
        #expect(a.type == .local)
        #expect(a.value == 2)
        let b = readOperand(bc.bytecode, at: 8)
        #expect(b.type == .bool)
        #expect(b.value == 1)  // true
    }

    @Test func testConvertIsArray() throws {
        let bc = try convert(
            stmt: .isArrayStmt(
                IR.IsArrayStatement(
                    source: IR.Operand(type: .local, value: .localIndex(3))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .isArray)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 3)
    }

    @Test func testConvertIsObject() throws {
        let bc = try convert(
            stmt: .isObjectStmt(
                IR.IsObjectStatement(
                    source: IR.Operand(type: .local, value: .localIndex(5))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .isObject)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 5)
    }

    @Test func testConvertIsSet() throws {
        let bc = try convert(
            stmt: .isSetStmt(
                IR.IsSetStatement(
                    source: IR.Operand(type: .local, value: .localIndex(7))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .isSet)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 7)
    }

    @Test func testConvertLen() throws {
        let bc = try convert(
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: 3
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .len)
        #expect(header.length == 8)  // source(4) + target(4)
        #expect(readOperand(bc.bytecode, at: 4).value == 2)
        #expect(readOperand(bc.bytecode, at: 8).value == 3)
    }

    @Test func testConvertMakeArray() throws {
        let bc = try convert(stmt: .makeArrayStmt(IR.MakeArrayStatement(capacity: 8, target: 2)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeArray)
        #expect(header.length == 8)  // capacity(4) + target(4)
        #expect(readLE32(bc.bytecode, at: 4) == 8)  // capacity
        #expect(readOperand(bc.bytecode, at: 8).value == 2)  // target
    }

    @Test func testConvertMakeNull() throws {
        let bc = try convert(stmt: .makeNullStmt(IR.MakeNullStatement(target: 5)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeNull)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 5)
    }

    @Test func testConvertMakeNumberInt() throws {
        let bc = try convert(stmt: .makeNumberIntStmt(IR.MakeNumberIntStatement(value: -99, target: 3)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeNumberInt)
        #expect(header.length == 12)  // int64(8) + target(4)
        #expect(readLE64(bc.bytecode, at: 4) == -99)
        #expect(readOperand(bc.bytecode, at: 12).value == 3)
    }

    @Test func testConvertMakeNumberRef() throws {
        // staticStringNumbers = [0] tells buildNumberTable to parse strings[0] as a number
        let bc = try convert(
            stmt: .makeNumberRefStmt(IR.MakeNumberRefStatement(index: 0, target: 4)),
            staticStrings: ["3.14"],
            staticStringNumbers: [0]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeNumberRef)
        #expect(header.length == 8)  // index(4) + target(4)
        #expect(readLE32(bc.bytecode, at: 4) == 0)  // string index 0
        #expect(readOperand(bc.bytecode, at: 8).value == 4)  // target local
        // Verify the number table was populated
        #expect(bc.numbers.count == 1)
        #expect(bc.numbers[0] != nil)
    }

    @Test func testConvertMakeObject() throws {
        let bc = try convert(stmt: .makeObjectStmt(IR.MakeObjectStatement(target: 6)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeObject)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 6)
    }

    @Test func testConvertMakeSet() throws {
        let bc = try convert(stmt: .makeSetStmt(IR.MakeSetStatement(target: 7)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .makeSet)
        #expect(header.length == 4)
        #expect(readOperand(bc.bytecode, at: 4).value == 7)
    }

    @Test func testConvertNop() throws {
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(stmt: .nopStmt(nop))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .nop)
        #expect(header.length == 0)
    }

    @Test func testConvertNotEqual() throws {
        let bc = try convert(
            stmt: .notEqualStmt(
                IR.NotEqualStatement(
                    a: IR.Operand(type: .local, value: .localIndex(2)),
                    b: IR.Operand(type: .local, value: .localIndex(3))
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .notEqual)
        #expect(header.length == 8)
        #expect(readOperand(bc.bytecode, at: 4).value == 2)
        #expect(readOperand(bc.bytecode, at: 8).value == 3)
    }

    @Test func testConvertNot() throws {
        // not wraps a block; its payload is the block content (a single nop = 4 bytes)
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(stmt: .notStmt(IR.NotStatement(block: IR.Block(statements: [.nopStmt(nop)]))))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .not)
        #expect(header.length == 4)  // nop = 4-byte header, no payload
        // Inner nop header at offset 4
        let innerHeader = try InstructionHeader.decode(readLE32(bc.bytecode, at: 4))
        #expect(innerHeader.opcode == .nop)
    }

    @Test func testConvertObjectInsertOnce() throws {
        let bc = try convert(
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: 4
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .objectInsertOnce)
        #expect(header.length == 12)  // object(4) + key(4) + value(4)
        #expect(readOperand(bc.bytecode, at: 4).value == 4)  // object
        #expect(readOperand(bc.bytecode, at: 8).value == 2)  // key
        #expect(readOperand(bc.bytecode, at: 12).value == 3)  // value
    }

    @Test func testConvertObjectInsert() throws {
        let bc = try convert(
            stmt: .objectInsertStmt(
                IR.ObjectInsertStatement(
                    key: IR.Operand(type: .bool, value: .bool(true)),
                    value: IR.Operand(type: .local, value: .localIndex(5)),
                    object: 6
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .objectInsert)
        #expect(header.length == 12)
        #expect(readOperand(bc.bytecode, at: 4).value == 6)  // object
        let keyOp = readOperand(bc.bytecode, at: 8)
        #expect(keyOp.type == .bool)
        #expect(keyOp.value == 1)
        #expect(readOperand(bc.bytecode, at: 12).value == 5)  // value
    }

    @Test func testConvertObjectMerge() throws {
        let bc = try convert(stmt: .objectMergeStmt(IR.ObjectMergeStatement(a: 2, b: 3, target: 4)))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .objectMerge)
        #expect(header.length == 12)  // target(4) + a(4) + b(4)
        #expect(readOperand(bc.bytecode, at: 4).value == 4)  // target
        #expect(readOperand(bc.bytecode, at: 8).value == 2)  // a
        #expect(readOperand(bc.bytecode, at: 12).value == 3)  // b
    }

    @Test func testConvertScan() throws {
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: 2, key: 3, value: 4,
                    block: IR.Block(statements: [.nopStmt(nop)])
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .scan)
        // payload: source(4) + key(4) + value(4) + nop(4) = 16
        #expect(header.length == 16)
        #expect(readOperand(bc.bytecode, at: 4).value == 2)  // source
        #expect(readOperand(bc.bytecode, at: 8).value == 3)  // key
        #expect(readOperand(bc.bytecode, at: 12).value == 4)  // value
        let innerHeader = try InstructionHeader.decode(readLE32(bc.bytecode, at: 16))
        #expect(innerHeader.opcode == .nop)
    }

    @Test func testConvertSetAdd() throws {
        let bc = try convert(
            stmt: .setAddStmt(
                IR.SetAddStatement(
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    set: 2
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .setAdd)
        #expect(header.length == 8)  // set(4) + operand(4)
        #expect(readOperand(bc.bytecode, at: 4).value == 2)  // set local
        #expect(readOperand(bc.bytecode, at: 8).value == 3)  // value operand
    }

    @Test func testConvertWith() throws {
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(
            stmt: .withStmt(
                IR.WithStatement(
                    local: 5,
                    path: [0, 1],
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    block: IR.Block(statements: [.nopStmt(nop)])
                )),
            staticStrings: ["data", "foo"]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .with)
        // payload: local(4) + value_op(4) + pathCount(4) + 2*pathIdx(8) + nop(4) = 24
        #expect(header.length == 24)
        #expect(readOperand(bc.bytecode, at: 4).value == 5)  // local
        let valOp = readOperand(bc.bytecode, at: 8)
        #expect(valOp.type == .local)
        #expect(valOp.value == 3)
        let pathCount = readLE32(bc.bytecode, at: 12)
        #expect(pathCount == 2)
        #expect(readLE32(bc.bytecode, at: 16) == 0)  // path[0]
        #expect(readLE32(bc.bytecode, at: 20) == 1)  // path[1]
        let innerHeader = try InstructionHeader.decode(readLE32(bc.bytecode, at: 24))
        #expect(innerHeader.opcode == .nop)
    }

    // MARK: - Block Statement Tests

    @Test func testConvertBlockStmtSingleBlock() throws {
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(
            stmt: .blockStmt(
                IR.BlockStatement(blocks: [
                    IR.Block(statements: [.nopStmt(nop)])
                ])))
        // Single sub-block → block1 with payload = block content (nop = 4 bytes)
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .block1)
        #expect(header.length == 4)
        let innerHeader = try InstructionHeader.decode(readLE32(bc.bytecode, at: 4))
        #expect(innerHeader.opcode == .nop)
    }

    @Test func testConvertBlockStmtZeroBlocks() throws {
        let bc = try convert(stmt: .blockStmt(IR.BlockStatement(blocks: [])))
        // Zero sub-blocks → general block encoding with numBlocks=0
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .block)
        // payload: numBlocks(4) = 4
        #expect(header.length == 4)
        #expect(readLE32(bc.bytecode, at: 4) == 0)  // numBlocks
    }

    @Test func testConvertBlockStmtTwoBlocks() throws {
        let nop = try JSONDecoder().decode(IR.NopStatement.self, from: Data("{}".utf8))
        let bc = try convert(
            stmt: .blockStmt(
                IR.BlockStatement(blocks: [
                    IR.Block(statements: [.nopStmt(nop)]),
                    IR.Block(statements: [.nopStmt(nop)]),
                ])))
        // 2 sub-blocks → general block encoding
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .block)
        // payload: numBlocks(4) + 2*(offset(4)+size(4)) + nop(4) + nop(4) = 4+16+4+4 = 28
        #expect(header.length == 28)
        #expect(readLE32(bc.bytecode, at: 4) == 2)  // numBlocks

        // Offsets are absolute byte positions; sizes are 4 (single nop)
        let block0offset = readLE32(bc.bytecode, at: 8)
        let block0size = readLE32(bc.bytecode, at: 12)
        let block1offset = readLE32(bc.bytecode, at: 16)
        let block1size = readLE32(bc.bytecode, at: 20)

        #expect(block0size == 4)
        #expect(block1size == 4)
        #expect(block1offset == block0offset + block0size)

        let inner0 = try InstructionHeader.decode(readLE32(bc.bytecode, at: Int(block0offset)))
        #expect(inner0.opcode == .nop)
        let inner1 = try InstructionHeader.decode(readLE32(bc.bytecode, at: Int(block1offset)))
        #expect(inner1.opcode == .nop)
    }

    // MARK: - Call Tests

    @Test func testConvertCallUserFunction() throws {
        let fn = IR.Func(
            name: "g0.f",
            path: ["g0", "f"],
            params: [Local(0), Local(1)],
            returnVar: Local(2),
            blocks: [IR.Block(statements: [])]
        )
        let bc = try convert(
            stmt: .callStmt(
                IR.CallStatement(
                    callFunc: "g0.f",
                    args: [
                        IR.Operand(type: .local, value: .localIndex(0)),
                        IR.Operand(type: .local, value: .localIndex(1)),
                    ],
                    result: 2
                )),
            funcs: [fn]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .call)
        // payload: result(4) + funcIndex(4) + count(4) + 2*operands(8) = 20
        #expect(header.length == 20)
        // result local
        #expect(readOperand(bc.bytecode, at: 4).value == 2)
        // func index: user func 0 (high bit clear)
        let funcIdx = readLE32(bc.bytecode, at: 8)
        #expect(funcIdx == 0)
        #expect(funcIdx & 0x8000_0000 == 0)
        // arg count
        #expect(readLE32(bc.bytecode, at: 12) == 2)
    }

    @Test func testConvertCallBuiltin() throws {
        let bc = try convert(
            stmt: .callStmt(
                IR.CallStatement(
                    callFunc: "data.test.builtin",
                    args: [IR.Operand(type: .local, value: .localIndex(3))],
                    result: 5
                )))
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .call)
        // result(4) + funcIndex(4) + count(4) + 1 operand(4) = 16
        #expect(header.length == 16)
        // result
        #expect(readOperand(bc.bytecode, at: 4).value == 5)
        // func index: builtin → high bit set, low bits = string table index
        let funcIdx = readLE32(bc.bytecode, at: 8)
        #expect(funcIdx & 0x8000_0000 != 0)
        // The builtin name should be in the string table
        let nameIdx = Int(funcIdx & 0x7FFF_FFFF)
        #expect(bc.strings[nameIdx] == "data.test.builtin")
    }

    @Test func testConvertCallDynamic() throws {
        let bc = try convert(
            stmt: .callDynamicStmt(
                IR.CallDynamicStatement(
                    path: [
                        IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                        IR.Operand(type: .stringIndex, value: .stringIndex(1)),
                    ],
                    args: [Local(3), Local(4)],
                    result: 5
                )),
            staticStrings: ["data", "foo"]
        )
        let header = try InstructionHeader.decode(readLE32(bc.bytecode, at: 0))
        #expect(header.opcode == .callDynamic)
        // result(4) + pathCount(4) + 2 path ops(8) + argsCount(4) + 2 arg locals(8) = 28
        #expect(header.length == 28)
        #expect(readOperand(bc.bytecode, at: 4).value == 5)  // result
        #expect(readLE32(bc.bytecode, at: 8) == 2)  // path count
        let p0 = readOperand(bc.bytecode, at: 12)
        #expect(p0.type == .stringIndex)
        #expect(p0.value == 0)
        let p1 = readOperand(bc.bytecode, at: 16)
        #expect(p1.type == .stringIndex)
        #expect(p1.value == 1)
        #expect(readLE32(bc.bytecode, at: 20) == 2)  // args count
        #expect(readOperand(bc.bytecode, at: 24).value == 3)  // arg0
        #expect(readOperand(bc.bytecode, at: 28).value == 4)  // arg1
    }

    // MARK: - Function Conversion Tests

    @Test func testConvertFunction() throws {
        let policy = IR.Policy(
            staticData: nil,
            plans: IR.Plans(plans: [
                IR.Plan(name: "test", blocks: [IR.Block(statements: [])])
            ]),
            funcs: IR.Funcs(funcs: [
                IR.Func(
                    name: "g0.policy",
                    path: ["g0", "policy"],
                    params: [Local(0), Local(1)],
                    returnVar: Local(2),
                    blocks: [
                        IR.Block(statements: [
                            .resultSetAddStmt(IR.ResultSetAddStatement(value: 2))
                        ])
                    ]
                )
            ])
        )
        let bc = try Converter.convert(policy)

        #expect(bc.functions.count == 1)
        let fn = bc.functions[0]
        #expect(fn.name == "g0.policy")
        #expect(fn.params == [Local(0), Local(1)])
        #expect(fn.returnVar == Local(2))
        #expect(fn.blocks.count == 1)
        #expect(fn.blocks[0].size > 0)

        // Verify the block contains resultSetAdd1 with value=2
        let innerHeader = try InstructionHeader.decode(readLE32(bc.bytecode, at: fn.blocks[0].offset))
        #expect(innerHeader.opcode == .resultSetAdd1)
        #expect(innerHeader.length == 2)
    }

    // MARK: - Number Table Tests

    @Test func testNumberTableParsesNumericStrings() throws {
        var policy = IR.Policy(
            staticData: IR.Static(strings: [
                IR.ConstString(value: "42"),
                IR.ConstString(value: "3.14"),
                IR.ConstString(value: "not-a-number"),
            ]),
            plans: IR.Plans(plans: [IR.Plan(name: "test", blocks: [IR.Block(statements: [])])]),
            funcs: nil
        )
        // Mark indices 0 and 1 as numeric; index 2 is not
        policy.staticStringNumbers = [0, 1]
        let bc = try Converter.convert(policy)

        #expect(bc.numbers.count == 3)
        #expect(bc.numbers[0] != nil)  // "42" parsed
        #expect(bc.numbers[1] != nil)  // "3.14" parsed
        #expect(bc.numbers[2] == nil)  // not in staticStringNumbers → nil
    }

    @Test func testNumberTableUnparseable() throws {
        var policy = IR.Policy(
            staticData: IR.Static(strings: [
                IR.ConstString(value: "definitely-not-a-number")
            ]),
            plans: IR.Plans(plans: [IR.Plan(name: "test", blocks: [IR.Block(statements: [])])]),
            funcs: nil
        )
        policy.staticStringNumbers = [0]  // marked as numeric but won't parse
        let bc = try Converter.convert(policy)

        #expect(bc.numbers.count == 1)
        #expect(bc.numbers[0] == nil)
    }

    @Test func testNumberTableEmptyWhenNoStaticStrings() throws {
        let bc = try Converter.convert(
            IR.Policy(
                staticData: nil,
                plans: IR.Plans(plans: [IR.Plan(name: "test", blocks: [IR.Block(statements: [])])]),
                funcs: nil
            ))
        #expect(bc.numbers.isEmpty)
    }

    // MARK: - Plan / Multi-Statement Tests

    @Test func testConvertMultipleStatements() throws {
        let policy = IR.Policy(
            staticData: nil,
            plans: IR.Plans(plans: [
                IR.Plan(
                    name: "test",
                    blocks: [
                        IR.Block(statements: [
                            .makeNullStmt(IR.MakeNullStatement(target: 0)),
                            .makeSetStmt(IR.MakeSetStatement(target: 1)),
                            .makeObjectStmt(IR.MakeObjectStatement(target: 2)),
                        ])
                    ])
            ]),
            funcs: nil
        )

        let bytecode = try Converter.convert(policy)
        let bytes = bytecode.bytecode

        var pc = 0
        let header1 = try InstructionHeader.decode(readLE32(bytes, at: pc))
        #expect(header1.opcode == Opcode.makeNull)
        pc += 4 + Int(header1.length)

        let header2 = try InstructionHeader.decode(readLE32(bytes, at: pc))
        #expect(header2.opcode == Opcode.makeSet)
        pc += 4 + Int(header2.length)

        let header3 = try InstructionHeader.decode(readLE32(bytes, at: pc))
        #expect(header3.opcode == Opcode.makeObject)
    }

    @Test func testConvertPlan() throws {
        let policy = IR.Policy(
            staticData: nil,
            plans: IR.Plans(plans: [
                IR.Plan(
                    name: "my_plan",
                    blocks: [
                        IR.Block(statements: [
                            .makeNullStmt(IR.MakeNullStatement(target: 0))
                        ])
                    ])
            ]),
            funcs: nil
        )

        let bytecode = try Converter.convert(policy)

        #expect(bytecode.plans.count == 1)
        #expect(bytecode.plans[0].name == "my_plan")
        #expect(bytecode.plans[0].maxLocal == 0)
        #expect(bytecode.plans[0].bytecodeOffset == 0)
        #expect(bytecode.plans[0].bytecodeSize > 0)
    }

    @Test func testStringTableFromStaticData() throws {
        let policy = IR.Policy(
            staticData: IR.Static(
                strings: [
                    IR.ConstString(value: "foo"),
                    IR.ConstString(value: "bar"),
                    IR.ConstString(value: "baz"),
                ],
                builtinFuncs: nil,
                files: nil
            ),
            plans: nil,
            funcs: nil
        )

        let bytecode = try Converter.convert(policy)

        #expect(bytecode.strings.count == 3)
        #expect(bytecode.strings[0] == "foo")
        #expect(bytecode.strings[1] == "bar")
        #expect(bytecode.strings[2] == "baz")
    }

    @Test func testConvertFullPolicy() throws {
        let policy = IR.Policy(
            staticData: IR.Static(
                strings: [IR.ConstString(value: "test")],
                builtinFuncs: nil,
                files: nil
            ),
            plans: IR.Plans(plans: [
                IR.Plan(
                    name: "plan1",
                    blocks: [
                        IR.Block(statements: [
                            .makeNullStmt(IR.MakeNullStatement(target: 0)),
                            .makeSetStmt(IR.MakeSetStatement(target: 1)),
                        ])
                    ]),
                IR.Plan(
                    name: "plan2",
                    blocks: [
                        IR.Block(statements: [
                            .makeObjectStmt(IR.MakeObjectStatement(target: 0))
                        ])
                    ]),
            ]),
            funcs: nil
        )

        let bytecode = try Converter.convert(policy)

        #expect(bytecode.plans.count == 2)
        #expect(bytecode.plans[0].name == "plan1")
        #expect(bytecode.plans[1].name == "plan2")
        #expect(bytecode.strings.count == 1)
        #expect(bytecode.strings[0] == "test")
        #expect(!bytecode.bytecode.isEmpty)
    }
}
