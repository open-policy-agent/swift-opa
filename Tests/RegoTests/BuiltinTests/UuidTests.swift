import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - UUID", .tags(.builtins))
    struct UuidTests {}
}

extension BuiltinTests.UuidTests {

    static let parseTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "parses UUID1",
            name: "uuid.parse",
            args: ["82dcb190-ef23-11ef-a7eb-5181aee655db"],
            expected: .success(
                .object([
                    "clocksequence": 10219,
                    "macvariables": "global:multicast",
                    "nodeid": "51-81-ae-e6-55-db",
                    "time": 1_740_012_127_017_000_000,
                    "variant": "RFC4122",
                    "version": 1,
                ]))
        ),
        BuiltinTests.TestCase(
            description: "parses UUID2",
            name: "uuid.parse",
            args: ["000003e8-f01d-21ef-8600-325096b39f47"],
            expected: .success(
                .object([
                    "clocksequence": 1536,
                    "macvariables": "local:unicast",
                    "nodeid": "32-50-96-b3-9f-47",
                    "time": 1_740_119_281_649_354_400,
                    "variant": "RFC4122",
                    "version": 2,
                    "id": 1000,
                    "domain": "Person",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "parses UUID4",
            name: "uuid.parse",
            args: [.string(UUID().uuidString)],
            expected: .success(
                .object([
                    "version": 4, "variant": "RFC4122",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "parses zero UUID4",
            name: "uuid.parse",
            args: [.string("00000000-0000-4000-8000-000000000000")],
            expected: .success(
                .object([
                    "version": 4, "variant": "RFC4122",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "ignores braces in UUID when at the ends",
            name: "uuid.parse",
            args: [.string("{00000000-0000-4000-8000-000000000000}")],
            expected: .success(
                .object([
                    "version": 4, "variant": "RFC4122",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "does not ignore braces in UUID when NOT at the ends",
            name: "uuid.parse",
            args: [.string("00000000-{0000}-4000-8000-000000000000")],
            expected: .failure(BuiltinError.evalError(msg: "invalid UUID format"))
        ),
        BuiltinTests.TestCase(
            description: "ignores leading urn:uuid:",
            name: "uuid.parse",
            args: [.string("urn:uuid:00000000-0000-4000-8000-000000000000")],
            expected: .success(
                .object([
                    "version": 4, "variant": "RFC4122",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "does not ignore urn:uuid: in the middle",
            name: "uuid.parse",
            args: [.string("00000000-urn:uuid:0000-4000-8000-000000000000")],
            expected: .failure(BuiltinError.evalError(msg: "invalid UUID format"))
        ),
        BuiltinTests.TestCase(
            description: "parses UUID without dashes",
            name: "uuid.parse",
            args: [.string("00000000000040008000000000000000")],
            expected: .success(
                .object([
                    "version": 4, "variant": "RFC4122",
                ]))
        ),
        BuiltinTests.TestCase(
            description: "returns undefined for invalid UUID",
            name: "uuid.parse",
            args: [.string("this is not valid UUID")],
            expected: .failure(BuiltinError.evalError(msg: "invalid UUID format"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "uuid.parse", sampleArgs: ["82DCB190-EF23-11EF-A7EB-5181AEE655DB"], argIndex: 0,
                argName: "uuid", allowedArgTypes: ["string"]),
            parseTests,

            BuiltinTests.generateFailureTests(
                builtinName: "uuid.rfc4122", sampleArgs: ["key"], argIndex: 0,
                argName: "k", allowedArgTypes: ["string"]),
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    @Test
    func rfc4122ReturnsValidUUID() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result = try await reg.invoke(withContext: ctx, name: "uuid.rfc4122", args: ["foo"], strict: true)
        // Make sure the output is *actually* a UUID
        switch result {
        case .string(let uuid):
            #expect(UUID(uuidString: uuid) != nil)
        default:
            Issue.record("uuid.rfc4122 should return a string, but got: \(result)")
        }
    }

    @Test
    func rfc4122ReturnsSameValueForSameKey() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "uuid.rfc4122", args: ["foo"], strict: true)
        let result2 = try await reg.invoke(withContext: ctx, name: "uuid.rfc4122", args: ["foo"], strict: true)
        #expect(result1 == result2)
    }

    @Test
    func rfc4122ReturnsDifferentValuesForNewContext() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx1 = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx1, name: "uuid.rfc4122", args: ["foo"], strict: true)
        let ctx2 = BuiltinContext()
        let result2 = try await reg.invoke(withContext: ctx2, name: "uuid.rfc4122", args: ["foo"], strict: true)
        #expect(result1 != result2)
    }

    @Test
    func rfc4122ReturnsDifferentValuesForDifferentKeys() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "uuid.rfc4122", args: ["foo"], strict: true)
        let result2 = try await reg.invoke(withContext: ctx, name: "uuid.rfc4122", args: ["bar"], strict: true)
        #expect(result1 != result2)
    }
}
