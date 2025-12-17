import AST
import Foundation
import IR

/// Array-based storage for IR local variables.
///
/// # Implementation Assumptions
///
/// This implementation makes the following assumptions about how the IR planner allocates locals:
///
/// 1. **Not Sparse**: The planner allocates locals with indices starting from 0 and
///    generally increasing consecutively. While gaps may exist, locals are not sparse
///    (e.g., using indices 0, 1, and 1000000). This makes array-based storage efficient
///    compared to dictionary-based storage.
///
/// 2. **Stable During Execution**: Local indices don't change during policy evaluation.
///    The same index always refers to the same logical variable.
///
/// 3. **No Register Collision**: Functions don't overwrite each other's locals. Each function
///    call frame uses its own set of local indices, so values don't need to be saved and
///    restored across function calls.
///
/// ## Growth Strategy
///
/// The array grows automatically when accessing out-of-bounds indices via the subscript setter.
/// After initial growth during the first few statements, the array typically reaches a stable
/// size and requires no further allocation for the remainder of evaluation.
///
/// ## Future Improvement
///
/// These assumptions could be validated during the `prepare` phase if violations lead
/// to incorrect behavior or excessive memory usage.
internal struct Locals: Equatable, Sendable, Encodable {
    var storage: Array<AST.RegoValue?>

    // Create empty Locals array
    init() {
        self.storage = []
    }

    // Create Locals from array of values
    init(_ elements: [AST.RegoValue?]) {
        self.storage = elements
    }

    // Create Locals with repeated value
    init(repeating value: AST.RegoValue?, count: Int) {
        self.storage = Array(repeating: value, count: count)
    }

    // Create Locals sized to accommodate given local indices
    // Used for function call frames where we need to pre-size for parameters
    // The O(N) max() scan is acceptable since functions typically have few parameters
    init(accommodating locals: [IR.Local], minimumSize: Int = 0) {
        let maxLocal = locals.max() ?? IR.Local(0)
        let requiredSize = Int(maxLocal) + 1 + minimumSize
        self.storage = Array(repeating: nil, count: requiredSize)
    }

    subscript(index: IR.Local) -> AST.RegoValue? {
        get {
            guard let intIndex = Int(exactly: index) else {
                return nil
            }
            guard intIndex >= 0, intIndex < storage.count else {
                return nil
            }
            return storage[intIndex]
        }
        set {
            guard let intIndex = Int(exactly: index) else {
                return
            }
            guard intIndex >= 0 else {
                return
            }
            if intIndex >= storage.count {
                storage.append(contentsOf: repeatElement(nil, count: intIndex - storage.count + 1))
            }
            storage[intIndex] = newValue
        }
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    // Resize array to specific size, truncating or extending with nil as needed
    mutating func resize(to size: Int) {
        guard size >= 0 else {
            return
        }
        if size < storage.count {
            storage.removeLast(storage.count - size)
        } else if size > storage.count {
            storage.append(contentsOf: repeatElement(nil, count: size - storage.count))
        }
    }

    static func == (lhs: Locals, rhs: Locals) -> Bool {
        return lhs.storage == rhs.storage
    }
}
