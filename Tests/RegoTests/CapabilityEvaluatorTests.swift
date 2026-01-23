import AST
import Foundation
import IR
import Testing

@testable import Rego

@Suite("CapabilityEvaluatorTests", .timeLimit(.minutes(1)))
struct CapabilityEvaluatorTests {
    @Test("Parsing and validating a fully specified capabilities file")
    func testValidatingCapabilitiesFile() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/full-capabilities-bundle")
                )
            ],
            capabilities: .path(IREvaluatorTests.relPath("TestData/Bundles/full-capabilities-bundle/capabilities.json"))
        )
        _ = try await engine.prepareForEvaluation(query: "policy")
    }

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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-passing.json"
                ))
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-rejected-missing.json"
                ))
        )

        let error = try await requireThrows(throws: RegoError.self, "Missing builtin must raise error") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("count"))  // count builtin signature missing
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-rejected-signature-mismatch.json"
                ))
        )

        let error = try await requireThrows(throws: RegoError.self, "Mismatch builtin signature must fail") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesMissingBuiltin)
        #expect(error.message.contains("count"))  // count builtin signature mismatch
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-passing.json"
                )),
            customBuiltins: [
                "my.slugify": { _, _ in .number(1) }
            ]
        )
        _ = try await engine.prepareForEvaluation(
            query: "policy"
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-rejected-missing.json"
                )),
            customBuiltins: [
                "my.slugify": { _, _ in .number(1) }
            ]
        )
        let error = try await requireThrows(throws: RegoError.self, "Missing builtin must raise error") {
            _ = try await engine.prepareForEvaluation(
                query: "policy"
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-rejected-signature-mismatch.json"
                )),
            customBuiltins: [
                "my.slugify": { _, _ in .number(1) }
            ]
        )

        let error = try await requireThrows(throws: RegoError.self, "Mismatched builtin signature must fail") {
            _ = try await engine.prepareForEvaluation(
                query: "policy"
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
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-custom-builtins/capabilities/capabilities-passing.json"
                )),
            customBuiltins: [:]  // not specifying the builtin
        )
        let error = try await requireThrows(throws: RegoError.self, "Required builtin not provided must fail") {
            _ = try await engine.prepareForEvaluation(
                query: "policy"
            )
        }
        #expect(error.code == .builtinUndefinedError)
        #expect(error.message.contains("my.slugify"))
    }

    @Test("Failing when capabilities file cannot be read from URL")
    func testCapabilitiesFileReadError() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            // Non-existent file to trigger read error
            capabilities: .path(IREvaluatorTests.relPath("TestData/Capabilities/does-not-exist.json"))
        )

        let error = try await requireThrows(throws: RegoError.self, "Unreadable capabilities file must raise error") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesReadError)
    }

    @Test("Failing when capabilities file cannot be decoded")
    func testCapabilitiesFileDecodeError() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            // Invalid JSON to trigger decode error
            capabilities: .path(IREvaluatorTests.relPath("TestData/Capabilities/invalid.json"))
        )

        let error = try await requireThrows(throws: RegoError.self, "Invalid capabilities JSON must raise error") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .capabilitiesDecodeError)
    }

    @Test("Failing when custom builtin name conflicts with default")
    func testConflictingCustomBuiltinName() async throws {
        var engine = OPA.Engine(
            bundlePaths: [
                .init(
                    name: "policy",
                    url: IREvaluatorTests.relPath("TestData/Bundles/simple-capabilities-bundle-default-builtins")
                )
            ],
            // Capabilities are unrelated to the name conflict; any passing file works
            capabilities: .path(
                IREvaluatorTests.relPath(
                    "TestData/Bundles/simple-capabilities-bundle-default-builtins/capabilities/capabilities-passing.json"
                )),
            customBuiltins: [
                // 'count' is a default builtin; this should trigger ambiguousBuiltinError during prepare
                "count": { _, _ in .number(0) }
            ]
        )

        let error = try await requireThrows(throws: RegoError.self, "Conflicting builtin name must raise error") {
            _ = try await engine.prepareForEvaluation(query: "policy")
        }
        #expect(error.code == .ambiguousBuiltinError)
        #expect(error.message.contains("count"))
    }
}

// Note(philip): This function is needed to emulate modern #require behavior
// in older versions of Swift (<= 6.0.3), returning the caught error. It should
// be replaced with normal usage of #require as soon as 6.0.3 support is dropped.
private func requireThrows<E: Error & Sendable, R>(
    throws errorType: E.Type,
    _ comment: String = "",
    operation: () async throws -> R
) async throws -> E {
    do {
        _ = try await operation()
        #expect(Bool(false), "Expected \(errorType) to be thrown. \(comment)")
        fatalError("This should never be reached")
    } catch let error as E {
        return error
    } catch {
        #expect(Bool(false), "Expected \(errorType) but got \(type(of: error)). \(comment)")
        fatalError("This should never be reached")
    }
}
