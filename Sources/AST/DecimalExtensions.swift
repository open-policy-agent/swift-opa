import Foundation

extension BinaryFloatingPoint {
    /// Convert a binary floating point value to Decimal with precision preservation.
    /// Uses NSNumber bridge to avoid exposing binary floating-point approximation artifacts.
    public var preciseDecimalValue: Decimal {
        NSNumber(value: Double(self)).decimalValue
    }
}

extension Decimal {
    private static let int64Min = Decimal(Int64.min)
    private static let int64Max = Decimal(Int64.max)
    private static let uint64Max = Decimal(UInt64.max)

    /// Convert Decimal to Double
    public var doubleValue: Double {
        Double(truncating: self as NSNumber)
    }

    /// Convert Decimal to Int64 with clamping
    public var int64Value: Int64 {
        guard self >= Self.int64Min && self <= Self.int64Max else {
            return self > 0 ? Int64.max : Int64.min
        }
        return Int64(truncating: self as NSNumber)
    }

    /// Convert Decimal to UInt64 with clamping
    public var uint64Value: UInt64 {
        guard !self.isNaN else { return 0 }
        guard self >= 0 else { return 0 }
        guard self <= Self.uint64Max else { return UInt64.max }
        return UInt64(truncating: self as NSNumber)
    }

    /// Safely extract Int64 value if Decimal represents a whole number within range
    public var safeInt64Value: Int64? {
        guard !self.isNaN && self.isFinite else { return nil }
        guard self >= Self.int64Min && self <= Self.int64Max else { return nil }

        let intValue = Int64(truncating: self as NSNumber)
        guard Decimal(intValue) == self else { return nil }
        return intValue
    }
}
