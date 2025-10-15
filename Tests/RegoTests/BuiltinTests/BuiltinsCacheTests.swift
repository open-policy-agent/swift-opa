import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinsCacheTests", .tags(.builtins))
    struct BuiltinsCacheTests {}
}

extension BuiltinTests.BuiltinsCacheTests {
    @Test("caching items with the same keys but different namespaces")
    func cachesDifferentNamespacesAsDifferentEntries() {
        let cache = BuiltinsCache()

        // Set a value in the implied global namespace
        cache["3!"] = 6

        // Verify another namespace with the same key has no value (yet)
        let y = cache["3!", .namespace("Other")]
        #expect(y == nil)

        // Now set a value with the same key in another namespace
        cache["3!", .namespace("Other")] = "something else"

        // The implied global namespace has the original value we set above
        let x: RegoValue? = cache["3!"]
        #expect(x == .number(6))

        // And the other namespace with the same key has its own value
        let yy: RegoValue? = cache["3!", .namespace("Other")]
        #expect(yy == .string("something else"))

        // Verify the original (implied namespace) value landed in the global namespace
        let x2 = cache["3!", .global]
        #expect(x2 == .number(6))
    }

    @Test("cache removal and counting")
    func testRemoval() {
        let cache = BuiltinsCache()
        cache["3!"] = 6
        #expect(cache.count == 1)

        cache["4!"] = 24
        #expect(cache.count == 2)

        cache["4!"] = nil
        #expect(cache.count == 1)

        #expect(cache["4!"] == nil)

        cache.removeAll()
        #expect(cache["3!"] == nil)
        #expect(cache.count == 0)
    }

    static let cacheKey = "test_key"
    static let builtinRegistry: BuiltinRegistry =
        .init(
            builtins: [
                "custom_cache_builtin_1": { ctx, args in
                    guard args.count == 1 else {
                        throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
                    }

                    // Write to builtin cache
                    ctx.cache[Self.cacheKey] = args[0]
                    // Read from builtin cache
                    let cacheEntry = try #require(ctx.cache[Self.cacheKey], "Expected entry is not present in cache")

                    return cacheEntry
                },
                "custom_cache_builtin_2": { ctx, args in
                    // Read from builtin cache
                    let value = try #require(ctx.cache[Self.cacheKey], "Expected entry is not present in cache")
                    // Reset entry
                    ctx.cache[Self.cacheKey] = nil
                    return value
                }
            ]
        )

    @Test("Shared cache across builtin evals")
    func test() async throws {
        // One builtin cache that is handed to both builtins
        let cache = BuiltinsCache()
        // Dummy value in cache
        let testCacheValue: RegoValue = .string("test_value")

        let result1 = await Result {
            try await Self.builtinRegistry.invoke(
                withContext: BuiltinContext(cache: cache),
                name: "custom_cache_builtin_1",
                args: [testCacheValue],
                strict: true
            )
        }
        try #expect(result1.get() == testCacheValue)
        #expect(cache.count == 1)
        #expect(cache[Self.cacheKey] == testCacheValue)

        let result2 = await Result {
            try await Self.builtinRegistry.invoke(
                withContext: BuiltinContext(cache: cache),
                name: "custom_cache_builtin_2",
                args: [testCacheValue],
                strict: true
            )
        }
        try #expect(result2.get() == testCacheValue)
        #expect(cache.count == 0)
        #expect(cache[Self.cacheKey] == nil)
    }
}
