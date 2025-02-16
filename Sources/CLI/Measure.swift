import Foundation

struct MeasureReport {
    let iterations: Int
    let elapsed: Duration
    let elapsedPerOperation: Duration
    let result: Any?
}

func measure<T>(iterations: Int = 1000, _ block: () throws -> T) rethrows -> MeasureReport {
    let clock = ContinuousClock()

    var result: T?
    let elapsed = try clock.measure {
        for _ in 0..<iterations {
            result = try block()
        }
    }

    return MeasureReport(
        iterations: iterations,
        elapsed: elapsed,
        elapsedPerOperation: elapsed / Double(iterations),
        result: result
    )
}

func measureAsync<T>(iterations: Int = 1000, _ block: () async throws -> T) async rethrows -> MeasureReport {
    let clock = ContinuousClock()

    var result: T?
    let elapsed = try await clock.measure {
        for _ in 0..<iterations {
            result = try await block()
        }
    }

    return MeasureReport(
        iterations: iterations,
        elapsed: elapsed,
        elapsedPerOperation: elapsed / Double(iterations),
        result: result
    )
}
