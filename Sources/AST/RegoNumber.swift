import Foundation

/// RegoNumber represents numeric values in Rego using native Swift types.
/// The enum case itself indicates float type: .int = integer type, .decimal = float type
public enum RegoNumber: Sendable, Hashable {
    case int(Int64)       // Integer values (isFloatType: false)
    case decimal(Decimal) // High-precision decimal values (isFloatType: true)

    // MARK: - Custom Equality
    public static func == (lhs: RegoNumber, rhs: RegoNumber) -> Bool {
        switch (lhs, rhs) {
        case (.int(let lVal), .int(let rVal)):
            return lVal == rVal
        case (.decimal(let lVal), .decimal(let rVal)):
            return lVal == rVal
        case (.decimal(let decimalVal), .int(let intVal)):
            return decimalVal == Decimal(intVal)
        case (.int(let intVal), .decimal(let decimalVal)):
            return Decimal(intVal) == decimalVal
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .int(let intVal):
            hasher.combine(Decimal(intVal))
        case .decimal(let decimalVal):
            hasher.combine(decimalVal)
        }
    }

    // MARK: - Essential Properties

    /// Convert to Double for arithmetic operations
    public var doubleValue: Double {
        switch self {
        case .int(let v):
            return Double(v)
        case .decimal(let v):
            return v.doubleValue
        }
    }

    /// Try to get as Int64 if it represents a whole number
    public var int64Value: Int64? {
        switch self {
        case .int(let v):
            return v
        case .decimal(let v):
            return v.safeInt64Value
        }
    }

    private static let uint64MaxDecimal = Decimal(UInt64.max)

    /// Get as UInt64 (clamps negative values to 0, clamps large values to UInt64.max)
    public var uint64Value: UInt64 {
        switch self {
        case .int(let v):
            return UInt64(clamping: v)
        case .decimal(let v):
            if v.isNaN || v < 0 {
                return 0
            }
            if v > Self.uint64MaxDecimal {
                return UInt64.max
            }

            return v.uint64Value
        }
    }

    /// Get as Int (may overflow for large Int64 values)
    public var intValue: Int {
        switch self {
        case .int(let v):
            return Int(clamping: v)
        case .decimal(let v):
            let doubleValue = v.doubleValue
            if let safeInt64 = doubleValue.toInt64Safe() {
                return Int(clamping: safeInt64)
            }
            if doubleValue.isNaN {
                return 0
            }
            if doubleValue >= Double(Int.max) {
                return Int.max
            }
            if doubleValue <= Double(Int.min) {
                return Int.min
            }
            return Int(doubleValue)
        }
    }

    /// Get the decimal value
    public var decimalValue: Decimal {
        switch self {
        case .int(let v):
            // Optimize for common small integer values to avoid repeated Decimal creation
            if v >= 0 && v <= 1000 {
                return Self.cachedDecimals[Int(v)]
            }
            return Decimal(v)
        case .decimal(let v):
            return v
        }
    }

    private static let cachedDecimals: [Decimal] = {
        return (0...1000).map { Decimal($0) }
    }()

    /// Returns true for decimal (floating-point) values, false for integer values
    public var isFloatType: Bool {
        switch self {
        case .int(_):
            return false
        case .decimal(_):
            return true
        }
    }

}

// MARK: - CustomStringConvertible & CustomDebugStringConvertible

extension RegoNumber: CustomStringConvertible, CustomDebugStringConvertible {
    /// String representation
    public var description: String {
        switch self {
        case .int(let v):
            return "\(v)"
        case .decimal(let v):
            return "\(v)"
        }
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Arithmetic Operations (for completeness)

extension RegoNumber {
    public static func + (lhs: RegoNumber, rhs: RegoNumber) -> RegoNumber {
        switch (lhs, rhs) {
        case (.int(let lVal), .int(let rVal)):
            let (result, overflow) = lVal.addingReportingOverflow(rVal)
            if !overflow {
                return RegoNumber.int(result)
            }
            return RegoNumber(Decimal(lVal) + Decimal(rVal))
        default:
            return RegoNumber(lhs.decimalValue + rhs.decimalValue)
        }
    }

    public static func - (lhs: RegoNumber, rhs: RegoNumber) -> RegoNumber {
        switch (lhs, rhs) {
        case (.int(let lVal), .int(let rVal)):
            let (result, overflow) = lVal.subtractingReportingOverflow(rVal)
            if !overflow {
                return RegoNumber.int(result)
            }
            return RegoNumber(Decimal(lVal) - Decimal(rVal))
        default:
            return RegoNumber(lhs.decimalValue - rhs.decimalValue)
        }
    }

    public static func * (lhs: RegoNumber, rhs: RegoNumber) -> RegoNumber {
        switch (lhs, rhs) {
        case (.int(let lVal), .int(let rVal)):
            let (result, overflow) = lVal.multipliedReportingOverflow(by: rVal)
            if !overflow {
                return RegoNumber.int(result)
            }
            return RegoNumber(Decimal(lVal) * Decimal(rVal))
        default:
            return RegoNumber(lhs.decimalValue * rhs.decimalValue)
        }
    }

    public static func / (lhs: RegoNumber, rhs: RegoNumber) -> RegoNumber {
        switch (lhs, rhs) {
        case (.int(let lVal), .int(let rVal)):
            guard rVal != 0 else {
                return RegoNumber(lhs.decimalValue / rhs.decimalValue)
            }

            if lVal % rVal == 0 {
                let (result, overflow) = lVal.dividedReportingOverflow(by: rVal)
                if !overflow {
                    return RegoNumber.int(result)
                }
            }

            fallthrough
        default:
            return RegoNumber(lhs.decimalValue / rhs.decimalValue)
        }
    }
}

// MARK: - Centralized Utility Extensions

extension Double {
    /// Safely convert Double to Int64 with overflow and precision checks
    func toInt64Safe() -> Int64? {
        // Handle special cases
        guard !self.isNaN && !self.isInfinite else {
            return nil
        }

        // Check if it's a whole number (no fractional part)
        guard self.truncatingRemainder(dividingBy: 1) == 0 else {
            return nil
        }

        // Use explicit bounds rather than Double conversion which may lose precision
        guard self >= -9_223_372_036_854_775_808.0 && self <= 9_223_372_036_854_775_807.0 else {
            return nil
        }

        // Use exactly conversion for safety
        return Int64(exactly: self)
    }
}

extension RegoNumber {
    /// Initializer for integer types
    public init<T: BinaryInteger>(value: T) {
        if let int64Value = Int64(exactly: value) {
            self = .int(int64Value)
        } else if let uint64Value = value as? UInt64 {
            self = .decimal(Decimal(uint64Value))
        } else {
            fatalError("Unsupported BinaryInteger type: \(T.self) with value: \(value)")
        }
    }

    /// Convenience initializer for floating-point types
    public init<T: BinaryFloatingPoint>(value: T) {
        let doubleValue = Double(value)

        guard !doubleValue.isNaN && !doubleValue.isInfinite else {
            self = .decimal(Decimal.nan)
            return
        }

        if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
            if let int64Val = doubleValue.toInt64Safe() {
                self = .int(int64Val)
                return
            }
        }

        self = .decimal(doubleValue.preciseDecimalValue)
    }

    /// Create RegoNumber from Decimal with smart type selection
    public init(_ decimal: Decimal) {
        // Handle special Decimal values
        if decimal.isNaN {
            self = .decimal(Decimal.nan)
            return
        }
        if !decimal.isFinite {
            let infinityDecimal = decimal > 0 ?
                Decimal.greatestFiniteMagnitude :
                -Decimal.greatestFiniteMagnitude
            self = .decimal(infinityDecimal)
            return
        }

        // Check if whole number within Int64 range
        if let int64Value = decimal.safeInt64Value {
            self = .int(int64Value)
            return
        }

        self = .decimal(decimal)
    }

}