import AST
import Foundation

// Path-based JSON builtins from the "object" category: json.filter, json.remove and
// json.patch. (json.marshal / json.unmarshal / json.is_valid live in Encoding.swift.)
//
// None of these functions parse JSON text. They operate on the already-decoded
// AST.RegoValue tree. The only "JSON" aspect is the JSON-Pointer-style path syntax
// (RFC6901) used to address nested locations, and RFC6902 JSON-Patch for json.patch.
extension BuiltinFuncs {

    // MARK: - json.filter

    // filter returns a new object containing only the paths of the input object named
    // in the second argument. Paths that don't exist in the object are ignored. A path
    // that names an interior node keeps that entire subtree.
    //
    // e.g. json.filter({"a": {"b": 1, "c": 2}}, {"a/b"}) => {"a": {"b": 1}}
    //
    // args
    // object (object[any: any]) - object to filter
    // paths (any<array[any], set[any]>) - JSON string paths, or arrays of path segments
    // returns: filtered (any) - remaining data from object with only the paths specified
    static func jsonFilter(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let paths = try getJSONPaths(args[1], builtinName: "json.filter")
        let filterTree = pathsToObject(paths)
        return filterValue(args[0], filterTree)
    }

    // MARK: - json.remove

    // remove returns a new object with the named paths removed from the input object.
    // Paths that don't exist are ignored. Removing an interior node removes its subtree.
    //
    // e.g. json.remove({"a": {"b": 1, "c": 2}}, {"a/b"}) => {"a": {"c": 2}}
    //
    // args
    // object (object[any: any]) - object to remove paths from
    // paths (any<array[any], set[any]>) - JSON string paths, or arrays of path segments
    // returns: output (any) - result of removing the specified paths from object
    static func jsonRemove(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let paths = try getJSONPaths(args[1], builtinName: "json.remove")
        let removeTree = pathsToObject(paths)
        // The top-level input is an object, so the recursive walk always returns a value.
        return jsonRemoveWalk(args[0], removeTree) ?? args[0]
    }

    // MARK: - json.patch

    // patch applies a sequence of RFC6902 JSON-Patch operations to the target value.
    // The target may be an object, array, set, or scalar. Any operation failure (bad
    // path, missing attribute, failed "test", unknown op) raises an evaluation error,
    // which surfaces as an undefined result under the default (non-strict) builtin mode.
    //
    // e.g. json.patch({"a": 1}, [{"op": "add", "path": "/b", "value": 2}]) => {"a": 1, "b": 2}
    //
    // args
    // object (any) - the object, array or set to patch
    // patches (array[object]) - the JSON patch operations to apply
    // returns: output (any) - the patched value
    static func jsonPatch(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .array(let operations) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "patches", got: args[1].typeName, want: "array")
        }

        return try applyPatches(args[0], operations)
    }

    // MARK: - Shared path parsing

    // getJSONPaths converts the "paths" argument of json.filter/json.remove into a list
    // of parsed paths, one per element. The argument must be an array or set; each
    // element is a single path that parsePath splits into segments.
    //
    // Both builtins accept the same paths argument, so they share this one entry point
    // for validating its shape and normalizing every element into segment lists.
    //
    // e.g. {"a/b", ["c", "d"]} => [[.string("a"), .string("b")], [.string("c"), .string("d")]]
    private static func getJSONPaths(_ operand: AST.RegoValue, builtinName: String) throws -> [[AST.RegoValue]] {
        let elements: [AST.RegoValue]
        switch operand {
        case .array(let arr):
            elements = arr
        case .set(let set):
            elements = Array(set)
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "paths", got: operand.typeName, want: "any<array, set>")
        }

        return try elements.map { try parsePath($0, builtinName: builtinName) }
    }

    // parsePath splits a single path into its segments. A path is either a "/"-separated
    // JSON pointer string, or an array whose elements are already the segments. For a
    // string, a leading "/" is optional and each segment is unescaped per RFC6901
    // ("~1" -> "/", then "~0" -> "~"). An empty string is the empty (root) path.
    //
    // All three builtins address nested locations by path, so this is the one place that
    // turns a path (whichever form the caller wrote) into segments: getJSONPaths calls it
    // per element, and json.patch calls it for each op's "path" and "from".
    //
    // e.g. "/a/b"   => [.string("a"), .string("b")]
    //      "a~1b/c" => [.string("a/b"), .string("c")]
    //      ["a", 0] => [.string("a"), .number(0)]
    //      ""       => []
    private static func parsePath(_ path: AST.RegoValue, builtinName: String) throws -> [AST.RegoValue] {
        switch path {
        case .string(let s):
            if s.isEmpty {
                return []
            }
            // Drop all leading '/' characters, then split on '/'.
            let trimmed = s.drop(while: { $0 == "/" })
            let segments = trimmed.split(separator: "/", omittingEmptySubsequences: false)
            return segments.map { .string(unescapePointerToken(String($0))) }
        case .array(let segments):
            // Array-form paths take their segments verbatim (they may be non-strings).
            return segments
        default:
            throw BuiltinError.evalError(
                msg:
                    "\(builtinName): operand 2 must be one of {set, array} containing string paths or arrays of path segments but got \(path.typeName)"
            )
        }
    }

    // unescapePointerToken decodes one RFC6901 path token: "~1" becomes "/", then "~0"
    // becomes "~". The order matters so that "~01" decodes to "~1" rather than "/".
    //
    // Called by parsePath on each segment of a string path, so that a key containing "/"
    // or "~" can still be addressed (it's written escaped in the pointer).
    //
    // e.g. "a~1b" => "a/b",  "~0" => "~"
    private static func unescapePointerToken(_ token: String) -> String {
        return token.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
    }

    // pathsToObject merges a list of parsed paths into one tree that filterValue and
    // jsonRemoveWalk later walk against. The tree mirrors the paths as nested objects,
    // with a .null leaf marking the end of each path (the location it addresses).
    //
    // json.filter and json.remove are given many independent paths but want to process
    // the input in a single pass. Collapsing the paths into one tree up front lets each
    // builtin walk the input and the tree together, instead of re-scanning per path (and
    // it resolves overlaps like "a" vs "a/b" once, here).
    //
    // When one path ends at a location, any longer path passing through it is dropped:
    // the shorter path already selects that whole subtree.
    //
    // e.g. ["a/b/c", "a/b/d", "e"] => {"a": {"b": {"c": null, "d": null}}, "e": null}
    //      ["a", "a/b"]            => {"a": null}   (the longer path is subsumed)
    private static func pathsToObject(_ paths: [[AST.RegoValue]]) -> AST.RegoValue {
        var root: [AST.RegoValue: AST.RegoValue] = [:]
        for path in paths where !path.isEmpty {
            insertNullLeaf(into: &root, path: path[...])
        }
        return .object(root)
    }

    // insertNullLeaf adds one path to the tree rooted at node, creating intermediate
    // objects along the way and marking the final segment with .null. If the path runs
    // into a .null leaf left by a shorter path, it stops — that path already covers this
    // location.
    //
    // This is pathsToObject's per-path step; it exists to keep the recursive merge (and
    // the overlap handling) separate from the loop that feeds it each path.
    private static func insertNullLeaf(into node: inout [AST.RegoValue: AST.RegoValue], path: ArraySlice<AST.RegoValue>)
    {
        guard let head = path.first else {
            return
        }
        let rest = path.dropFirst()
        if rest.isEmpty {
            // Leaf: mark this location for keep/remove, overwriting any deeper subtree.
            node[head] = .null
            return
        }
        switch node[head] {
        case .some(.null):
            // A shorter path already claimed this node; nothing deeper matters.
            return
        case .some(.object(var child)):
            insertNullLeaf(into: &child, path: rest)
            node[head] = .object(child)
        default:
            var child: [AST.RegoValue: AST.RegoValue] = [:]
            insertNullLeaf(into: &child, path: rest)
            node[head] = .object(child)
        }
    }

    // MARK: - filter / remove tree walks

    // filterValue produces the json.filter result: the parts of value selected by the
    // filter tree (from pathsToObject), walking the two in step. A .null filter node keeps
    // value whole; an object filter node keeps only the children it names and recurses
    // into each.
    //
    // e.g. value  {"a": {"b": 1, "c": 2}, "d": 3}
    //      filter {"a": {"b": null}}
    //      result {"a": {"b": 1}}
    private static func filterValue(_ value: AST.RegoValue, _ filter: AST.RegoValue) -> AST.RegoValue {
        guard case .object(let filterObj) = filter else {
            // .null (or any non-object) filter node keeps the entire value.
            return value
        }
        switch value {
        case .object(let obj):
            var out: [AST.RegoValue: AST.RegoValue] = [:]
            for (key, child) in obj {
                if let sub = filterObj[key] {
                    out[key] = filterValue(child, sub)
                }
            }
            return .object(out)
        case .array(let arr):
            var out: [AST.RegoValue] = []
            for (i, child) in arr.enumerated() {
                if let sub = filterObj[.string(String(i))] {
                    out.append(filterValue(child, sub))
                }
            }
            return .array(out)
        case .set(let set):
            var out: Set<AST.RegoValue> = []
            for member in set {
                if let sub = filterObj[member] {
                    out.insert(filterValue(member, sub))
                }
            }
            return .set(out)
        default:
            return value
        }
    }

    // jsonRemoveWalk produces the json.remove result: value with the locations named by
    // the remove tree removed, or nil to tell the caller to drop value entirely.
    //
    // filter is the remove-tree node matching value's location:
    //   - nil: no path reaches here, so keep value unchanged.
    //   - .null: a path ends here, so remove value (return nil).
    //   - .object: recurse into the children of value that the node names.
    //
    // When a recursive call returns nil, the object/set/array caller omits that child.
    //
    // e.g. value  {"a": {"b": 1, "c": 2}, "d": 3}
    //      filter {"a": {"b": null}}
    //      result {"a": {"c": 2}, "d": 3}
    private static func jsonRemoveWalk(_ value: AST.RegoValue, _ filter: AST.RegoValue?) -> AST.RegoValue? {
        guard let filter else {
            // No path reaches here: keep it as-is.
            return value
        }
        guard case .object(let filterObj) = filter else {
            if case .null = filter {
                // A path ends here: drop this value.
                return nil
            }
            return value
        }
        switch value {
        case .object(let obj):
            var out: [AST.RegoValue: AST.RegoValue] = [:]
            for (key, child) in obj {
                if let kept = jsonRemoveWalk(child, filterObj[key]) {
                    out[key] = kept
                }
            }
            return .object(out)
        case .set(let set):
            var out: Set<AST.RegoValue> = []
            for member in set {
                if let kept = jsonRemoveWalk(member, filterObj[member]) {
                    out.insert(kept)
                }
            }
            return .set(out)
        case .array(let arr):
            // Removing an element shifts the remaining elements left, per the JSON patch spec.
            var out: [AST.RegoValue] = []
            for (i, child) in arr.enumerated() {
                if let kept = jsonRemoveWalk(child, filterObj[.string(String(i))]) {
                    out.append(kept)
                }
            }
            return .array(out)
        default:
            return value
        }
    }

    // MARK: - patch application

    // applyPatches is the body of json.patch: it applies operations to target in order and
    // returns the patched value. Each operation is an object with a string "op" (add,
    // remove, replace, move, copy, or test) and a "path"; add/replace/test also require
    // "value", and move/copy require "from". A malformed operation, a missing attribute, or
    // a failed "test" throws. It's split out from jsonPatch so the fold over operations
    // stays separate from argument validation.
    //
    // e.g. target {"a": 1}
    //      ops    [{"op": "add", "path": "/b", "value": 2}, {"op": "remove", "path": "/a"}]
    //      result {"b": 2}
    private static func applyPatches(_ target: AST.RegoValue, _ operations: [AST.RegoValue]) throws -> AST.RegoValue {
        var working = target

        for operation in operations {
            guard case .object(let op) = operation else {
                throw BuiltinError.evalError(
                    msg: "json.patch: must be an array of JSON-Patch objects, but at least one element is not an object"
                )
            }

            guard let pathTerm = op[.string("path")] else {
                throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'path'")
            }
            guard let opTerm = op[.string("op")] else {
                throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'op'")
            }
            guard case .string(let opName) = opTerm else {
                throw BuiltinError.evalError(msg: "json.patch: attribute 'op' must be a string")
            }

            let path = try parsePath(pathTerm, builtinName: "json.patch")

            switch opName {
            case "add":
                guard let value = op[.string("value")] else {
                    throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'value'")
                }
                working = try insertAtPath(working, path[...], value)
            case "remove":
                working = try removeAtPath(working, path[...])
            case "replace":
                guard let value = op[.string("value")] else {
                    throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'value'")
                }
                if path.isEmpty {
                    working = value
                } else {
                    // Delete-then-insert gives overwrite semantics and enforces that the
                    // target location already exists.
                    let removed = try removeAtPath(working, path[...])
                    working = try insertAtPath(removed, path[...], value)
                }
            case "move":
                guard let fromTerm = op[.string("from")] else {
                    throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'from'")
                }
                let from = try parsePath(fromTerm, builtinName: "json.patch")
                let chunk = try getAtPath(working, from[...])
                let removed = try removeAtPath(working, from[...])
                working = try insertAtPath(removed, path[...], chunk)
            case "copy":
                guard let fromTerm = op[.string("from")] else {
                    throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'from'")
                }
                let from = try parsePath(fromTerm, builtinName: "json.patch")
                let chunk = try getAtPath(working, from[...])
                working = try insertAtPath(working, path[...], chunk)
            case "test":
                guard let value = op[.string("value")] else {
                    throw BuiltinError.evalError(msg: "json.patch: missing required attribute 'value'")
                }
                let current = try getAtPath(working, path[...])
                guard current == value else {
                    throw BuiltinError.evalError(msg: "json.patch: test operation failed")
                }
            default:
                throw BuiltinError.evalError(msg: "json.patch: unrecognized op: '\(opName)'")
            }
        }

        return working
    }

    // getAtPath returns the value reached by following path from value, or throws if any
    // segment doesn't exist. An empty path returns value itself.
    //
    // applyPatches uses it for the ops that read a location before changing anything:
    // "move"/"copy" read the "from" value to relocate, and "test" reads the value to
    // compare against.
    //
    // e.g. value {"a": [10, 20]}, path ["a", "1"] => 20
    private static func getAtPath(_ value: AST.RegoValue, _ path: ArraySlice<AST.RegoValue>) throws -> AST.RegoValue {
        guard let head = path.first else {
            return value
        }
        let rest = path.dropFirst()
        switch value {
        case .object(let obj):
            guard let child = obj[head] else {
                throw BuiltinError.evalError(msg: "json.patch: path does not exist")
            }
            return try getAtPath(child, rest)
        case .array(let arr):
            let index = try arrayIndex(head, count: arr.count, allowEnd: false)
            return try getAtPath(arr[index], rest)
        case .set(let set):
            guard set.contains(head) else {
                throw BuiltinError.evalError(msg: "json.patch: path does not exist")
            }
            return try getAtPath(head, rest)
        default:
            throw BuiltinError.evalError(msg: "json.patch: path does not exist")
        }
    }

    // removeAtPath returns a copy of value with the element at path removed, or throws if
    // the location doesn't exist. Removing an array element shifts later elements left.
    //
    // applyPatches uses it for "remove", for "replace" (delete-then-insert, which also
    // makes replace fail when the target is missing), and for "move" (deleting the value
    // from its "from" location before re-inserting it).
    //
    // e.g. value {"a": [10, 20, 30]}, path ["a", "1"] => {"a": [10, 30]}
    private static func removeAtPath(_ value: AST.RegoValue, _ path: ArraySlice<AST.RegoValue>) throws -> AST.RegoValue
    {
        guard let head = path.first else {
            throw BuiltinError.evalError(msg: "json.patch: cannot remove root document")
        }
        let rest = path.dropFirst()
        let isLeaf = rest.isEmpty

        switch value {
        case .object(var obj):
            guard obj[head] != nil else {
                throw BuiltinError.evalError(msg: "json.patch: path does not exist")
            }
            if isLeaf {
                obj[head] = nil
            } else {
                obj[head] = try removeAtPath(obj[head]!, rest)
            }
            return .object(obj)
        case .array(var arr):
            let index = try arrayIndex(head, count: arr.count, allowEnd: false)
            if isLeaf {
                arr.remove(at: index)
            } else {
                arr[index] = try removeAtPath(arr[index], rest)
            }
            return .array(arr)
        case .set(var set):
            guard set.contains(head) else {
                throw BuiltinError.evalError(msg: "json.patch: path does not exist")
            }
            set.remove(head)
            if !isLeaf {
                set.insert(try removeAtPath(head, rest))
            }
            return .set(set)
        default:
            throw BuiltinError.evalError(msg: "json.patch: path does not exist")
        }
    }

    // insertAtPath returns a copy of value with newValue placed at path, or throws if the
    // parent location doesn't exist. An empty path replaces value outright. In an array,
    // "-" appends and an integer index inserts before that position (shifting later
    // elements right); in a set, the final segment must equal newValue.
    //
    // applyPatches uses it to write a value into place: "add", "replace" (the insert half
    // of delete-then-insert), and the destination of "move"/"copy".
    //
    // e.g. value {"a": [10, 20]}, path ["a", "1"], newValue 15 => {"a": [10, 15, 20]}
    //      value {"a": [10, 20]}, path ["a", "-"], newValue 30 => {"a": [10, 20, 30]}
    private static func insertAtPath(
        _ value: AST.RegoValue, _ path: ArraySlice<AST.RegoValue>, _ newValue: AST.RegoValue
    ) throws -> AST.RegoValue {
        guard let head = path.first else {
            return newValue
        }
        let rest = path.dropFirst()
        let isLeaf = rest.isEmpty

        switch value {
        case .object(var obj):
            if isLeaf {
                obj[head] = newValue
            } else {
                guard let child = obj[head] else {
                    throw BuiltinError.evalError(msg: "json.patch: path does not exist")
                }
                obj[head] = try insertAtPath(child, rest, newValue)
            }
            return .object(obj)
        case .array(var arr):
            if isLeaf {
                if head == .string("-") {
                    arr.append(newValue)
                } else {
                    let index = try arrayIndex(head, count: arr.count, allowEnd: true)
                    arr.insert(newValue, at: index)
                }
            } else {
                let index = try arrayIndex(head, count: arr.count, allowEnd: false)
                arr[index] = try insertAtPath(arr[index], rest, newValue)
            }
            return .array(arr)
        case .set(var set):
            if isLeaf {
                // Adding to a set requires the path segment to name the value being added.
                guard head == newValue else {
                    throw BuiltinError.evalError(msg: "json.patch: set element must equal the path segment")
                }
                set.insert(newValue)
            } else {
                guard set.contains(head) else {
                    throw BuiltinError.evalError(msg: "json.patch: path does not exist")
                }
                set.remove(head)
                set.insert(try insertAtPath(head, rest, newValue))
            }
            return .set(set)
        default:
            throw BuiltinError.evalError(msg: "json.patch: path does not exist")
        }
    }

    // arrayIndex converts a path segment into an array index. String segments must be a
    // canonical non-negative integer (no leading zeros, e.g. "0" or "12" but not "01").
    // Numeric segments must be whole numbers. When allowEnd is true the index may equal the
    // array length (an append position); otherwise it must address an existing element.
    //
    // getAtPath/removeAtPath/insertAtPath all reach it when a path segment lands on an
    // array: a path segment is text (or a raw number from an array-form path), but an
    // array needs a validated Int, and the rules differ for reading vs. appending.
    private static func arrayIndex(_ segment: AST.RegoValue, count: Int, allowEnd: Bool) throws -> Int {
        let index: Int
        switch segment {
        case .string(let s):
            guard isCanonicalIndexString(s), let parsed = Int(s) else {
                throw BuiltinError.evalError(msg: "json.patch: invalid array index '\(s)'")
            }
            index = parsed
        case .number(let n):
            guard !n.isFloatType, let parsed = n.int64Value else {
                throw BuiltinError.evalError(msg: "json.patch: invalid array index")
            }
            index = Int(parsed)
        default:
            throw BuiltinError.evalError(msg: "json.patch: invalid array index")
        }

        let upperBound = allowEnd ? count : count - 1
        guard index >= 0 && index <= upperBound else {
            throw BuiltinError.evalError(msg: "json.patch: array index out of bounds")
        }
        return index
    }

    // isCanonicalIndexString reports whether s is a canonical array index: "0", or a run of
    // digits with no leading zero. This rejects "", "01", "-1", "1e0", and similar.
    //
    // arrayIndex uses it to reject string segments that Int() would otherwise accept or
    // that JSON-Patch treats as invalid array indices, so e.g. "01" fails rather than
    // silently becoming index 1.
    private static func isCanonicalIndexString(_ s: String) -> Bool {
        guard !s.isEmpty else {
            return false
        }
        if s == "0" {
            return true
        }
        guard s.first != "0" else {
            return false
        }
        return s.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
