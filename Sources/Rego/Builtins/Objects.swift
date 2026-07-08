import AST
import Foundation

extension BuiltinFuncs {

    static func objectGet(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .object(let object) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let key = args[1]
        let defaultValue = args[2]

        switch key {
        case .array(let keyPath):
            // For an array "key" we treat it as a path into the object..
            // Copying behavior from upstream OPA, an empty array should return the whole object
            var current: AST.RegoValue = .object(object)
            for key in keyPath {
                switch current {
                case .array(let arr):
                    guard case .number(let idx) = key else {
                        return defaultValue
                    }
                    guard !key.isFloat else {
                        return defaultValue
                    }
                    let i = idx.intValue
                    // Bounds check
                    guard i >= 0 && i < arr.count else {
                        return defaultValue
                    }
                    current = arr[i]
                case .object(let currentObj):
                    guard let next = currentObj[key] else {
                        return defaultValue
                    }
                    current = next
                case .set(let set):
                    guard set.contains(key) else {
                        return defaultValue
                    }
                    current = key
                default:
                    return defaultValue
                }
            }
            return current

        default:
            // Scalar keys - simple lookup
            guard let value = object[key] else {
                return defaultValue
            }
            return value
        }
    }

    static func objectKeys(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .object(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        return .set(Set(x.keys))
    }

    // union creates a new object of the asymmetric union of two objects.
    // args
    // a (object[any: any])
    // left-hand object
    // b (object[any: any])
    // right-hand object
    // returns: output (any) a new object which is the result of an asymmetric recursive union of two objects where conflicts
    // are resolved by choosing the key from the right-hand object b
    static func objectUnion(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object(let a) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "object")
        }

        guard case .object(let b) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "object")
        }

        guard !a.isEmpty else {
            return .object(b)
        }

        guard !b.isEmpty else {
            return .object(a)
        }

        return .object(a.merging(b) { (_, new) in new })
    }

    // union_n creates a new object by merging all objects in the provided array of objects to merge (array[object[any: any]])
    // returns: output (any) a new object which is the result of an asymmetric recursive union of all objects
    // where conflicts are resolved by choosing the key from the right-hand object
    static func objectUnionN(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .array(let objects) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "objects", got: args[0].typeName, want: "array")
        }

        // Start with an empty object as the accumulator
        var result: [AST.RegoValue: AST.RegoValue] = [:]

        // Iterate through each object in the array
        for (index, obj) in objects.enumerated() {
            guard case .object(let objDict) = obj else {
                throw BuiltinError.argumentTypeMismatch(arg: "objects[\(index)]", got: obj.typeName, want: "object")
            }

            // Merge this object into the result (right-hand side wins on conflicts)
            result = result.merging(objDict) { (_, new) in new }
        }

        return .object(result)
    }

    // filter returns a new object with only the keys of the input object that are
    // present in the keys argument. keys may be an array, set, or object.
    // args
    // object (object[any: any]) - object to filter keys
    // keys (any<array[any], object[any: any], set[any]>) - keys to keep in object
    // returns: filtered (any) - remaining data from object with only keys specified in keys
    static func objectFilter(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object(let object) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let keys = try keysArgumentAsSet(args[1], arg: "keys")

        // Result holds at most one entry per key that also exists in
        // the object.
        var result: [AST.RegoValue: AST.RegoValue] = [:]
        result.reserveCapacity(Swift.min(keys.count, object.count))
        for key in keys {
            if let value = object[key] {
                result[key] = value
            }
        }

        return .object(result)
    }

    // remove returns a new object with the specified keys removed from the input object.
    // keys may be an array, set, or object.
    // args
    // object (object[any: any]) - object to remove keys from
    // keys (any<array[any], object[any: any], set[any]>) - keys to remove from object
    // returns: output (any) - result of removing the specified keys from object
    static func objectRemove(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .object(let object) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let keysToRemove = try keysArgumentAsSet(args[1], arg: "keys")

        guard !keysToRemove.isEmpty else {
            return .object(object)
        }

        var result: [AST.RegoValue: AST.RegoValue] = [:]
        result.reserveCapacity(Swift.max(0, object.count - keysToRemove.count))
        for (key, value) in object where !keysToRemove.contains(key) {
            result[key] = value
        }

        return .object(result)
    }

    // subset determines if the sub value is a subset of the super value.
    // args
    // super (any<object[any: any], set[any], array[any]>) - object, set, or array to check against
    // sub (any<object[any: any], set[any], array[any]>) - object, set, or array to check
    // returns: result (boolean) - true if sub is a subset of super
    static func objectSubset(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        return .boolean(try isSubset(super: args[0], sub: args[1]))
    }

    // MARK: - Private helpers

    // isArrayASubsetOfAnotherArray returns true when sub appears as a contiguous, in-order
    // subsequence of super.
    private static func isArrayASubsetOfAnotherArray(super superArr: [AST.RegoValue], sub subArr: [AST.RegoValue])
        -> Bool
    {
        guard let first = subArr.first else {
            return true
        }
        guard superArr.count >= subArr.count else {
            return false
        }

        // We use a filtered for loop to skip starting indices that don't
        // match the start of the sub-array's sequence.
        for start in 0...(superArr.count - subArr.count) where superArr[start] == first {
            // Match the rest of the sequence normally.
            var matched = true
            for offset in 1..<subArr.count where superArr[start + offset] != subArr[offset] {
                matched = false
                break
            }
            if matched {
                return true
            }
        }

        return false
    }

    // isObjectASubsetOfAnotherObject returns true when every key in sub is present in
    // super and the corresponding values are subsets. Nested objects, sets, and arrays
    // are checked recursively; all other values must be equal.
    private static func isObjectASubsetOfAnotherObject(
        super superObj: [AST.RegoValue: AST.RegoValue], sub subObj: [AST.RegoValue: AST.RegoValue]
    ) -> Bool {
        for (key, subChild) in subObj {
            guard let superChild = superObj[key] else {
                return false
            }
            if subChild == superChild {
                continue
            }
            switch (superChild, subChild) {
            case (.object(let superChildObj), .object(let subChildObj)):
                if !isObjectASubsetOfAnotherObject(super: superChildObj, sub: subChildObj) {
                    return false
                }
            case (.set(let superChildSet), .set(let subChildSet)):
                if !subChildSet.isSubset(of: superChildSet) {
                    return false
                }
            case (.array(let superChildArr), .array(let subChildArr)):
                if !isArrayASubsetOfAnotherArray(super: superChildArr, sub: subChildArr) {
                    return false
                }
            default:
                return false
            }
        }

        return true
    }

    // isSetASubsetOfArray returns true when every member of subset appears somewhere in the
    // super array, without regard to ordering.
    private static func isSetASubsetOfArray(super superArr: [AST.RegoValue], sub subSet: Set<AST.RegoValue>) -> Bool {
        // Mirrors OPA's arraySetSubset implementation.
        var unmatched = subSet.count
        for element in superArr {
            if subSet.contains(element) {
                unmatched -= 1
            }
            if unmatched == 0 {
                return true
            }
        }
        return false
    }

    // isSubset implements the subset relation across the supported type combinations.
    // Both operands must be the same type (both objects, both sets, or both arrays),
    // with the single exception that a set may be checked against an array, in which
    // case the set members must appear somewhere in the array.
    private static func isSubset(super superValue: AST.RegoValue, sub subValue: AST.RegoValue) throws -> Bool {
        switch (superValue, subValue) {
        case (.object(let superObj), .object(let subObj)):
            return isObjectASubsetOfAnotherObject(super: superObj, sub: subObj)
        case (.set(let superSet), .set(let subSet)):
            return subSet.isSubset(of: superSet)
        case (.array(let superArr), .array(let subArr)):
            return isArrayASubsetOfAnotherArray(super: superArr, sub: subArr)
        case (.array(let superArr), .set(let subSet)):
            return isSetASubsetOfArray(super: superArr, sub: subSet)
        default:
            throw BuiltinError.evalError(
                msg: "both arguments object.subset must be of the same type or array and set")
        }
    }

    // keysArgumentAsSet interprets the second ("keys") argument of object.filter and
    // object.remove as the set of keys it references.
    //
    // Both filter and remove builtins accept the argument as one of three interchangeable
    // forms - an array (its elements are the keys), a set (its members are the keys), or
    // an object (its own keys are the keys). Regardless of the form, filter and remove only
    // need to test membership ("is this object key named?"). Normalizing all three
    // forms into a single Set lets both builtins share identical lookup logic instead
    // of each repeating the same type switch, and gives one place to raise the type error
    // for an unsupported shape. This mirrors upstream OPA's getObjectKeysParam helper.
    private static func keysArgumentAsSet(_ value: AST.RegoValue, arg: String) throws -> Set<AST.RegoValue> {
        switch value {
        case .array(let arr):
            return Set(arr)
        case .set(let set):
            return set
        case .object(let obj):
            return Set(obj.keys)
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: arg, got: value.typeName, want: "any<array[any], object[any: any], set[any]>")
        }
    }
}
