import Foundation

extension RegoNumber: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = RegoNumber(int: value)
    }
}

extension RegoNumber: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        if value.isNaN || value.isInfinite {
            self = RegoNumber(decimal: Decimal.nan)
        } else {
            self = RegoNumber(decimal: value.preciseDecimalValue)
        }
    }
}
