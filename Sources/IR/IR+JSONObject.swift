import AST
import Foundation

// Custom decoding from Darwin JSONSerialization output (see JSONObject). Must match the Decodable
// conformances, which `JSONObjectIRTests` checks against JSONDecoder.

#if canImport(Darwin)

    extension JSONObject {
        fileprivate func local(_ key: String) throws -> Local { try integer(key) }
        fileprivate func operand(_ key: String) throws -> Operand { try decode(key, Operand.init(json:)) }
        fileprivate func block(_ key: String) throws -> Block { try decode(key, Block.init(json:)) }
        fileprivate func blocks(_ key: String) throws -> [Block]? { try arrayIfPresent(key, Block.init(json:)) }
    }

    @inline(__always)
    private func with<T>(_ value: T, _ update: (inout T) throws -> Void) rethrows -> T {
        var value = value
        try update(&value)
        return value
    }

    extension Policy {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(
                staticData: try o.decodeIfPresent("static", Static.init(json:)),
                plans: try o.decodeIfPresent("plans", Plans.init(json:)),
                funcs: try o.decodeIfPresent("funcs", Funcs.init(json:)))
        }
    }

    extension Static {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(
                strings: try o.arrayIfPresent("strings", ConstString.init(json:)),
                builtinFuncs: try o.arrayIfPresent("builtin_funcs", BuiltinFunc.init(json:)),
                files: try o.arrayIfPresent("files", ConstString.init(json:)))
        }
    }

    extension ConstString {
        init(json: JSONValue) throws {
            self.init(value: try JSONObject(json).string("value"))
        }
    }

    extension BuiltinFunc {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(name: try o.string("name"), decl: try o.decode("decl", FunctionTypeDecl.init(json:)))
        }
    }

    extension Plans {
        init(json: JSONValue) throws {
            self.init(plans: try JSONObject(json).array("plans", Plan.init(json:)))
        }
    }

    extension Plan {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(name: try o.string("name"), blocks: try o.array("blocks", Block.init(json:)))
        }
    }

    extension Funcs {
        init(json: JSONValue) throws {
            let funcs = try JSONObject(json).arrayIfPresent("funcs", Func.init(json:))
            self = with(Funcs(funcs: [])) { $0.funcs = funcs }
        }
    }

    extension Func {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(
                name: try o.string("name"),
                path: try o.array("path", JSONConvert.string),
                params: try o.array("params", JSONConvert.integer),
                returnVar: try o.local("return"),
                blocks: try o.array("blocks", Block.init(json:)))
        }
    }

    extension Block {
        init(json: JSONValue) throws {
            self.init(statements: try JSONObject(json).array("stmts", Statement.init(json:)))
        }
    }

    extension Operand {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            let type: OpType = try o.rawValue("type")
            switch type {
            case .local: self.init(type: type, value: .localIndex(try o.integer("value")))
            case .bool: self.init(type: type, value: .bool(try o.bool("value")))
            case .stringIndex: self.init(type: type, value: .stringIndex(try o.integer("value")))
            }
        }
    }

    extension Statement {
        // Each element of a block's `stmts` is `{"type": "<name>", "stmt": {<fields>, "row", "col", "file"}}`.
        init(json: JSONValue) throws {
            let wrapper = try JSONObject(json)
            let type: PartialStatement.KnownStatements = try wrapper.rawValue("type")
            self = try wrapper.decode("stmt") { try Statement(type: type, stmt: JSONObject($0)) }
        }

        private init(type: PartialStatement.KnownStatements, stmt s: JSONObject) throws {
            let loc = Location(row: try s.integer("row"), col: try s.integer("col"), file: try s.integer("file"))
            switch type {
            case .arrayAppendStmt:
                self = .arrayAppendStmt(
                    .init(location: loc, array: try s.local("array"), value: try s.operand("value")))
            case .assignIntStmt:
                self = .assignIntStmt(
                    .init(location: loc, value: try s.integer("value"), target: try s.local("target")))
            case .assignVarOnceStmt:
                self = .assignVarOnceStmt(
                    .init(location: loc, source: try s.operand("source"), target: try s.local("target")))
            case .assignVarStmt:
                self = .assignVarStmt(
                    .init(location: loc, source: try s.operand("source"), target: try s.local("target")))
            case .blockStmt:
                let blocks = try s.blocks("blocks")
                self = .blockStmt(
                    with(.init(blocks: [])) {
                        $0.location = loc
                        $0.blocks = blocks
                    })
            case .breakStmt:
                self = .breakStmt(with(.init(index: try s.integer("index"))) { $0.location = loc })
            case .callDynamicStmt:
                self = .callDynamicStmt(
                    .init(
                        location: loc, path: try s.array("path", Operand.init(json:)),
                        args: try s.array("args", JSONConvert.integer), result: try s.local("result")))
            case .callStmt:
                let args = try s.arrayIfPresent("args", Operand.init(json:))
                self = .callStmt(
                    with(.init(location: loc, callFunc: try s.string("func"), result: try s.local("result"))) {
                        $0.args = args
                    })
            case .dotStmt:
                self = .dotStmt(
                    with(
                        .init(source: try s.operand("source"), key: try s.operand("key"), target: try s.local("target"))
                    ) {
                        $0.location = loc
                    })
            case .equalStmt:
                self = .equalStmt(with(.init(a: try s.operand("a"), b: try s.operand("b"))) { $0.location = loc })
            case .isArrayStmt:
                self = .isArrayStmt(.init(location: loc, source: try s.operand("source")))
            case .isDefinedStmt:
                self = .isDefinedStmt(.init(location: loc, source: try s.local("source")))
            case .isObjectStmt:
                self = .isObjectStmt(.init(location: loc, source: try s.operand("source")))
            case .isSetStmt:
                self = .isSetStmt(.init(location: loc, source: try s.operand("source")))
            case .isUndefinedStmt:
                self = .isUndefinedStmt(with(.init(source: try s.local("source"))) { $0.location = loc })
            case .lenStmt:
                self = .lenStmt(
                    with(.init(source: try s.operand("source"), target: try s.local("target"))) { $0.location = loc })
            case .makeArrayStmt:
                self = .makeArrayStmt(
                    .init(location: loc, capacity: try s.integer("capacity"), target: try s.local("target")))
            case .makeNullStmt:
                self = .makeNullStmt(.init(location: loc, target: try s.local("target")))
            case .makeNumberIntStmt:
                self = .makeNumberIntStmt(
                    .init(location: loc, value: try s.integer("value"), target: try s.local("target")))
            case .makeNumberRefStmt:
                self = .makeNumberRefStmt(
                    .init(location: loc, index: try s.integer("Index"), target: try s.local("target")))
            case .makeObjectStmt:
                self = .makeObjectStmt(.init(location: loc, target: try s.local("target")))
            case .makeSetStmt:
                self = .makeSetStmt(.init(location: loc, target: try s.local("target")))
            case .nopStmt:
                self = .nopStmt(with(.init()) { $0.location = loc })
            case .notEqualStmt:
                self = .notEqualStmt(with(.init(a: try s.operand("a"), b: try s.operand("b"))) { $0.location = loc })
            case .notStmt:
                self = .notStmt(.init(location: loc, block: try s.block("block")))
            case .objectInsertOnceStmt:
                self = .objectInsertOnceStmt(
                    with(.init(key: try s.operand("key"), value: try s.operand("value"), object: try s.local("object")))
                    {
                        $0.location = loc
                    })
            case .objectInsertStmt:
                self = .objectInsertStmt(
                    .init(
                        location: loc, key: try s.operand("key"), value: try s.operand("value"),
                        object: try s.local("object")))
            case .objectMergeStmt:
                self = .objectMergeStmt(
                    .init(location: loc, a: try s.local("a"), b: try s.local("b"), target: try s.local("target")))
            case .resetLocalStmt:
                self = .resetLocalStmt(.init(location: loc, target: try s.local("target")))
            case .resultSetAddStmt:
                self = .resultSetAddStmt(with(.init(value: try s.local("value"))) { $0.location = loc })
            case .returnLocalStmt:
                self = .returnLocalStmt(.init(location: loc, source: try s.local("source")))
            case .scanStmt:
                self = .scanStmt(
                    with(
                        .init(
                            source: try s.local("source"), key: try s.local("key"), value: try s.local("value"),
                            block: try s.block("block"))
                    ) { $0.location = loc })
            case .setAddStmt:
                self = .setAddStmt(.init(location: loc, value: try s.operand("value"), set: try s.local("set")))
            case .withStmt:
                self = .withStmt(
                    .init(
                        location: loc, local: try s.local("local"),
                        path: try s.arrayIfPresent("path", JSONConvert.integer),
                        value: try s.operand("value"), block: try s.block("block")))
            }
        }
    }

    extension Capabilities {
        init(json: JSONValue) throws {
            let o = try JSONObject(json)
            self.init(
                builtins: try o.array("builtins", BuiltinFunc.init(json:)),
                allowNet: try o.arrayIfPresent("allow_net", JSONConvert.string),
                features: try o.arrayIfPresent("features", JSONConvert.string),
                futureKeywords: try o.arrayIfPresent("future_keywords", JSONConvert.string),
                wasmABIVersions: try o.arrayIfPresent("wasm_abi_versions") { v in
                    let v = try JSONObject(v)
                    return WasmABIVersion(
                        version: try v.integer("version"), minorVersion: try v.integer("minor_version"))
                })
        }
    }

#endif
