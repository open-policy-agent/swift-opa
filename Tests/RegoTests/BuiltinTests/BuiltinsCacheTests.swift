import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinsCacheTests")
struct BuiltinsCacheTests {
    @Test("caching items with the same keys but different namespaces")
    func cachesDifferentNamespacesAsDifferentEntries() {
        var cache = BuiltinsCache()

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
        var cache = BuiltinsCache()
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
}
