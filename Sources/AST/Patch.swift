import Foundation

extension RegoValue {
    public enum PatchError: Error {
        case emptyPath
    }

    // patch returns a new RegoValue consisting of
    // the original patched or overlayed with another RegoValue
    // at the provided path.
    // If the path does not yet exist, it will be created.
    public func patch(with overlay: RegoValue, at path: [String]) throws(PatchError)
        -> RegoValue
    {
        return try patch(with: overlay, at: path[...])
    }

    public func patch(with overlay: RegoValue, at path: ArraySlice<String>) throws(PatchError)
        -> RegoValue
    {
        // Base cases
        guard !path.isEmpty else {
            throw .emptyPath
        }

        let i = path.startIndex
        let k = path[i]

        // Merge in the overlay value when we hit the leaf
        if path.count == 1 {
            switch self {
            case .object(var o):
                // copy-on-write
                o[k] = overlay
                return .object(o)
            default:
                let o: [String: RegoValue] = [k: overlay]
                return .object(o)
            }
        }

        switch self {
        case .object(var o):
            // Already has this key
            if let v = o[k] {
                o[k] = try v.patch(with: overlay, at: path[i.advanced(by: 1)...])
                return .object(o)
            }

            // Non-overlapping key
            let v = try RegoValue.null.patch(with: overlay, at: path[i.advanced(by: 1)...])
            o[k] = v
            return .object(o)

        default:
            // Intermediate node which is not an object - pave it over with a new object
            let v = try RegoValue.null.patch(with: overlay, at: path[i.advanced(by: 1)...])
            let o: [String: RegoValue] = [k: v]
            return .object(o)
        }
    }
}
