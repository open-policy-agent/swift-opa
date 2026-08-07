import Foundation
import TestRunner

/// Formats ``TestResult`` collections in a style close to `opa test`'s pretty output.
///
/// Output lists only non-passing tests (failures, errors, skips) by default,
/// followed by a summary. Verbose output lists every test.
///
/// We do not support printing failure traces, so the FAILURES section is omitted.
struct TestReporter {
    let verbose: Bool

    private static let separator = String(repeating: "-", count: 80)

    /// Renders the report body (per-test lines + separator + summary).
    func render(_ results: [TestResult]) -> String {
        var lines: [String] = []

        for result in results {
            guard verbose || result.outcome != .passed else {
                continue
            }
            if let file = result.testCase.file, let row = result.testCase.row {
                lines.append("\(file):\(row):")
            }
            lines.append(statusLine(result))
        }

        lines.append(Self.separator)
        lines.append(contentsOf: summary(results))
        return lines.joined(separator: "\n")
    }

    private func statusLine(_ result: TestResult) -> String {
        let duration = result.duration.formatted(.adaptive)
        switch result.outcome {
        case .passed:
            return "\(result.testCase.name): PASS (\(duration))"
        case .failed:
            return "\(result.testCase.name): FAIL (\(duration))"
        case .skipped:
            return "\(result.testCase.name): SKIPPED"
        case .errored(let message):
            return "\(result.testCase.name): ERROR (\(duration))\n  \(message)"
        }
    }

    private func summary(_ results: [TestResult]) -> [String] {
        let total = results.count
        let passed = results.count(where: { $0.outcome == .passed })
        let failed = results.count(where: { $0.outcome == .failed })
        let skipped = results.count(where: { $0.outcome == .skipped })
        let errored = results.count(where: {
            guard case .errored = $0.outcome else { return false }
            return true
        })

        var lines = ["PASS: \(passed)/\(total)"]
        if failed > 0 { lines.append("FAIL: \(failed)/\(total)") }
        if errored > 0 { lines.append("ERROR: \(errored)/\(total)") }
        if skipped > 0 { lines.append("SKIPPED: \(skipped)/\(total)") }
        return lines
    }
}
