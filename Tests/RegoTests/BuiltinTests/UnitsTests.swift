import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Units", .tags(.builtins))
    struct UnitsTests {}
}

let exo: UInt64 = 10_000_000_000_000_000_000
let ei: UInt64 = 11_529_215_046_068_469_760

extension BuiltinTests.UnitsTests {
    // Test cases below largely mimic the compliance suite
    static let unitsParseErrorTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty string causes units.parse: no amount provided",
            name: "units.parse",
            args: [""],
            expected: .failure(BuiltinError.evalError(msg: "no amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "solo unit string causes units.parse: no amount provided",
            name: "units.parse",
            args: ["G"],
            expected: .failure(BuiltinError.evalError(msg: "no amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "non-number causes units.parse: could not parse amount to a number",
            name: "units.parse",
            args: ["foo"],
            expected: .failure(
                BuiltinError.evalError(msg: "no amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "invalid number causes units.parse: could not parse amount to a number",
            name: "units.parse",
            args: ["0.0.0"],
            expected: .failure(
                BuiltinError.evalError(msg: "could not parse amount to a number"))
        ),
        BuiltinTests.TestCase(
            description: "spaces causes units.parse: spaces not allowed in resource strings",
            name: "units.parse",
            args: ["10 0G"],
            expected: .failure(
                BuiltinError.evalError(msg: "spaces not allowed in resource strings"))
        ),
        BuiltinTests.TestCase(
            description: "unknown unit causes units.parse: unknown unit",
            name: "units.parse",
            args: ["0Z"],
            expected: .failure(BuiltinError.evalError(msg: "unknown unit"))
        ),
    ]

    static let unitsParseTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "500m == 0.5",
            name: "units.parse",
            args: ["500m"],
            expected: .success(.number(0.5))
        ),
        BuiltinTests.TestCase(
            description: "0.0005K == 0.5",
            name: "units.parse",
            args: ["0.0005K"],
            expected: .success(.number(0.5))
        ),
        BuiltinTests.TestCase(
            description: "0.0000005M == 0.5",
            name: "units.parse",
            args: ["0.0000005M"],
            expected: .success(.number(0.5))
        ),
        BuiltinTests.TestCase(
            description: "Quoted \"100TI\" == 109951162777600",
            name: "units.parse",
            args: ["\"100TI\""],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100TI == 109951162777600",
            name: "units.parse",
            args: ["100TI"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "0 == 0",
            name: "units.parse",
            args: ["0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "0.0 == 0",
            name: "units.parse",
            args: ["0.0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: ".0 == 0",
            name: "units.parse",
            args: [".0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "12345 == 12345",
            name: "units.parse",
            args: ["12345"],
            expected: .success(.number(12345))
        ),
        BuiltinTests.TestCase(
            description: "10K == 10000",
            name: "units.parse",
            args: ["10K"],
            expected: .success(.number(10000))
        ),
        BuiltinTests.TestCase(
            description: "10KI == 10240",
            name: "units.parse",
            args: ["10KI"],
            expected: .success(.number(10240))
        ),
        BuiltinTests.TestCase(
            description: "10k == 10000",
            name: "units.parse",
            args: ["10k"],
            expected: .success(.number(10000))
        ),
        BuiltinTests.TestCase(
            description: "10Ki == 10240",
            name: "units.parse",
            args: ["10Ki"],
            expected: .success(.number(10240))
        ),
        BuiltinTests.TestCase(
            description: "200M == 200000000",
            name: "units.parse",
            args: ["200M"],
            expected: .success(.number(200_000_000))
        ),
        BuiltinTests.TestCase(
            description: "300Gi == 322122547200",
            name: "units.parse",
            args: ["300Gi"],
            expected: .success(.number(322_122_547_200))
        ),
        BuiltinTests.TestCase(
            description: "1.1K == 1100",
            name: "units.parse",
            args: ["1.1K"],
            expected: .success(.number(1100))
        ),
        BuiltinTests.TestCase(
            description: "1.1Ki == 1126.4",
            name: "units.parse",
            args: ["1.1Ki"],
            expected: .success(.number(1126.4))
        ),
        BuiltinTests.TestCase(
            description: ".5K == 500",
            name: "units.parse",
            args: [".5K"],
            expected: .success(.number(500))
        ),
        BuiltinTests.TestCase(
            description: "100k == 100000",
            name: "units.parse",
            args: ["100k"],
            expected: .success(.number(100000))
        ),
        BuiltinTests.TestCase(
            description: "100K == 100000",
            name: "units.parse",
            args: ["100K"],
            expected: .success(.number(100000))
        ),
        BuiltinTests.TestCase(
            description: "100ki == 102400",
            name: "units.parse",
            args: ["100ki"],
            expected: .success(.number(102400))
        ),
        BuiltinTests.TestCase(
            description: "100Ki == 102400",
            name: "units.parse",
            args: ["100Ki"],
            expected: .success(.number(102400))
        ),
        BuiltinTests.TestCase(
            description: "100M == 100000000",
            name: "units.parse",
            args: ["100M"],
            expected: .success(.number(100_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100mi == 104857600",
            name: "units.parse",
            args: ["100mi"],
            expected: .success(.number(104_857_600))
        ),
        BuiltinTests.TestCase(
            description: "100Mi == 104857600",
            name: "units.parse",
            args: ["100Mi"],
            expected: .success(.number(104_857_600))
        ),
        BuiltinTests.TestCase(
            description: "100g == 100000000000",
            name: "units.parse",
            args: ["100g"],
            expected: .success(.number(100_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100gi == 107374182400",
            name: "units.parse",
            args: ["100gi"],
            expected: .success(.number(107_374_182_400))
        ),
        BuiltinTests.TestCase(
            description: "100t == 100000000000000",
            name: "units.parse",
            args: ["100t"],
            expected: .success(.number(100_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100T == 100000000000000",
            name: "units.parse",
            args: ["100T"],
            expected: .success(.number(100_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100ti == 109951162777600",
            name: "units.parse",
            args: ["100ti"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100Ti == 109951162777600",
            name: "units.parse",
            args: ["100Ti"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100p == 100000000000000000",
            name: "units.parse",
            args: ["100p"],
            expected: .success(.number(100_000_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100P == 100000000000000000",
            name: "units.parse",
            args: ["100P"],
            expected: .success(.number(100_000_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100pi == 112589990684262400",
            name: "units.parse",
            args: ["100pi"],
            expected: .success(.number(112_589_990_684_262_400))
        ),
        BuiltinTests.TestCase(
            description: "100Pi == 112589990684262400",
            name: "units.parse",
            args: ["100Pi"],
            expected: .success(.number(112_589_990_684_262_400))
        ),
        BuiltinTests.TestCase(
            description: "10e == 10000000000000000000",
            name: "units.parse",
            args: ["10e"],
            expected: .success(.number(RegoNumber(value: exo)))
        ),
        BuiltinTests.TestCase(
            description: "10E == 10000000000000000000",
            name: "units.parse",
            args: ["10E"],
            expected: .success(.number(RegoNumber(value: exo)))
        ),
        BuiltinTests.TestCase(
            description: "10ei == 11529215046068469760",
            name: "units.parse",
            args: ["10ei"],
            expected: .success(.number(RegoNumber(value: ei)))
        ),
        BuiltinTests.TestCase(
            description: "10Ei == 11529215046068469760",
            name: "units.parse",
            args: ["10Ei"],
            expected: .success(.number(RegoNumber(value: ei)))
        ),
        BuiltinTests.TestCase(
            description: "1e10 == 10000000000",
            name: "units.parse",
            args: ["1e10"],
            expected: .success(.number(10_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "3.2E4 == 32000",
            name: "units.parse",
            args: ["3.2E4"],
            expected: .success(.number(32000))
        ),
        BuiltinTests.TestCase(
            description: "2.5e3K == 2500000",
            name: "units.parse",
            args: ["2.5e3K"],
            expected: .success(.number(2_500_000))
        ),
        BuiltinTests.TestCase(
            description: "1e3M == 1000000000",
            name: "units.parse",
            args: ["1e3M"],
            expected: .success(.number(1_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "4E2G == 400000000000",
            name: "units.parse",
            args: ["4E2G"],
            expected: .success(.number(400_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "5e1Gi == 53687091200",
            name: "units.parse",
            args: ["5e1Gi"],
            expected: .success(.number(53_687_091_200))
        ),
        BuiltinTests.TestCase(
            description: "1e-2 == 0.01",
            name: "units.parse",
            args: ["1e-2"],
            expected: .success(.number(0.01))
        ),
        BuiltinTests.TestCase(
            description: "7.8E-1 == 0.78",
            name: "units.parse",
            args: ["7.8E-1"],
            expected: .success(.number(0.78))
        ),
        BuiltinTests.TestCase(
            description: "6e3Mi == 6291456000",
            name: "units.parse",
            args: ["6e3Mi"],
            expected: .success(.number(6_291_456_000))
        ),
        BuiltinTests.TestCase(
            description: "42 == 42",
            name: "units.parse",
            args: ["42"],
            expected: .success(.number(42))
        ),
        BuiltinTests.TestCase(
            description: "-3.5E2m == -0.35",
            name: "units.parse",
            args: ["-3.5E2m"],
            expected: .success(.number(-0.35))
        ),
        BuiltinTests.TestCase(
            description: "128Gi == 137438953472",
            name: "units.parse",
            args: ["128Gi"],
            expected: .success(.number(137_438_953_472))
        ),
    ]

    static let unitBytesParseErrorTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty string causes units.parse_bytes: no byte amount provided",
            name: "units.parse_bytes",
            args: [""],
            expected: .failure(
                BuiltinError.evalError(msg: "no byte amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "solo unit string causes units.parse_bytes: no byte amount provided",
            name: "units.parse_bytes",
            args: ["G"],
            expected: .failure(
                BuiltinError.evalError(msg: "no byte amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "non-number causes units.parse_bytes: could not parse byte amount to a number",
            name: "units.parse_bytes",
            args: ["foo"],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "no byte amount provided"))
        ),
        BuiltinTests.TestCase(
            description: "invalid number causes units.parse: could not parse byte amount to a number",
            name: "units.parse_bytes",
            args: ["0.0.0"],
            expected: .failure(
                BuiltinError.evalError(msg: "could not parse byte amount to a number"))
        ),
        BuiltinTests.TestCase(
            description: "spaces causes units.parse_bytes: spaces not allowed in resource strings",
            name: "units.parse_bytes",
            args: ["10 0G"],
            expected: .failure(
                BuiltinError.evalError(msg: "spaces not allowed in resource strings")
            )
        ),
        BuiltinTests.TestCase(
            description: "unknown unit causes units.parse: unknown unit",
            name: "units.parse_bytes",
            args: ["0Z"],
            expected: .failure(BuiltinError.evalError(msg: "unknown unit"))
        ),
    ]

    static let unitBytesParseTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "Quoted \"100TIB\" == 109951162777600",
            name: "units.parse_bytes",
            args: ["\"100TIB\""],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100TIB == 109951162777600",
            name: "units.parse_bytes",
            args: ["100TIB"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "0 == 0",
            name: "units.parse_bytes",
            args: ["0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "0.0 == 0",
            name: "units.parse_bytes",
            args: ["0.0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: ".0 == 0",
            name: "units.parse_bytes",
            args: [".0"],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "12345 == 12345",
            name: "units.parse_bytes",
            args: ["12345"],
            expected: .success(.number(12345))
        ),
        BuiltinTests.TestCase(
            description: "10KB == 10000",
            name: "units.parse_bytes",
            args: ["10KB"],
            expected: .success(.number(10000))
        ),
        BuiltinTests.TestCase(
            description: "10KIB == 10240",
            name: "units.parse_bytes",
            args: ["10KIB"],
            expected: .success(.number(10240))
        ),
        BuiltinTests.TestCase(
            description: "10kb == 10000",
            name: "units.parse_bytes",
            args: ["10kb"],
            expected: .success(.number(10000))
        ),
        BuiltinTests.TestCase(
            description: "10Kib == 10240",
            name: "units.parse_bytes",
            args: ["10Kib"],
            expected: .success(.number(10240))
        ),
        BuiltinTests.TestCase(
            description: "200mb == 200000000",
            name: "units.parse_bytes",
            args: ["200mb"],
            expected: .success(.number(200_000_000))
        ),
        BuiltinTests.TestCase(
            description: "300GiB == 322122547200",
            name: "units.parse_bytes",
            args: ["300GiB"],
            expected: .success(.number(322_122_547_200))
        ),
        BuiltinTests.TestCase(
            description: "1.1KB == 1100",
            name: "units.parse_bytes",
            args: ["1.1KB"],
            expected: .success(.number(1100))
        ),
        BuiltinTests.TestCase(
            description: "1.1KiB == 1126",
            name: "units.parse_bytes",
            args: ["1.1KiB"],
            expected: .success(.number(1126))
        ),
        BuiltinTests.TestCase(
            description: ".5KB == 500",
            name: "units.parse_bytes",
            args: [".5KB"],
            expected: .success(.number(500))
        ),
        BuiltinTests.TestCase(
            description: "100k == 100000",
            name: "units.parse_bytes",
            args: ["100k"],
            expected: .success(.number(100000))
        ),
        BuiltinTests.TestCase(
            description: "100kb == 100000",
            name: "units.parse_bytes",
            args: ["100kb"],
            expected: .success(.number(100000))
        ),
        BuiltinTests.TestCase(
            description: "100ki == 102400",
            name: "units.parse_bytes",
            args: ["100ki"],
            expected: .success(.number(102400))
        ),
        BuiltinTests.TestCase(
            description: "100kib == 102400",
            name: "units.parse_bytes",
            args: ["100kib"],
            expected: .success(.number(102400))
        ),
        BuiltinTests.TestCase(
            description: "100m == 100000000",
            name: "units.parse_bytes",
            args: ["100m"],
            expected: .success(.number(100_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100mb == 100000000",
            name: "units.parse_bytes",
            args: ["100mb"],
            expected: .success(.number(100_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100mi == 104857600",
            name: "units.parse_bytes",
            args: ["100mi"],
            expected: .success(.number(104_857_600))
        ),
        BuiltinTests.TestCase(
            description: "100mib == 104857600",
            name: "units.parse_bytes",
            args: ["100mib"],
            expected: .success(.number(104_857_600))
        ),
        BuiltinTests.TestCase(
            description: "100g == 100000000000",
            name: "units.parse_bytes",
            args: ["100g"],
            expected: .success(.number(100_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100gb == 100000000000",
            name: "units.parse_bytes",
            args: ["100gb"],
            expected: .success(.number(100_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100gi == 107374182400",
            name: "units.parse_bytes",
            args: ["100gi"],
            expected: .success(.number(107_374_182_400))
        ),
        BuiltinTests.TestCase(
            description: "100gib == 107374182400",
            name: "units.parse_bytes",
            args: ["100gib"],
            expected: .success(.number(107_374_182_400))
        ),
        BuiltinTests.TestCase(
            description: "100t == 100000000000000",
            name: "units.parse_bytes",
            args: ["100t"],
            expected: .success(.number(100_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100tb == 100000000000000",
            name: "units.parse_bytes",
            args: ["100tb"],
            expected: .success(.number(100_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100ti == 109951162777600",
            name: "units.parse_bytes",
            args: ["100ti"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100tib == 109951162777600",
            name: "units.parse_bytes",
            args: ["100tib"],
            expected: .success(.number(109_951_162_777_600))
        ),
        BuiltinTests.TestCase(
            description: "100p == 100000000000000000",
            name: "units.parse_bytes",
            args: ["100p"],
            expected: .success(.number(100_000_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100pb == 100000000000000000",
            name: "units.parse_bytes",
            args: ["100pb"],
            expected: .success(.number(100_000_000_000_000_000))
        ),
        BuiltinTests.TestCase(
            description: "100pi == 112589990684262400",
            name: "units.parse_bytes",
            args: ["100pi"],
            expected: .success(.number(112_589_990_684_262_400))
        ),
        BuiltinTests.TestCase(
            description: "100pib == 112589990684262400",
            name: "units.parse_bytes",
            args: ["100pib"],
            expected: .success(.number(112_589_990_684_262_400))
        ),
        BuiltinTests.TestCase(
            description: "10e == 10000000000000000000",
            name: "units.parse_bytes",
            args: ["10e"],
            expected: .success(.number(RegoNumber(value: exo)))
        ),
        BuiltinTests.TestCase(
            description: "10eb == 10000000000000000000",
            name: "units.parse_bytes",
            args: ["10eb"],
            expected: .success(.number(RegoNumber(value: exo)))
        ),
        BuiltinTests.TestCase(
            description: "10ei == 11529215046068469760",
            name: "units.parse_bytes",
            args: ["10ei"],
            expected: .success(.number(RegoNumber(value: ei)))
        ),
        BuiltinTests.TestCase(
            description: "10eib == 11529215046068469760",
            name: "units.parse_bytes",
            args: ["10eib"],
            expected: .success(.number(RegoNumber(value: ei)))
        ),
        BuiltinTests.TestCase(
            description: "1e3KB == 1000000",
            name: "units.parse_bytes",
            args: ["1e3KB"],
            expected: .success(.number(1_000_000))
        ),
        BuiltinTests.TestCase(
            description: "3.2E2MiB == 335544320",
            name: "units.parse_bytes",
            args: ["3.2E2MiB"],
            expected: .success(.number(335_544_320))
        ),
        BuiltinTests.TestCase(
            description: "4.5e1GiB == 48318382080",
            name: "units.parse_bytes",
            args: ["4.5e1GiB"],
            expected: .success(.number(48_318_382_080))
        ),
        BuiltinTests.TestCase(
            description: "5e6 == 5000000",
            name: "units.parse_bytes",
            args: ["5e6"],
            expected: .success(.number(5_000_000))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "units.parse", sampleArgs: ["100"], argIndex: 0, argName: "x", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),

            unitsParseErrorTests,
            unitsParseTests,

            BuiltinTests.generateFailureTests(
                builtinName: "units.parse_bytes", sampleArgs: ["100"], argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            unitBytesParseErrorTests,
            unitBytesParseTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}

@Suite("RegoNumber Conversion Tests")
struct RegoNumberConversionTests {
    @Test
    func returnsUIntForPositiveWholeNumbers() {
        let expectedWhole: UInt64 = 1024 * 1024 * 1024 * 1024 * 1024 * 1024
        let inputWholeDouble: Double = Double(expectedWhole)

        #expect(RegoNumber(Decimal(inputWholeDouble)) == RegoNumber(value: expectedWhole))
    }

    @Test
    func returnsIntForNegativeWholeNumbers() {
        let expectedWhole: Int64 = -1024 * 1024 * 1024
        let inputWholeDouble: Double = Double(expectedWhole)

        #expect(RegoNumber(Decimal(inputWholeDouble)) == RegoNumber(value: expectedWhole))
    }

    @Test
    func handlesFractionalNumbers() {
        let inputFractionalDouble: Double = Double.pi
        let fractionalRegoNumber = RegoNumber(Decimal(inputFractionalDouble))

        #expect(fractionalRegoNumber.isFloatType == true)
        #expect(fractionalRegoNumber.doubleValue == inputFractionalDouble)
    }
}
