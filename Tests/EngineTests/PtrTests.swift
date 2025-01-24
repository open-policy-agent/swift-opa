import Testing

@testable import Rego

@Suite
struct PtrTests {
    struct SomeStruct {
        var foo: String
        var i: Int
    }

    @Test
    func testPtr() {
        var a = SomeStruct(foo: "bar", i: 42)
        let b = a

        let p = Ptr(toCopyOf: a)
        let p2 = p

        a.foo = "baz"
        #expect(a.foo == "baz")
        #expect(b.foo == "bar")  // was not affected by a

        #expect(p.v.foo == "bar")  // we took ownership of a copy before a was mutated
        #expect(p2.v.foo == "bar")

        p.v.foo = "qux"
        #expect(p2.v.foo == "qux")  // our shared reference is updated
        #expect(a.foo == "baz")  // still detached from our shared reference
    }
}
