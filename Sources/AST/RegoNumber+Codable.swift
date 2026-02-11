import Foundation

extension RegoNumber: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self = RegoNumber(int: Int64(intValue))
            return
        }

        let decimalValue = try container.decode(Decimal.self)
        self = RegoNumber(decimalValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self.storage {
        case .int(let v):
            try container.encode(v)
        case .decimal(let v):
            if let int64Value = self.int64Value, Decimal(int64Value) == v {
                try container.encode(int64Value)
                return
            }

            if v >= 0 {
                let uint64Value = self.clampedUint64Value
                if Decimal(uint64Value) == v {
                    try container.encode(uint64Value)
                    return
                }
            }

            let doubleValue = self.doubleValue
            if doubleValue.isInfinite || doubleValue.isNaN {
                struct NonConformingFloatError: Error {
                    let message = "Cannot encode non-conforming float value (infinity or NaN)"
                }
                throw NonConformingFloatError()
            }
            try container.encode(doubleValue)
        }
    }
}
