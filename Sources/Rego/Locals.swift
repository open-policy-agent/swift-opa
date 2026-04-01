import AST
import Foundation

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
internal struct Locals: Equatable, Sendable, Encodable {
    var storage: [AST.RegoValue?]

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

    subscript(index: Local) -> AST.RegoValue? {
        get {
            let idx = Int(index)
            return storage[idx]
        }
        set {
            let idx = Int(index)
            precondition(idx < storage.count, "local index \(idx) out of bounds (size \(storage.count))")
            storage[idx] = newValue
        }
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    // Clear values up to usedCount and return the storage for pooling
    mutating func releaseStorage(usedCount: Int? = nil) -> [AST.RegoValue?] {
        let clearCount = usedCount ?? storage.count
        for i in 0..<clearCount {
            storage[i] = nil
        }

        return storage
    }

    static func == (lhs: Locals, rhs: Locals) -> Bool {
        return lhs.storage == rhs.storage
    }
}
