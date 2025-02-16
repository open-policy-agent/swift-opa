import Foundation

// This makes MeasureReport "formattable"
extension MeasureReport {
    public func formatted<S>(_ v: S) -> S.FormatOutput where S: FormatStyle, S.FormatInput == MeasureReport {
        return v.format(self)
    }
}

// This magic makes our factory available in "." format from MeasureReport.formatted, which is defined as:
// public func formatted<S>(_ v: S) -> S.FormatOutput where S : FormatStyle, S.FormatInput == MeasureReport
extension FormatStyle where Self == GobenchStyle {
    static var gobench: Self {
        return GobenchStyle()
    }
}

struct GobenchStyle: FormatStyle, Sendable {
    typealias FormatInput = MeasureReport
    typealias FormatOutput = String

    // <name> <iterations> <value> <unit> [<value> <unit>...]
    // https://go.googlesource.com/proposal/+/master/design/14313-benchmark-format.md
    func format(_ report: MeasureReport) -> String {
        let v = report.elapsedPerOperation

        // Figure out which units are closest
        var value: String = ""
        var unit: String = ""
        if v.components.seconds >= 1 {
            value = v.seconds.formatted(.number.precision(.fractionLength(0...4)))
            unit = "s/op"
        } else if 1..<1000 ~= v.milliseconds {
            value = v.milliseconds.formatted(.number.precision(.fractionLength(0...4)))
            unit = "ms/op"
        } else if 1..<1000 ~= v.microseconds {
            value = v.microseconds.formatted(.number.precision(.fractionLength(0...4)))
            unit = "μs/op"
        } else if 1..<1000 ~= v.nanoseconds {
            value = v.nanoseconds.formatted(.number.precision(.fractionLength(0...4)))
            unit = "ns/op"
        } else {
            value = v.components.attoseconds.formatted(.number.precision(.fractionLength(0...4)))
            unit = "as/op"
        }
        return "Benchmark\t\(report.iterations)\t\(value) \(unit)"
    }
}
