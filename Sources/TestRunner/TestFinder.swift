import IR

/// Finds Rego test cases within a compiled IR policy.
///
/// When OPA compiles a bundle to an IR plan, every reachable rule becomes a
/// `func` even when it is not exposed as a runnable `plan`. Test rules therefore
/// live in `policy.funcs` and can be fished out by inspecting func names.
public enum TestFinder {
    /// The `data.` prefix OPA uses for the query name of a rule.
    private static let queryPrefix = "data"

    /// Returns the test cases defined by `policy`, in the order the funcs appear.
    ///
    /// A func is considered a test when:
    /// - It is a top-level rule (its path is `["g0", <package...>, <rule>]`).
    /// - Args are only the implicit `input` and `data` parameters.
    /// - Its rule name begins with `test_` (runnable) or `todo_test_` (skipped).
    public static func findTests(in policy: IR.Policy) -> [TestCase] {
        guard let funcs = policy.funcs?.funcs else {
            return []
        }

        let files = policy.staticData?.files ?? []

        var tests: [TestCase] = []
        for f in funcs {
            // Test rules only use the implicit (input, data) params.
            guard f.params == [0, 1] else {
                continue
            }
            // Path looks like ["g0", "<pkg...>", "<rule>"]. We need at least the
            // group tag plus a rule name.
            guard f.path.count >= 2, let rule = f.path.last else {
                continue
            }

            let skipped: Bool
            if rule.hasPrefix("todo_test_") {
                skipped = true
            } else if rule.hasPrefix("test_") {
                skipped = false
            } else {
                continue  // Not a test rule? Skip to next func.
            }

            // Drop the leading group tag (e.g. "g0").
            // The rest is the package path + rule name.
            let pathComponents = Array(f.path.dropFirst())
            let planName = pathComponents.joined(separator: "/")
            let name = "\(queryPrefix).\(pathComponents.joined(separator: "."))"

            let location = f.blocks.first?.statements.first?.location
            let file = location.flatMap { loc -> String? in
                guard loc.file >= 0, loc.file < files.count else { return nil }
                return files[loc.file].value
            }
            let row = location.flatMap { $0.row > 0 ? $0.row : nil }

            tests.append(
                TestCase(
                    name: name,
                    planName: planName,
                    funcName: f.name,
                    skipped: skipped,
                    file: file,
                    row: row
                )
            )
        }
        return tests
    }
}
