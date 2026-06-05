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

        // exponent >= 0 means the value is already a whole number; bridge directly.
        // For exponent < 0, check integrality before the range guard — non-integer
        // decimals return nil without paying the two NSDecimalCompare calls in
        // `self >= int64Min && self <= int64Max`.
        if exponent < 0 {
            #if canImport(ObjectiveC)
                // On Apple platforms, NSDecimalCompact strips trailing zeros from the
                // significand. If the exponent is still negative after compaction the value
                // is genuinely fractional — return nil without allocating NSNumber.
                // NSDecimalCompact is documented as normalising a decimal "so that
                // calculations using it will take up as little memory as possible" and is a
                // prerequisite for all NSDecimal arithmetic functions.
                //
                // Examples (significand × 10^exponent):
                //   100   = 1    × 10^ 2  → exponent already > 0, bridge directly
                //   10    = 10   × 10^ 0  → exponent already 0, bridge directly
                //   10.0  = 100  × 10^-1  → compact → 1 × 10^1   (exponent >= 0 → integer)
                //   10.23 = 1023 × 10^-2  → compact → 1023 × 10^-2  (no trailing zeros → nil)
                //   10.20 = 1020 × 10^-2  → compact → 102  × 10^-1  (exponent < 0 → nil)
                var copy = self
                NSDecimalCompact(&copy)
                guard copy.exponent >= 0 else { return nil }
                guard copy >= Self.int64Min && copy <= Self.int64Max else { return nil }
                return Int64(truncating: copy as NSNumber)
            #else
                // On non-Apple platforms fall back to the truncation+equality check which
                // is correct regardless of internal representation.
                let intValue = Int64(truncating: self as NSNumber)
                guard Decimal(intValue) == self else { return nil }
                return intValue
            #endif
        }

        guard self >= Self.int64Min && self <= Self.int64Max else { return nil }
        return Int64(truncating: self as NSNumber)
    }
}
