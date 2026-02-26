import AST
import Foundation
import IR

/// Class-backed storage for IR local variables.
///
/// Uses a reference-type backing store so that assigning one Locals to another
/// does NOT trigger copy-on-write on the underlying array. The pool in
/// `IREvaluationContext` manages ownership explicitly — COW safety is redundant
/// overhead in this hot path.
///
/// # Implementation Assumptions
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

/// Reference-counted backing store for Locals.
/// Avoids copy-on-write overhead when Locals are saved/restored across function calls.
// nonisolated(unsafe) is safe because IREvaluationContext is single-threaded during evaluation.
internal final class LocalsStorage: @unchecked Sendable {
    var elements: [AST.RegoValue?]

    init(_ elements: [AST.RegoValue?]) {
        self.elements = elements
    }

    init(repeating value: AST.RegoValue?, count: Int) {
        self.elements = Array(repeating: value, count: count)
    }
}

internal struct Locals: Equatable, Sendable, Encodable {
    // Class-backed storage eliminates COW on the hot path.
    // nonisolated(unsafe) is safe: Locals are only accessed by a single
    // IREvaluationContext at a time, which is not shared across threads.
    nonisolated(unsafe) var backing: LocalsStorage

    // Create empty Locals array
    init() {
        self.backing = LocalsStorage([])
    }

    // Create Locals from array of values
    init(_ elements: [AST.RegoValue?]) {
        self.backing = LocalsStorage(elements)
    }

    // Create Locals wrapping an existing storage object (used by pool)
    init(_ storage: LocalsStorage) {
        self.backing = storage
    }

    // Create Locals with repeated value
    init(repeating value: AST.RegoValue?, count: Int) {
        self.backing = LocalsStorage(repeating: value, count: count)
    }

    // Create Locals sized to accommodate given local indices
    // Used for function call frames where we need to pre-size for parameters
    // The O(N) max() scan is acceptable since functions typically have few parameters
    init(accommodating locals: [IR.Local], minimumSize: Int = 0) {
        let maxLocal = locals.max() ?? IR.Local(0)
        let requiredSize = Int(maxLocal) + 1 + minimumSize
        self.backing = LocalsStorage(repeating: nil, count: requiredSize)
    }

    subscript(index: IR.Local) -> AST.RegoValue? {
        get {
            let idx = Int(index)
            // Return nil if out of bounds. This happens when:
            // - The local hasn't been written to yet (treated as undefined)
            // - In tests that don't go through evalPlan pre-allocation
            guard idx < backing.elements.count else {
                return nil
            }
            return backing.elements[idx]
        }
        set {
            let idx = Int(index)
            // Grow array if needed to accommodate the index.
            // After pre-allocation this should rarely trigger, but is needed
            // for tests and as a safety net.
            if idx >= backing.elements.count {
                backing.elements.append(contentsOf: repeatElement(nil, count: idx - backing.elements.count + 1))
            }
            backing.elements[idx] = newValue
        }
    }

    var count: Int { backing.elements.count }
    var isEmpty: Bool { backing.elements.isEmpty }

    // Clear values up to usedCount. The backing storage is reused in-place.
    func clearForReuse(usedCount: Int? = nil) {
        let clearCount = usedCount ?? backing.elements.count
        for i in 0..<clearCount {
            backing.elements[i] = nil
        }
    }

    // Resize array to specific size, truncating or extending with nil as needed
    func resize(to size: Int) {
        guard size >= 0 else {
            return
        }
        if size < backing.elements.count {
            backing.elements.removeLast(backing.elements.count - size)
        } else if size > backing.elements.count {
            backing.elements.append(contentsOf: repeatElement(nil, count: size - backing.elements.count))
        }
    }

    static func == (lhs: Locals, rhs: Locals) -> Bool {
        return lhs.backing.elements == rhs.backing.elements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(backing.elements)
    }
}
