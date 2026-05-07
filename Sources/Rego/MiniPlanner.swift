import AST
import Foundation
import IR

/// MiniPlanner generates a single-plan ``IR/Policy`` that performs a direct
/// lookup against the data tree for the given query path, wrapping the value
/// (when present) as `{"result": <value>}` in the result set.
///
/// The generated plan uses chained ``IR/DotStatement``s, to perform the data
/// document `data.x.y.z`-style lookups.
internal enum MiniPlanner {
    /// Returns an ``IR/Policy`` containing a single plan that performs a
    /// direct data-tree lookup for `query`.
    static func generate(query: String) throws -> IR.Policy {
        let entrypoint = try queryToEntryPoint(query)

        // Plan name follows the existing entrypoint convention: bare `data`
        // stays as `"data"`, otherwise segments are slash-joined.
        let segments: [String] =
            entrypoint == "data"
            ? []
            : entrypoint.split(separator: "/").map(String.init)

        // Static strings layout:
        //   index 0           -> "result" (key for the wrapper object)
        //   indices 1..<count -> path segments, in order
        var strings: [IR.ConstString] = [IR.ConstString(value: "result")]
        for s in segments {
            strings.append(IR.ConstString(value: s))
        }

        // Local register layout (matches existing discovery-style template):
        //   local 0  -> input  (reserved by VM)
        //   local 1  -> data   (reserved by VM)
        //   local 2  -> walked target (final value to wrap)
        //   local 3  -> alias of local 2
        //   local 4  -> wrapper object {"result": local 3}
        //   local 5+ -> intermediate Dot walks (5=data, 6=data.s1, 7=data.s1.s2, ...)
        var stmts: [IR.Statement] = []

        if segments.isEmpty {
            // Bare `data` query: the data root is the answer, no walking.
            stmts.append(
                .assignVarOnceStmt(
                    IR.AssignVarOnceStatement(
                        source: IR.Operand(type: .local, value: .localIndex(1)),
                        target: 2
                    )
                )
            )
        } else {
            stmts.append(
                .assignVarOnceStmt(
                    IR.AssignVarOnceStatement(
                        source: IR.Operand(type: .local, value: .localIndex(1)),
                        target: 5
                    )
                )
            )
            var src: Int = 5
            var dst: Int = 6
            for (i, _) in segments.enumerated() {
                // strings[0] is "result"; segment strings begin at index 1.
                let keyIdx = i + 1
                stmts.append(
                    .dotStmt(
                        IR.DotStatement(
                            source: IR.Operand(type: .local, value: .localIndex(src)),
                            key: IR.Operand(type: .stringIndex, value: .stringIndex(keyIdx)),
                            target: AST.Local(dst)
                        )
                    )
                )
                src = dst
                dst += 1
            }
            // Move the walked value into local 2.
            stmts.append(
                .assignVarOnceStmt(
                    IR.AssignVarOnceStatement(
                        source: IR.Operand(type: .local, value: .localIndex(src)),
                        target: 2
                    )
                )
            )
        }

        // Wrap as {"result": <value>} and emit one result-set entry.
        stmts.append(
            .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: 3
                )
            )
        )
        stmts.append(.makeObjectStmt(IR.MakeObjectStatement(target: 4)))
        stmts.append(
            .objectInsertStmt(
                IR.ObjectInsertStatement(
                    key: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: 4
                )
            )
        )
        stmts.append(.resultSetAddStmt(IR.ResultSetAddStatement(value: 4)))

        let block = IR.Block(statements: stmts)
        let plan = IR.Plan(name: entrypoint, blocks: [block])
        return IR.Policy(
            staticData: IR.Static(strings: strings),
            plans: IR.Plans(plans: [plan]),
            funcs: nil
        )
    }
}
