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
