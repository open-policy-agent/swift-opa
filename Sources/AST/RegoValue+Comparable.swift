import Foundation

extension RegoValue: Comparable {
    // Following the upstream OPA Go implementation:
    //
    //   Different types are never equal to each other. For comparison purposes, types
    //   are sorted as follows:
    //
    //   nil < Null < Boolean < Number < String < Var < Ref < Array < Object < Set <
    //   ArrayComprehension < ObjectComprehension < SetComprehension < Expr < SomeDecl
    //   < With < Body < Rule < Import < Package < Module.
    //
    //   Arrays and Refs are equal if and only if both a and b have the same length
    //   and all corresponding elements are equal. If one element is not equal, the
    //   return value is the same as for the first differing element. If all elements
    //   are equal but a and b have different lengths, the shorter is considered less
    //   than the other.
    //
    //   Objects are considered equal if and only if both a and b have the same sorted
    //   (key, value) pairs and are of the same length. Other comparisons are
    //   consistent but not defined.
    //
    //   Sets are considered equal if and only if the symmetric difference of a and b
    //   is empty.
    //   Other comparisons are consistent but not defined.
    //
    // Since we have a subset of these types we'll keep the order, skipping any that we
    // don't have implemented here (yet).
    //
    // ref: https://github.com/open-policy-agent/opa/blob/da69c328192f0ec4b9b4b4bcce9ca88d02c291cf/v1/types/types.go#L845
    public static func < (lhs: RegoValue, rhs: RegoValue) -> Bool {
        // Check their type sort orders first
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        // Handle the case where the lhs and rhs are the same types
        // For the collection types compare by keys, then values, then length as appropriate.
        // Fallback to the default hash behavior for remaining types (null, undefined)
        switch (lhs, rhs) {
        case (.array(let lhs), .array(let rhs)):
            // compare elements first
            // ref: https://github.com/open-policy-agent/opa/blob/da69c328192f0ec4b9b4b4bcce9ca88d02c291cf/v1/types/types.go#L1171
            for (l, r) in zip(lhs, rhs) {
                if l != r {
                    return l < r
                }
            }

            // All shared elements are equal, compare length as tie breaker
            return lhs.count < rhs.count

        case (.boolean(let lhs), .boolean(let rhs)):
            return rhs && !lhs

        case (.number(let lhs), .number(let rhs)):
            return lhs < rhs

        case (.object(let lhs), .object(let rhs)):
            // Objects - compare keys, then values, then length
            let lSortedKeys = lhs.keys.sorted()
            let rSortedKeys = rhs.keys.sorted()

            for (lk, rk) in zip(lSortedKeys, rSortedKeys) {
                if lk != rk {
                    return lk < rk
                }
                let lv = lhs[lk]!
                let rv = rhs[rk]!

                if lv != rv {
                    return lv < rv
                }
            }

            // All shared keys and values are equal, compare length as tie breaker
            return lhs.count < rhs.count

        case (.set(let lhs), .set(let rhs)):
            let l: RegoValue = .array(Array(lhs).sorted())
            let r: RegoValue = .array(Array(rhs).sorted())

            return l < r

        case (.string(let lhs), .string(let rhs)):
            return lhs < rhs

        default:
            return lhs.hashValue < rhs.hashValue
        }
    }

    public static func compare(_ lhs: RegoValue, _ rhs: RegoValue) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        } else if lhs > rhs {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    // ref: https://github.com/open-policy-agent/opa/blob/da69c328192f0ec4b9b4b4bcce9ca88d02c291cf/v1/types/types.go#L1189
    private var sortOrder: Int {
        return switch self {
        case .undefined: 0
        case .null: 1
        case .boolean: 2
        case .number: 3
        case .string: 4
        case .array: 5
        case .object: 6
        case .set: 7
        }
    }
}
