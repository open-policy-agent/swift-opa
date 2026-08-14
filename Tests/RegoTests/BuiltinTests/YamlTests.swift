#if YAML
    import AST
    import Foundation
    import Testing

    @testable import Rego

    extension BuiltinTests {
        @Suite("BuiltinTests - Yaml", .tags(.builtins))
        struct YamlTests {}
    }

    extension BuiltinTests.YamlTests {
        static let yamlIsValidTests: [BuiltinTests.TestCase] = [
            BuiltinTests.TestCase(
                description: "valid yaml",
                name: "yaml.is_valid",
                args: [
                    """
                    foo:
                    - qux: bar
                    - baz: 2
                    """
                ],
                expected: .success(.boolean(true))
            ),
            BuiltinTests.TestCase(
                description: "invalid yaml",
                name: "yaml.is_valid",
                args: [
                    """
                    foo:
                    - qux: bar
                    - baz: {
                    """
                ],
                expected: .success(.boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "json ok",
                name: "yaml.is_valid",
                args: [
                    "{\"json\": \"ok\"}"
                ],
                expected: .success(.boolean(true))
            ),
            BuiltinTests.TestCase(
                description: "invalid - non string",
                name: "yaml.is_valid",
                args: [["foo": 1]],
                expected: .success(.boolean(false))  // Matches OPA: returns false rather than throwing.
            ),
        ]

        static let yamlMarshalTests: [BuiltinTests.TestCase] = [
            BuiltinTests.TestCase(
                description: "nested object and list",
                name: "yaml.marshal",
                args: [
                    [["foo": [1, 2, 3]]]
                ],
                expected: .success(
                    """
                    - foo:
                      - 1
                      - 2
                      - 3

                    """
                )
            )
        ]

        static let yamlUnmarshalTests: [BuiltinTests.TestCase] = [
            BuiltinTests.TestCase(
                description: "nested object and list",
                name: "yaml.unmarshal",
                args: [
                    """
                    - foo:
                      - 1
                      - 2
                      - 3
                    """
                ],
                expected: .success([["foo": [1, 2, 3]]])
            )
        ]

        static var allTests: [BuiltinTests.TestCase] {
            [
                // yaml.is_valid's documentation states it requires a string, but
                // like OPA, it does not throw on a wrong-typed argument. In those
                // cases it returns false.
                BuiltinTests.generateFailureTests(
                    builtinName: "yaml.is_valid",
                    sampleArgs: [
                        """
                        - 1
                        - 2
                        - 3
                        """
                    ],
                    argIndex: 0, argName: "x",
                    allowedArgTypes: ["undefined", "null", "boolean", "number", "string", "object", "array", "set"],
                    generateNumberOfArgsTest: true),
                BuiltinTests.generateFailureTests(
                    builtinName: "yaml.marshal",
                    sampleArgs: [["x": 2]],
                    argIndex: 0, argName: "x",
                    allowedArgTypes: ["undefined", "boolean", "null", "number", "string", "array", "object", "set"],
                    generateNumberOfArgsTest: true),
                BuiltinTests.generateFailureTests(
                    builtinName: "yaml.unmarshal",
                    sampleArgs: [
                        """
                        - 1
                        - 2
                        - 3
                        """
                    ],
                    argIndex: 0, argName: "x",
                    allowedArgTypes: ["string"],
                    generateNumberOfArgsTest: true),
                yamlIsValidTests,
                yamlMarshalTests,
                yamlUnmarshalTests,
            ].flatMap { $0 }
        }

        @Test(arguments: allTests)
        func testBuiltins(tc: BuiltinTests.TestCase) async throws {
            try await BuiltinTests.testBuiltin(tc: tc)
        }
    }
#endif
