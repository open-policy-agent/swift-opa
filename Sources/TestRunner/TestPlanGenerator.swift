import IR

/// Generates ad-hoc IR plans that invoke a test func and surface its result.
///
/// swift-opa resolves called funcs *per policy*, so a wrapper plan must live in
/// the same ``IR/Policy`` as the func it calls. ``TestRunner`` uses these helpers
/// to integrate wrapper plans into a copy of the policy that already holds the
/// test funcs.
public enum TestPlanGenerator {
    /// The object key in the result set that stores the test's return value.
    /// Mirrors OPA's own plan wrapper, of the form: `{"result": <value>}`
    public static let resultKey = "result"

    // Reserved implicit locals present in every plan/func frame.
    private static let inputLocal: Local = 0
    private static let dataLocal: Local = 1
    // Locals introduced by the wrapper itself.
    private static let callResultLocal: Local = 2
    private static let objectLocal: Local = 3

    /// Builds the wrapper plan for a runnable test.
    ///
    /// The plan calls `funcName` with the implicit `input` and `data` arguments,
    /// wraps its return value in `{"result": <value>}`, and adds that object to
    /// the result set. When the test func is undefined (such as when the test failed),
    /// the call result local stays undefined and the `ObjectInsert`/`ResultSetAdd`
    /// statements are skipped, leaving an empty result set.
    ///
    /// - Parameters:
    ///   - planName: The IR plan name, e.g. `authz_test/test_post_allowed`.
    ///   - funcName: The IR func name to invoke, e.g. `g0.data.authz_test.test_post_allowed`.
    ///   - resultStringIndex: Index of the `"result"` string in the policy's static string table.
    public static func makeWrapperPlan(
        planName: String,
        funcName: String,
        resultStringIndex: Int
    ) -> IR.Plan {
        let statements: [IR.Statement] = [
            .callStmt(
                IR.CallStatement(
                    callFunc: funcName,
                    args: [
                        IR.Operand(type: .local, value: .localIndex(Int(inputLocal))),
                        IR.Operand(type: .local, value: .localIndex(Int(dataLocal))),
                    ],
                    result: callResultLocal
                )
            ),
            .makeObjectStmt(IR.MakeObjectStatement(target: objectLocal)),
            .objectInsertStmt(
                IR.ObjectInsertStatement(
                    key: IR.Operand(type: .stringIndex, value: .stringIndex(resultStringIndex)),
                    value: IR.Operand(type: .local, value: .localIndex(Int(callResultLocal))),
                    object: objectLocal
                )
            ),
            .resultSetAddStmt(IR.ResultSetAddStatement(value: objectLocal)),
        ]
        return IR.Plan(name: planName, blocks: [IR.Block(statements: statements)])
    }
}
