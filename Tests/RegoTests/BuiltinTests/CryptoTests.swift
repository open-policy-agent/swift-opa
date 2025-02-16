import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Crypto", .tags(.builtins))
    struct CryptoTests {}
}

extension BuiltinTests.CryptoTests {
    static let sha256HashTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "digests empty string",
            name: "crypto.sha256",
            args: [""],
            expected: .success(.string("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
        ),
        BuiltinTests.TestCase(
            description: "digests a string",
            name: "crypto.sha256",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("16aba5393ad72c0041f5600ad3c2c52ec437a2f0c7fc08fadfc3c0fe9641d7a3"))
        ),
    ]

    static let sha256HMACTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "hmacs empty string with empty key",
            name: "crypto.hmac.sha256",
            args: ["", ""],
            expected: .success(.string("b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad"))
        ),
        BuiltinTests.TestCase(
            description: "hmacs empty string with key",
            name: "crypto.hmac.sha256",
            args: ["", "secret key"],
            expected: .success(.string("ddfa2483361fb35202689547ae9dab34aa34dca48cb3cb8611f6982fdf8088a0"))
        ),
        BuiltinTests.TestCase(
            description: "hmacs a string",
            name: "crypto.hmac.sha256",
            args: ["Lorem ipsum dolor sit amet", "secret key"],
            expected: .success(.string("84e5db6f55117aa18c300ac63f08793761d5a59d331a8543b71fcf4c836a0991"))
        ),
    ]

    static let sha512HMACTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "hmacs empty string with empty key",
            name: "crypto.hmac.sha512",
            args: ["", ""],
            expected: .success(
                .string(
                    "b936cee86c9f87aa5d3c6f2e84cb5a4239a5fe50480a6ec66b70ab5b1f4ac6730c6c515421b327ec1d69402e53dfb49ad7381eb067b338fd7b0cb22247225d47"
                ))
        ),
        BuiltinTests.TestCase(
            description: "hmacs empty string with key",
            name: "crypto.hmac.sha512",
            args: ["", "secret key"],
            expected: .success(
                .string(
                    "481a9fc7b98764c270445f5ff18f46a5d0d183d32b85d87f24186c94150aa9beaf85a1e91c478e4ec082d26348ac3e837305c02828ccbe011c297e0fdee23a84"
                ))
        ),
        BuiltinTests.TestCase(
            description: "hmacs a string",
            name: "crypto.hmac.sha512",
            args: ["Lorem ipsum dolor sit amet", "secret key"],
            expected: .success(
                .string(
                    "9c355942346ea32aadff7a5362c8ea000094d3950cf4ca8f83f8140e3d846e0ed6f4263fa86b2e320a8cf149ac2ce6e497f2de7e2e8d33e189505f41cbb15371"
                ))
        ),
    ]

    static let hmacEqualityTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "two empty hmacs are equal",
            name: "crypto.hmac.equal",
            args: ["", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "hmacs of different lengths are not equal",
            name: "crypto.hmac.equal",
            args: ["9c355942346", "9c355942346ea"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "different hmacs of same lengths are not equal",
            name: "crypto.hmac.equal",
            args: [
                "16aba5393ad72c0041f5600ad3c2c52ec437a2f0c7fc08fadfc3c0fe9641d7a3",
                "b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
            ],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "same hmacs of same lengths are equal",
            name: "crypto.hmac.equal",
            args: [
                "16aba5393ad72c0041f5600ad3c2c52ec437a2f0c7fc08fadfc3c0fe9641d7a3",
                "16aba5393ad72c0041f5600ad3c2c52ec437a2f0c7fc08fadfc3c0fe9641d7a3",
            ],
            expected: .success(true)
        ),
    ]

    static let insecureTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "digests a string",
            name: "crypto.md5",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("fea80f2db003d4ebc4536023814aa885"))
        ),
        BuiltinTests.TestCase(
            description: "digests a string",
            name: "crypto.sha1",
            args: ["Lorem ipsum dolor sit amet"],
            expected: .success(.string("38f00f8738e241daea6f37f6f55ae8414d7b0219"))
        ),
        BuiltinTests.TestCase(
            description: "hmacs a string",
            name: "crypto.hmac.md5",
            args: ["Lorem ipsum dolor sit amet", "secret key"],
            expected: .success(.string("a99535dcf3ddf56a01abfc0191de1f91"))
        ),
        BuiltinTests.TestCase(
            description: "hmacs a string",
            name: "crypto.hmac.sha1",
            args: ["Lorem ipsum dolor sit amet", "secret key"],
            expected: .success(.string("6186f4c71326245bbd8f7a71e6ffec89f4ff4b67"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "crypto.sha256", sampleArgs: ["x"],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            sha256HashTests,

            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.sha256", sampleArgs: ["x", "key"],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.sha256", sampleArgs: ["x", "key"],
                argIndex: 1, argName: "key",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false),
            sha256HMACTests,

            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.sha512", sampleArgs: ["x", "key"],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.sha512", sampleArgs: ["x", "key"],
                argIndex: 1, argName: "key",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false),
            sha512HMACTests,

            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.equal", sampleArgs: ["mac1", "mac2"],
                argIndex: 0, argName: "mac1",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "crypto.hmac.equal", sampleArgs: ["mac1", "mac2"],
                argIndex: 1, argName: "mac2",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false),
            hmacEqualityTests,

            insecureTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
