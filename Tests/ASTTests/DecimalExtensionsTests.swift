import Foundation
import Testing

@testable import AST

// Tests for Decimal.safeInt64Value and the NSDecimalCompact invariant it relies on.
//
// safeInt64Value uses NSDecimalCompact to short-circuit non-integer decimals without
// allocating NSNumber. The correctness depends on NSDecimalCompact removing ALL trailing
// zeros from the significand so that a negative exponent after compaction reliably means
// the value is not an integer.

@Suite("DecimalExtensions")
struct DecimalExtensionsTests {

    // MARK: - NSDecimalCompact invariant

    // Construct 2.0 as significand=20, exponent=-1 by starting from Decimal(2)
    // (significand=2, exponent=0) and shifting one decimal place: multiply significand
    // by 10 and decrement exponent. Verifies NSDecimalCompact removes the trailing zero.
    // Requires access to Decimal's internal fields — Apple platforms only.
    #if canImport(ObjectiveC)
        @Test func compactRaisesExponentForIntegerWithTrailingZeroInSignificand() {
            var d = Decimal(2)
            d._mantissa.0 *= 10  // 2 → 20
            d._exponent -= 1  // 0 → -1: now 20 × 10^-1 = 2.0 (non-compact)
            d._isCompact = 0

            #expect(d == 2, "precondition: 20 × 10^-1 should equal 2")
            #expect(d.exponent == -1, "precondition: exponent should be -1 before compact")

            NSDecimalCompact(&d)

            #expect(d.exponent >= 0, "compact must raise exponent when significand has trailing zero")
            #expect(d == 2, "value must be unchanged after compact")
        }
    #endif

    // Non-integers have no trailing zeros to remove — compact leaves exponent negative.
    @Test func compactLeavesExponentNegativeForNonInteger() {
        var d = Decimal(string: "1.5")!
        #expect(d.exponent < 0, "precondition: 1.5 should have negative exponent")
        NSDecimalCompact(&d)
        #expect(d.exponent < 0, "compact cannot raise exponent for a genuine non-integer")
    }

    // MARK: - safeInt64Value

    @Test func safeInt64ValueReturnsNilForFractionalDecimal() {
        #expect(Decimal(string: "1.5")!.safeInt64Value == nil)
        #expect(Decimal(string: "10.23")!.safeInt64Value == nil)
        #expect(Decimal(string: "-0.1")!.safeInt64Value == nil)
        #expect(Decimal(string: "0.999")!.safeInt64Value == nil)
        // Double-initialised fractionals (1.5 and 2.5 are exactly representable in binary)
        #expect(Decimal(1.5).safeInt64Value == nil)
        #expect(Decimal(2.5).safeInt64Value == nil)
    }

    @Test func safeInt64ValueConvertsPlainIntegers() {
        #expect(Decimal(2).safeInt64Value == 2)
        #expect(Decimal(0).safeInt64Value == 0)
        #expect(Decimal(-5).safeInt64Value == -5)
        #expect(Decimal(1_000_000).safeInt64Value == 1_000_000)
        #expect(Decimal(Int64.max).safeInt64Value == Int64.max)
        #expect(Decimal(Int64.min).safeInt64Value == Int64.min)
        // Double-initialised integers (2.0 is exactly representable)
        #expect(Decimal(2.0).safeInt64Value == 2)
    }

    @Test func safeInt64ValueConvertsArithmeticIntegers() {
        #expect((Decimal(10) / Decimal(5)).safeInt64Value == 2)
        #expect((Decimal(100) / Decimal(10)).safeInt64Value == 10)
        #expect((Decimal(3) * Decimal(4)).safeInt64Value == 12)
    }

    @Test func safeInt64ValueReturnsNilForArithmeticFractions() {
        #expect((Decimal(1) / Decimal(3)).safeInt64Value == nil)
        #expect((Decimal(2) / Decimal(3)).safeInt64Value == nil)
        #expect((Decimal(10) / Decimal(3)).safeInt64Value == nil)
    }

    // Verify safeInt64Value handles an integer stored with a negative exponent
    // (the case NSDecimalCompact is needed for).
    // Requires access to Decimal's internal fields — Apple platforms only.
    #if canImport(ObjectiveC)
        @Test func safeInt64ValueConvertsIntegerWithNegativeExponent() {
            var d = Decimal(2)
            d._mantissa.0 *= 10
            d._exponent -= 1
            d._isCompact = 0
            #expect(d.safeInt64Value == 2)
        }
    #endif

    @Test func safeInt64ValueReturnsNilOutOfRange() {
        #expect((Decimal(Int64.max) + 1).safeInt64Value == nil)
        #expect((Decimal(Int64.min) - 1).safeInt64Value == nil)
    }
}
