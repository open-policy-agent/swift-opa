import Foundation

extension RegoValue {
    // patch returns a new RegoValue consisting of
    // the original patched or overlayed with another RegoValue
    // at the provided path.
    // If the path does not yet exist, it will be created.
    package func patch(with overlay: RegoValue, at path: [String]) -> RegoValue {
        return patch(with: overlay, at: path[...])
    }

    package func patch(with overlay: RegoValue, at path: ArraySlice<String>) -> RegoValue {
        // Base case
        if path.isEmpty {
            return overlay
        }

        let i = path.startIndex
        let k = RegoValue.string(path[i])

        switch self {
        case .object(var o):
            // Already has this key
            if let v = o[k] {
                o[k] = v.patch(with: overlay, at: path[i.advanced(by: 1)...])
                return .object(o)
            }

            // Non-overlapping key
            let v = RegoValue.null.patch(with: overlay, at: path[i.advanced(by: 1)...])
            o[k] = v
            return .object(o)

        default:
            // Intermediate node which is not an object - pave it over with a new object
            let v = RegoValue.null.patch(with: overlay, at: path[i.advanced(by: 1)...])
            let o: [RegoValue: RegoValue] = [k: v]
            return .object(o)
        }
    }

    // removing returns a new RegoValue with the value at the given path removed.
    // If the path does not exist, the value is returned unchanged. For an object
    // node the leaf key is removed from its parent. For an array node the element
    // at the integer-valued segment is removed and the array is compacted.
    // Ancestors are preserved even if they become empty as a result. A segment
    // that does not address the current node (a non-integer index into an array,
    // an out-of-bounds index, a missing object key, or any segment into a scalar
    // or set) is a no-op. An empty path resets the value to an empty object,
    // matching the "reset the store" semantics callers expect at the root.
    package func removing(at path: [String]) -> RegoValue {
        // An empty path addresses the root itself. Removing the root resets the
        // value to an empty object, matching the "reset the store" semantics
        // callers expect. This only makes sense at the root, so it is handled
        // here at the entry point rather than in the recursive core, which only
        // ever sees non-empty paths.
        guard !path.isEmpty else {
            return .object([:])
        }
        return removing(at: path[...])
    }

    // This variant of ``removing`` works on an ArraySlice, and is the
    // recursive core for removal operations. It assumes a non-empty path: the
    // recursion removes a leaf directly once `restOfPath` is empty and only
    // recurses on a non-empty remainder, so the empty-path case never reaches
    // here. The root-reset case is handled by the entry point above.
    package func removing(at path: ArraySlice<String>) -> RegoValue {
        guard let i = path.indices.first else {
            // Defensive no-op: a non-root empty path does not address anything.
            return self
        }
        let segment = path[i]
        let restOfPath = path[i.advanced(by: 1)...]

        switch self {
        case .object(var o):
            let k = RegoValue.string(segment)
            guard let child = o[k] else {
                return self
            }
            if restOfPath.isEmpty {
                // Leaf: remove the key from the parent.
                o.removeValue(forKey: k)
                return .object(o)
            }
            // Recurse into the child; reattach the child structure, post-deletion.
            o[k] = child.removing(at: restOfPath)
            return .object(o)

        case .array(var a):
            // Arrays are addressed by a non-negative integer index. Anything
            // else (non-integer or out-of-bounds) does not address an element,
            // so it is a no-op.
            guard let idx = Int(segment), idx >= 0, idx < a.count else {
                return self
            }
            if restOfPath.isEmpty {
                // Leaf: remove the element, compacting the array.
                a.remove(at: idx)
                return .array(a)
            }
            // Recurse into the element; reattach post-deletion.
            a[idx] = a[idx].removing(at: restOfPath)
            return .array(a)

        default:
            // Scalars and sets carry no addressable path: no-op.
            return self
        }
    }
}

// Support for merging a .object RegoValue with another
extension [RegoValue: RegoValue] {
    package func merge(with other: [RegoValue: RegoValue]) -> [RegoValue: RegoValue] {
        var result = self
        for (k, v) in other {
            if case .object(let objValueSelf) = self[k], case .object(let objValueOther) = v {
                // both self and other have objects at this key, merge them recursively
                result[k] = .object(objValueSelf.merge(with: objValueOther))
            } else {
                result[k] = v
            }
        }
        return result
    }
}
