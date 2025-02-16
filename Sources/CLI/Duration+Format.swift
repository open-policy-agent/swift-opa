// Duration - This file contains helpers for working with and formatting Durations.
import Foundation

// This magic makes our factory available in "." format from Duration.formatted, which is defined as:
// public func formatted<S>(_ v: S) -> S.FormatOutput where S : FormatStyle, S.FormatInput == Duration
extension FormatStyle where Self == AdaptiveDurationStyle {
    static var adaptive: Self {
        return AdaptiveDurationStyle()
    }
}

struct AdaptiveDurationStyle: FormatStyle, Sendable {
    typealias FormatInput = Duration
    typealias FormatOutput = String

    func format(_ v: Duration) -> String {
        // Figure out which units are closest
        if v.components.seconds >= 1 {
            return "\(v.description)"
        }
        if 1..<1000 ~= v.milliseconds {
            return v.milliseconds.formatted(.number.precision(.fractionLength(0...4))) + "ms"
        }
        if 1..<1000 ~= v.microseconds {
            return v.microseconds.formatted(.number.precision(.fractionLength(0...4))) + "μs"
        }
        if 1..<1000 ~= v.nanoseconds {
            return v.nanoseconds.formatted(.number.precision(.fractionLength(0...4))) + "ns"
        }
        return "\(v.components.attoseconds)as"
    }
}

extension FormatStyle where Self == NanosecondsDurationStyle {
    static var nanoseconds: Self {
        return NanosecondsDurationStyle()
    }
}

struct NanosecondsDurationStyle: FormatStyle, Sendable {
    typealias FormatInput = Duration
    typealias FormatOutput = String

    func format(_ v: Duration) -> String {
        return v.nanoseconds.formatted(.number.precision(.fractionLength(0...4))) + "ns"
    }
}

private let attosecondsPerSecond = Double(1e18)
private let nanosecondsPerSecond = Double(1e9)
private let microsecondsPerSecond = Double(1e6)
private let millisecondsPerSecond = Double(1e3)

private let nanosecondsPerAtto = Double(1e9)
private let microsecondsPerAtto = Double(1e12)
private let millisecondsPerAtto = Double(1e15)

extension Duration {
    var seconds: Double {
        return Double(self.components.attoseconds) / attosecondsPerSecond
    }
    var nanoseconds: Double {
        return Double(self.components.attoseconds) / nanosecondsPerAtto
    }
    var microseconds: Double {
        return Double(self.components.attoseconds) / microsecondsPerAtto
    }
    var milliseconds: Double {
        return Double(self.components.attoseconds) / millisecondsPerSecond
    }
}
