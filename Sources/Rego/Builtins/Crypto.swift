import AST
import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

extension BuiltinFuncs {
    static func sha256Hash(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHash(ctx: ctx, args: args, h: SHA256())
    }

    static func insecureSHA1Hash(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHash(ctx: ctx, args: args, h: Insecure.SHA1())
    }

    static func insecureMD5Hash(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHash(ctx: ctx, args: args, h: Insecure.MD5())
    }

    static func sha256HMAC(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHMAC(ctx: ctx, args: args, h: SHA256())
    }

    static func sha512HMAC(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHMAC(ctx: ctx, args: args, h: SHA512())
    }

    static func insecureSha1HMAC(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHMAC(ctx: ctx, args: args, h: Insecure.SHA1())
    }

    static func insecureMD5HMAC(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doHMAC(ctx: ctx, args: args, h: Insecure.MD5())
    }

    static func hmacsEqual(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "mac1", got: args[0].typeName, want: "string")
        }

        guard case .string(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "mac2", got: args[1].typeName, want: "string")
        }

        return .boolean(x.constantTimeCompare(to: y))
    }

    /// A generic HMAC implementaion given h as a HashFunction
    private static func doHMAC<H: HashFunction>(ctx: BuiltinContext, args: [AST.RegoValue], h: H) throws
        -> AST.RegoValue
    {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard case .string(let key) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "key", got: args[1].typeName, want: "string")
        }

        let sk = SymmetricKey(data: Data(key.utf8))
        let signature = Data(HMAC<H>.authenticationCode(for: Data(x.utf8), using: sk)).hexEncoded

        return .string(signature)
    }

    /// A generic Hash implementaion given h as a HashFunction
    private static func doHash<H: HashFunction>(ctx: BuiltinContext, args: [AST.RegoValue], h: H) throws
        -> AST.RegoValue
    {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        let hash = Data(H.hash(data: Data(x.utf8))).hexEncoded

        return .string(hash)
    }
}

extension String {
    /// Basic constant-time comparison for strings
    /// See https://github.com/apple/swift-nio-ssl/blob/049520bf7d8c0303a70e449aaa49467cf7d29a5d/Sources/NIOSSL/SwiftCrypto/SafeCompare.swift#L17
    fileprivate func constantTimeCompare(to other: String) -> Bool {
        guard self.count == other.count else {
            return false
        }

        return zip(self.utf8, other.utf8).reduce(into: 0) { $0 |= $1.0 ^ $1.1 } == 0
    }
}
