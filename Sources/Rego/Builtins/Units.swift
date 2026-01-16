import AST
import Foundation

extension BuiltinFuncs {
    static func parseUnits(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doParse(
            ctx: ctx, args: args, allowedUnits: ConversionUnit.regularUnits, unitNormalizer: metricUnitNormalizer,
            returnInts: false,
            msgNoAmount: "no amount provided",
            msgInvalidAmount: "could not parse amount to a number",
            msgInvalidUnit: "unknown unit",
            msgNoSpacesAllowed: "spaces not allowed in resource strings")
    }

    static func parseByteUnits(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doParse(
            ctx: ctx, args: args,
            allowedUnits: ConversionUnit.specialByteUnits.merging(
                ConversionUnit.regularUnits, uniquingKeysWith: { (current, _) in current }),
            unitNormalizer: { $0.lowercased() },
            returnInts: true,
            msgNoAmount: "no byte amount provided",
            msgInvalidAmount: "could not parse byte amount to a number",
            msgInvalidUnit: "unknown unit",
            msgNoSpacesAllowed: "spaces not allowed in resource strings")
    }

    /// Returns the normalized metric unit symbol for a given symbol.
    /// Unlike in units.parse_bytes, we only lowercase after the first letter,
    /// so that we can distinguish between 'm' and 'M'.
    /// - Parameter symbol: The symbol to normalize.
    private static func metricUnitNormalizer(_ symbol: String) -> String {
        if symbol.count > 1 {
            let lower = symbol.dropFirst().lowercased()  // Drop the first character and convert the rest to lowercase
            return String(symbol.prefix(1)) + lower  // Concatenate the first character with the lowercase rest
        }
        return symbol
    }

    /// Internal implementation of units parsing suitable for both metrics and byte units.

    /// Returns the normalized metric unit symbol for a given symbol.
    /// - Parameters:
    ///   - ctx: The builtin context.
    ///   - args: The arguments to parse.
    ///   - allowedUnits: The set of valid units.
    ///   - unitNormalizer: The function to normalize unit symbols.
    ///   - returnInts: Flag signaling that float values need to be truncated to ints.
    ///   - msgNoAmount: The error message to use if no amount is provided.
    ///   - msgInvalidAmount: The error message to use if the amount string cannot be parsed as a number.
    ///   - msgInvalidUnit: The error message to use if the unit is invalid.
    ///   - msgNoSpacesAllowed: The error message to use if the input string contains spaces (backwards compatibility with compliance tests)
    private static func doParse(
        ctx: BuiltinContext, args: [AST.RegoValue], allowedUnits: [String: ConversionUnit],
        unitNormalizer: (String) -> String,
        returnInts: Bool,
        msgNoAmount: String,
        msgInvalidAmount: String,
        msgInvalidUnit: String,
        msgNoSpacesAllowed: String
    ) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard !value.contains(" ") else {
            throw BuiltinError.evalError(msg: msgNoSpacesAllowed)
        }

        let pair: (String, String) = extractNumAndUnit(input: value.replacingOccurrences(of: "\"", with: ""))
        guard pair.0.count > 0 else {
            throw BuiltinError.evalError(msg: msgNoAmount)
        }

        // For Go Compatibility, there is a difference in how Decimal vs Golang parses strings like 0.0.0
        guard pair.0.components(separatedBy: ".").count <= 2 else {
            throw BuiltinError.evalError(msg: msgInvalidAmount)
        }
        // Now try to parse the amount value into a Decimal
        guard let x = Decimal(string: pair.0) else {
            throw BuiltinError.evalError(msg: msgInvalidAmount)
        }

        let unit = unitNormalizer(pair.1)

        // Lookup the unit
        guard let u = allowedUnits[unit] else {
            throw BuiltinError.evalError(msg: msgInvalidUnit)
        }

        // Compute and return the result
        // Note that if result *looks like an int*, we will just return an integer
        // even though we maintain our computations as Decimals
        let result = NSNumber(value: NSDecimalNumber(decimal: u.apply(to: x)).doubleValue)

        // Handle infinite values that would crash in toNumberRegoValue
        guard result.doubleValue.isFinite else {
            let infiniteValue =
                returnInts
                ? NSNumber(value: result.doubleValue > 0 ? Int64.max : Int64.min)
                : NSNumber(value: result.doubleValue)
            return .number(infiniteValue)
        }

        return result.toNumberRegoValue(asInt: returnInts)
    }

    /// See https://github.com/open-policy-agent/opa/blob/ce23f71acaabb3b2a9e1438db29047c483a5f009/v1/topdown/parse_bytes.go#L118
    /// for the original Go implementation.
    private static func extractNumAndUnit(input s: String) -> (String, String) {
        func isNum(_ c: Character) -> Bool {
            return c.isNumber || c == "."
        }

        var firstNonNumIdx = -1
        var scanIndex = 0

        while scanIndex < s.count {
            let c = s[s.index(s.startIndex, offsetBy: scanIndex)]

            // Identify the first non-numeric character, marking the boundary between the number and the unit.
            if !isNum(c) && c != "e" && c != "E" && c != "+" && c != "-" {
                firstNonNumIdx = scanIndex
                break
            }

            let nextIndex = s.index(s.startIndex, offsetBy: scanIndex + 1)
            if c == "e" || c == "E" {
                // Check if the next character is a valid digit or +/- for scientific notation
                if scanIndex == s.count - 1 || (!s[nextIndex].isNumber && s[nextIndex] != "+" && s[nextIndex] != "-") {
                    firstNonNumIdx = scanIndex
                    break
                }

                // Skip the next character if it is '+' or '-'
                if scanIndex + 1 < s.count && (s[nextIndex] == "+" || s[nextIndex] == "-") {
                    scanIndex += 1
                }
            }

            scanIndex += 1
        }

        if firstNonNumIdx == -1 {  // only digits, '.', or valid scientific notation
            return (s, "")
        }

        if firstNonNumIdx == 0 {  // only units (starts with non-digit)
            return ("", s)
        }

        // Return the number and the rest as the unit
        let numberPart = String(s.prefix(firstNonNumIdx))
        let unitPart = String(s.suffix(from: s.index(s.startIndex, offsetBy: firstNonNumIdx)))

        return (numberPart, unitPart)
    }
}

/// Conversion Units: https://en.wikipedia.org/wiki/Metric_prefix
/// Note that we are only supporting the same subset that is defined in OPA:
/// See  https://github.com/open-policy-agent/opa/blob/ce23f71acaabb3b2a9e1438db29047c483a5f009/v1/topdown/parse_units.go#L71
/// For Byte Units
/// See https://github.com/open-policy-agent/opa/blob/ce23f71acaabb3b2a9e1438db29047c483a5f009/v1/topdown/parse_bytes.go#L17
struct ConversionUnit {
    let symbols: [String]
    let coefficient: Decimal
    static let none = ConversionUnit(symbols: [""], coefficient: 1)
    static let milli = ConversionUnit(symbols: ["m"], coefficient: Decimal(0.001))
    static let kilo = ConversionUnit(symbols: ["k", "K"], coefficient: 1000)
    static let ki = ConversionUnit(symbols: ["ki", "Ki"], coefficient: 1024)
    static let mega = ConversionUnit(symbols: ["M"], coefficient: 1000 * 1000)
    static let mi = ConversionUnit(symbols: ["mi", "Mi"], coefficient: 1024 * 1024)
    static let giga = ConversionUnit(symbols: ["g", "G"], coefficient: 1000 * 1000 * 1000)
    static let gi = ConversionUnit(symbols: ["gi", "Gi"], coefficient: 1024 * 1024 * 1024)
    static let tera = ConversionUnit(symbols: ["t", "T"], coefficient: 1000 * 1000 * 1000 * 1000)
    static let ti = ConversionUnit(symbols: ["ti", "Ti"], coefficient: 1024 * 1024 * 1024 * 1024)
    static let peta = ConversionUnit(symbols: ["p", "P"], coefficient: 1000 * 1000 * 1000 * 1000 * 1000)
    static let pi = ConversionUnit(symbols: ["pi", "Pi"], coefficient: 1024 * 1024 * 1024 * 1024 * 1024)
    static let exa = ConversionUnit(symbols: ["e", "E"], coefficient: 1000 * 1000 * 1000 * 1000 * 1000 * 1000)
    static let ei = ConversionUnit(symbols: ["ei", "Ei"], coefficient: 1024 * 1024 * 1024 * 1024 * 1024 * 1024)
    // We map ALL individual conversion units' symbols to the Conversion Unit itself
    static let regularUnits: [String: ConversionUnit] = Dictionary(
        uniqueKeysWithValues: [
            ConversionUnit.none, ConversionUnit.milli, ConversionUnit.kilo, ConversionUnit.ki, ConversionUnit.mega,
            ConversionUnit.mi, ConversionUnit.giga, ConversionUnit.gi, ConversionUnit.tera, ConversionUnit.ti,
            ConversionUnit.peta, ConversionUnit.pi, ConversionUnit.exa, ConversionUnit.ei,
        ].flatMap { z in
            z.symbols.map { symbol in
                (symbol, z)
            }
        })

    static let kb = ConversionUnit(symbols: ["kb", "k"], coefficient: 1000)
    static let kib = ConversionUnit(symbols: ["kib", "ki"], coefficient: 1024)
    static let mb = ConversionUnit(symbols: ["mb", "m"], coefficient: 1000 * 1000)
    static let mib = ConversionUnit(symbols: ["mib", "mi"], coefficient: 1024 * 1024)
    static let gb = ConversionUnit(symbols: ["gb", "g"], coefficient: 1000 * 1000 * 1000)
    static let gib = ConversionUnit(symbols: ["gib", "bi"], coefficient: 1024 * 1024 * 1024)
    static let tb = ConversionUnit(symbols: ["tb", "t"], coefficient: 1000 * 1000 * 1000 * 1000)
    static let tib = ConversionUnit(symbols: ["tib", "ti"], coefficient: 1024 * 1024 * 1024 * 1024)
    static let pb = ConversionUnit(symbols: ["pb", "p"], coefficient: 1000 * 1000 * 1000 * 1000 * 1000)
    static let pib = ConversionUnit(symbols: ["pib", "pi"], coefficient: 1024 * 1024 * 1024 * 1024 * 1024)
    static let eb = ConversionUnit(symbols: ["eb", "e"], coefficient: 1000 * 1000 * 1000 * 1000 * 1000 * 1000)
    static let eib = ConversionUnit(symbols: ["eib", "ei"], coefficient: 1024 * 1024 * 1024 * 1024 * 1024 * 1024)
    // We map ALL individual conversion units' symbols to the Conversion Unit itself
    static let specialByteUnits: [String: ConversionUnit] = Dictionary(
        uniqueKeysWithValues: [
            ConversionUnit.none, ConversionUnit.kb, ConversionUnit.kib, ConversionUnit.mb, ConversionUnit.mib,
            ConversionUnit.gb, ConversionUnit.gib, ConversionUnit.tb, ConversionUnit.tib, ConversionUnit.pb,
            ConversionUnit.pib, ConversionUnit.eb, ConversionUnit.eib,
        ].flatMap { z in
            z.symbols.map { symbol in
                (symbol, z)
            }
        })
}

extension ConversionUnit {
    public func apply(to value: Decimal) -> Decimal {
        return value * self.coefficient
    }
}

extension NSNumber {
    /// Returns .number RegoValue that best represents a given NSNumber.
    /// If the number *looks like an int*, we will just return an integer.
    /// When asInt=true is passed, we will *ALWAYS* return an integer.
    /// Positive integers will be returned as unsigned int64.
    /// Booleans will also be converted to .number RegoValue.
    /// - Parameter asInt: forces truncation to integer even when the number if fractional
    func toNumberRegoValue(asInt: Bool = false) -> RegoValue {
        if asInt {
            if self.decimalValue > Decimal(0) {
                return .number(NSNumber(value: self.uint64Value))
            }
            return .number(NSNumber(value: self.int64Value))
        }
        let fractionalRemainder = self.decimalValue - Decimal(self.int64Value)
        guard fractionalRemainder == Decimal(0) else {
            // It's probably a float
            return .number(self)
        }
        if self.decimalValue > Decimal(0) {
            return .number(NSNumber(value: self.uint64Value))
        }
        return .number(NSNumber(value: self.int64Value))
    }
}
