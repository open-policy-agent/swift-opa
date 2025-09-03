import AST
import Foundation
import IR
import Testing

@testable import Rego

@Suite("CapabilityEvaluatorTests", .timeLimit(.minutes(1)))
struct CapabilityEvaluatorTests {
    // Default builtins
    
    @Test("Passing capabilities with default builtins")
    func testCapabilitiesPassingDefaultBuiltins() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-passing.json")
        )
        _ = try await engine.prepareForEvaluation(query: "policy")
    }

    @Test("Failing capabilities when required default builtin is missing")
    func testCapabilitiesFailingMissingDefaultBuiltin() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-rejected-missing.json")
        )

        let error = try await #require(throws: RegoError.self, "Missing builtin must raise error") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("count"))        // count builtin signature missing
    }

    @Test("Failing capabilities when default builtin signature mismatches")
    func testCapabilitiesFailingSignatureMismatchDefaultBuiltin() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-rejected-signature-mismatch.json")
        )

        let error = try await #require(throws: RegoError.self, "Mismatch builtin signature must fail") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("count"))        // count builtin signature mismatch
    }

    // Custom builtins

    @Test("Passing capabilities with custom builtin")
    func testCapabilitiesPassingCustomBuiltin() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-custom-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath(
                "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-passing.json"
            )
        )
        _ = try await engine.prepareForEvaluation(
            query: "policy",
            customBuiltins: [
                "my.slugify": { _, _ in .number(1) }
            ]
        )
    }

    @Test("Failing capabilities when required custom builtin is missing from capabilities")
    func testCapabilitiesFailingMissingCustomBuiltinInCapabilities() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-custom-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath(
                "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-rejected-missing.json"
            )
        )
        let error = try await #require(throws: RegoError.self, "Missing builtin must raise error") {
            _ = try await engine.prepareForEvaluation(
                query: "policy",
                customBuiltins: [
                    "my.slugify": { _, _ in .number(1) }
                ]
            )
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("my.slugify"))
    }

    @Test("Failing capabilities when custom builtin signature mismatches")
    func testCapabilitiesFailingSignatureMismatchCustomBuiltin() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-custom-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath(
                "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-rejected-signature-mismatch.json"
            )
        )

        let error = try await #require(throws: RegoError.self, "Mismatched builtin signature must fail") {
            _ = try await engine.prepareForEvaluation(
                query: "policy",
                customBuiltins: [
                    "my.slugify": { _, _ in .number(1) }
                ]
            )
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("my.slugify"))
    }

    @Test("Failing when capabilities include custom builtin but registry lacks it")
    func testCapabilitiesFailingCustomBuiltinNotProvided() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-custom-builtins")
                )
            ],
            capabilitiesPath: IREvaluatorTests.relPath(
                "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-passing.json"
            )
        )
        let error = try await #require(throws: RegoError.self, "Required builtin not provided must fail") {
            _ = try await engine.prepareForEvaluation(
                query: "policy",
                customBuiltins: [:]     // Not specifying the builtin
            )
        }
        #expect(error.code == .builtinUndefinedError)
        #expect(error.message.contains("my.slugify"))
    }
}
