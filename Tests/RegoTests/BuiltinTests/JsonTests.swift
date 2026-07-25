import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Objects/JSON", .tags(.builtins))
    struct JsonTests {}
}

extension BuiltinTests.JsonTests {

    // MARK: - json.filter

    static let jsonFilterTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base: keep a single nested path",
            name: "json.filter",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .set(["a/b/c"]),
            ],
            expected: .success(["a": ["b": ["c": 7]]])
        ),
        BuiltinTests.TestCase(
            description: "multiple roots",
            name: "json.filter",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .set(["a/b/c", "e"]),
            ],
            expected: .success(["a": ["b": ["c": 7]], "e": 9])
        ),
        BuiltinTests.TestCase(
            description: "paths given as an array",
            name: "json.filter",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .array(["a/b/c", "e"]),
            ],
            expected: .success(["a": ["b": ["c": 7]], "e": 9])
        ),
        BuiltinTests.TestCase(
            description: "array-form path segments",
            name: "json.filter",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .set([.array(["a", "b", "c"]), .array(["e"])]),
            ],
            expected: .success(["a": ["b": ["c": 7]], "e": 9])
        ),
        BuiltinTests.TestCase(
            description: "conflict: shorter path keeps the whole subtree",
            name: "json.filter",
            args: [
                ["a": ["b": 7]],
                .set(["a", "a/b"]),
            ],
            expected: .success(["a": ["b": 7]])
        ),
        BuiltinTests.TestCase(
            description: "index into arrays",
            name: "json.filter",
            args: [
                ["a": [["b": 7, "c": 8], ["d": 9]]],
                .set(["a/0/b", "a/1"]),
            ],
            expected: .success(["a": [["b": 7], ["d": 9]]])
        ),
        BuiltinTests.TestCase(
            description: "numeric object keys addressed alongside array indexes",
            name: "json.filter",
            args: [
                ["a": [["1": ["b", "c", "d"]], ["x": "y"]]],
                .set(["a/0/1/2"]),
            ],
            expected: .success(["a": [["1": ["d"]]]])
        ),
        BuiltinTests.TestCase(
            description: "escaped path tokens (~1 -> /, ~0 -> ~)",
            name: "json.filter",
            args: [
                ["a/b": ["c~d": 1, "other": 2]],
                .set(["a~1b/c~0d"]),
            ],
            expected: .success(["a/b": ["c~d": 1]])
        ),
        BuiltinTests.TestCase(
            description: "empty path set yields empty object",
            name: "json.filter",
            args: [
                ["a": 7],
                .set([]),
            ],
            expected: .success([:])
        ),
        BuiltinTests.TestCase(
            description: "missing path is ignored on empty object",
            name: "json.filter",
            args: [
                [:],
                .set(["a/b"]),
            ],
            expected: .success([:])
        ),
        BuiltinTests.TestCase(
            description: "keep a member of a nested set",
            name: "json.filter",
            args: [
                ["a": .set(["x", "y"])],
                .set(["a/x"]),
            ],
            expected: .success(["a": .set(["x"])])
        ),
    ]

    // MARK: - json.remove

    static let jsonRemoveTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base: remove a single nested path",
            name: "json.remove",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .set(["a/b/c"]),
            ],
            expected: .success(["a": ["b": ["d": 8]], "e": 9])
        ),
        BuiltinTests.TestCase(
            description: "remove shifts array elements left",
            name: "json.remove",
            args: [
                ["a": [["b": 7, "c": 8], ["d": 9]]],
                .set(["a/0/b", "a/1"]),
            ],
            expected: .success(["a": [["c": 8]]])
        ),
        BuiltinTests.TestCase(
            description: "conflict: removing a parent removes its subtree",
            name: "json.remove",
            args: [
                ["a": ["b": 7], "c": 1],
                .set(["a", "a/b"]),
            ],
            expected: .success(["c": 1])
        ),
        BuiltinTests.TestCase(
            description: "remove all top-level keys",
            name: "json.remove",
            args: [
                ["a": ["b": 7], "c": 1],
                .set(["a", "c"]),
            ],
            expected: .success([:])
        ),
        BuiltinTests.TestCase(
            description: "empty path set leaves object unchanged",
            name: "json.remove",
            args: [
                ["a": 7],
                .set([]),
            ],
            expected: .success(["a": 7])
        ),
        BuiltinTests.TestCase(
            description: "array-form path segments",
            name: "json.remove",
            args: [
                ["a": ["b": ["c": 7, "d": 8]], "e": 9],
                .set([.array(["a", "b", "c"]), .array(["e"])]),
            ],
            expected: .success(["a": ["b": ["d": 8]]])
        ),
        BuiltinTests.TestCase(
            description: "remove a member of a nested set",
            name: "json.remove",
            args: [
                ["a": .set(["x", "y"])],
                .set(["a/x"]),
            ],
            expected: .success(["a": .set(["y"])])
        ),
        BuiltinTests.TestCase(
            description: "removing the last key leaves an empty object, not a removed parent",
            name: "json.remove",
            args: [
                ["a": ["b": 7], "c": 1],
                .set(["a/b"]),
            ],
            expected: .success(["a": [:], "c": 1])
        ),
        BuiltinTests.TestCase(
            description: "path that does not exist is a no-op",
            name: "json.remove",
            args: [
                ["a": 1],
                .set(["z/y"]),
            ],
            expected: .success(["a": 1])
        ),
    ]

    // MARK: - json.patch

    static let jsonPatchTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "add: new object member",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "add", "path": "/b", "value": 2]]),
            ],
            expected: .success(["a": 1, "b": 2])
        ),
        BuiltinTests.TestCase(
            description: "add: insert into array shifts right",
            name: "json.patch",
            args: [
                ["a": [1, 2, 3]],
                .array([["op": "add", "path": "/a/1", "value": 9]]),
            ],
            expected: .success(["a": [1, 9, 2, 3]])
        ),
        BuiltinTests.TestCase(
            description: "add: append to array with '-'",
            name: "json.patch",
            args: [
                ["a": [1, 2]],
                .array([["op": "add", "path": "/a/-", "value": 3]]),
            ],
            expected: .success(["a": [1, 2, 3]])
        ),
        BuiltinTests.TestCase(
            description: "remove: object member",
            name: "json.patch",
            args: [
                ["a": 1, "b": 2],
                .array([["op": "remove", "path": "/a"]]),
            ],
            expected: .success(["b": 2])
        ),
        BuiltinTests.TestCase(
            description: "replace: overwrite existing value",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "replace", "path": "/a", "value": 2]]),
            ],
            expected: .success(["a": 2])
        ),
        BuiltinTests.TestCase(
            description: "replace: empty path replaces whole document",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "replace", "path": "", "value": "x"]]),
            ],
            expected: .success("x")
        ),
        BuiltinTests.TestCase(
            description: "move: relocate a value",
            name: "json.patch",
            args: [
                ["a": 1, "b": 2],
                .array([["op": "move", "from": "/a", "path": "/c"]]),
            ],
            expected: .success(["b": 2, "c": 1])
        ),
        BuiltinTests.TestCase(
            description: "copy: duplicate a value",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "copy", "from": "/a", "path": "/b"]]),
            ],
            expected: .success(["a": 1, "b": 1])
        ),
        BuiltinTests.TestCase(
            description: "test: matching value leaves document unchanged",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "test", "path": "/a", "value": 1]]),
            ],
            expected: .success(["a": 1])
        ),
        BuiltinTests.TestCase(
            description: "sequential operations apply in order",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([
                    ["op": "add", "path": "/b", "value": 2],
                    ["op": "remove", "path": "/a"],
                ]),
            ],
            expected: .success(["b": 2])
        ),
        BuiltinTests.TestCase(
            description: "escaped path token addresses a key containing '/'",
            name: "json.patch",
            args: [
                ["a/b": 1, "c": 2],
                .array([["op": "remove", "path": "/a~1b"]]),
            ],
            expected: .success(["c": 2])
        ),
        BuiltinTests.TestCase(
            description: "add into a set requires the segment to equal the value",
            name: "json.patch",
            args: [
                .set(["a", "b"]),
                .array([["op": "add", "path": "/c", "value": "c"]]),
            ],
            expected: .success(.set(["a", "b", "c"]))
        ),
        BuiltinTests.TestCase(
            description: "remove from a set",
            name: "json.patch",
            args: [
                .set(["a", "b"]),
                .array([["op": "remove", "path": "/a"]]),
            ],
            expected: .success(.set(["b"]))
        ),
        BuiltinTests.TestCase(
            description: "replace: overwrite an array element in place",
            name: "json.patch",
            args: [
                ["a": [1, 2, 3]],
                .array([["op": "replace", "path": "/a/1", "value": 9]]),
            ],
            expected: .success(["a": [1, 9, 3]])
        ),
        BuiltinTests.TestCase(
            description: "remove: array element shifts the rest left",
            name: "json.patch",
            args: [
                ["a": [1, 2, 3]],
                .array([["op": "remove", "path": "/a/1"]]),
            ],
            expected: .success(["a": [1, 3]])
        ),
        BuiltinTests.TestCase(
            description: "add: integer index equal to the length appends",
            name: "json.patch",
            args: [
                ["a": [1, 2]],
                .array([["op": "add", "path": "/a/2", "value": 3]]),
            ],
            expected: .success(["a": [1, 2, 3]])
        ),
        BuiltinTests.TestCase(
            description: "add: empty path replaces the whole document",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "add", "path": "", "value": "z"]]),
            ],
            expected: .success("z")
        ),
        BuiltinTests.TestCase(
            description: "add: array-form path with a numeric segment",
            name: "json.patch",
            args: [
                ["a": [1, 2]],
                .array([["op": "add", "path": .array(["a", 1]), "value": 9]]),
            ],
            expected: .success(["a": [1, 9, 2]])
        ),
        BuiltinTests.TestCase(
            description: "target may be a top-level array",
            name: "json.patch",
            args: [
                .array([1, 2, 3]),
                .array([["op": "add", "path": "/1", "value": 9]]),
            ],
            expected: .success(.array([1, 9, 2, 3]))
        ),
        BuiltinTests.TestCase(
            description: "move within an array",
            name: "json.patch",
            args: [
                ["a": [1, 2, 3]],
                .array([["op": "move", "from": "/a/0", "path": "/a/2"]]),
            ],
            expected: .success(["a": [2, 3, 1]])
        ),
        BuiltinTests.TestCase(
            description: "copy appends into an array",
            name: "json.patch",
            args: [
                ["a": 1, "b": [10]],
                .array([["op": "copy", "from": "/a", "path": "/b/-"]]),
            ],
            expected: .success(["a": 1, "b": [10, 1]])
        ),
        BuiltinTests.TestCase(
            description: "test: matching value on a nested path",
            name: "json.patch",
            args: [
                ["a": ["b": 1]],
                .array([["op": "test", "path": "/a/b", "value": 1]]),
            ],
            expected: .success(["a": ["b": 1]])
        ),
        BuiltinTests.TestCase(
            description: "test: matching whole document via empty path",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "test", "path": "", "value": ["a": 1]]]),
            ],
            expected: .success(["a": 1])
        ),
    ]

    // MARK: - json.patch failures (surface as errors under strict mode)

    static let jsonPatchFailureTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "test: mismatched value fails",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "test", "path": "/a", "value": 2]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: test operation failed"))
        ),
        BuiltinTests.TestCase(
            description: "add: array index out of bounds",
            name: "json.patch",
            args: [
                ["a": [1]],
                .array([["op": "add", "path": "/a/5", "value": 9]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: array index out of bounds"))
        ),
        BuiltinTests.TestCase(
            description: "remove: non-canonical array index with leading zero",
            name: "json.patch",
            args: [
                ["a": [1, 2]],
                .array([["op": "remove", "path": "/a/01"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: invalid array index '01'"))
        ),
        BuiltinTests.TestCase(
            description: "add: missing required 'value' attribute",
            name: "json.patch",
            args: [
                [:],
                .array([["op": "add", "path": "/a"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: missing required attribute 'value'"))
        ),
        BuiltinTests.TestCase(
            description: "missing required 'path' attribute",
            name: "json.patch",
            args: [
                [:],
                .array([["op": "add", "value": 1]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: missing required attribute 'path'"))
        ),
        BuiltinTests.TestCase(
            description: "unrecognized op",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "frobnicate", "path": "/a"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: unrecognized op: 'frobnicate'"))
        ),
        BuiltinTests.TestCase(
            description: "remove: path does not exist",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "remove", "path": "/missing"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: path does not exist"))
        ),
        BuiltinTests.TestCase(
            description: "add into a set: segment must equal the value",
            name: "json.patch",
            args: [
                .set(["a"]),
                .array([["op": "add", "path": "/b", "value": "c"]]),
            ],
            expected: .failure(
                BuiltinError.evalError(msg: "json.patch: set element must equal the path segment"))
        ),
        BuiltinTests.TestCase(
            description: "move: missing required 'from' attribute",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": "move", "path": "/b"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: missing required attribute 'from'"))
        ),
        BuiltinTests.TestCase(
            description: "op attribute is not a string",
            name: "json.patch",
            args: [
                ["a": 1],
                .array([["op": 1, "path": "/a"]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: attribute 'op' must be a string"))
        ),
        BuiltinTests.TestCase(
            description: "operation element is not an object",
            name: "json.patch",
            args: [
                ["a": 1],
                .array(["not-an-op"]),
            ],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "json.patch: must be an array of JSON-Patch objects, but at least one element is not an object"
                ))
        ),
        BuiltinTests.TestCase(
            description: "add: float array index is invalid",
            name: "json.patch",
            args: [
                ["a": [1, 2]],
                .array([["op": "add", "path": .array(["a", 1.5]), "value": 9]]),
            ],
            expected: .failure(BuiltinError.evalError(msg: "json.patch: invalid array index"))
        ),
    ]

    // MARK: - invalid argument types

    static let jsonFilterArgErrorTests: [BuiltinTests.TestCase] =
        BuiltinTests.generateFailureTests(
            builtinName: "json.filter",
            sampleArgs: [["a": 1], .set(["a"])],
            argIndex: 0,
            argName: "object",
            allowedArgTypes: ["object"],
            generateNumberOfArgsTest: true
        )
        + BuiltinTests.generateFailureTests(
            builtinName: "json.filter",
            sampleArgs: [["a": 1], .set(["a"])],
            argIndex: 1,
            argName: "paths",
            allowedArgTypes: ["array", "set"]
        )
        + [
            // A valid container holding an invalid path element isn't expressible via
            // generateFailureTests, so cover it explicitly.
            BuiltinTests.TestCase(
                description: "paths element has wrong type",
                name: "json.filter",
                args: [["a": 1], .set([.number(1)])],
                expected: .failure(
                    BuiltinError.evalError(
                        msg:
                            "json.filter: operand 2 must be one of {set, array} containing string paths or arrays of path segments but got number"
                    ))
            )
        ]

    static let jsonRemoveArgErrorTests: [BuiltinTests.TestCase] =
        BuiltinTests.generateFailureTests(
            builtinName: "json.remove",
            sampleArgs: [["a": 1], .set(["a"])],
            argIndex: 0,
            argName: "object",
            allowedArgTypes: ["object"],
            generateNumberOfArgsTest: true
        )
        + BuiltinTests.generateFailureTests(
            builtinName: "json.remove",
            sampleArgs: [["a": 1], .set(["a"])],
            argIndex: 1,
            argName: "paths",
            allowedArgTypes: ["array", "set"]
        )

    static let jsonPatchArgErrorTests: [BuiltinTests.TestCase] =
        BuiltinTests.generateFailureTests(
            builtinName: "json.patch",
            sampleArgs: [["a": 1], .array([])],
            argIndex: 1,
            argName: "patches",
            allowedArgTypes: ["array"],
            generateNumberOfArgsTest: true
        )

    static var allTests: [BuiltinTests.TestCase] {
        [
            jsonFilterTests,
            jsonRemoveTests,
            jsonPatchTests,
            jsonPatchFailureTests,
            jsonFilterArgErrorTests,
            jsonRemoveArgErrorTests,
            jsonPatchArgErrorTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
