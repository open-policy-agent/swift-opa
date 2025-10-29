import AST
import Foundation
import IR

/// InvocationKey is a key for memoizing an IR function call invocation.
/// Note we capture the arguments as unresolved operands and not resolved values,
/// as hashing the values was proving extremely expensive. We instead rely on the
/// invariant the the plan / evaluator will not modify a local after it has been initally set.
struct InvocationKey: Hashable {
    let funcName: String
    let args: [IR.Operand]
}

/// MemoCache is a memoization cache of plan invocations
typealias MemoCache = [InvocationKey: AST.RegoValue]

/// MemoStack is a stack of MemoCaches
final class MemoStack {
    var stack: [MemoCache] = []
}

extension MemoStack {
    /// Get and set values on the cache at the top of the memo stack.
    subscript(key: InvocationKey) -> AST.RegoValue? {
        get {
            guard !self.stack.isEmpty else {
                return nil
            }
            return self.stack[self.stack.count - 1][key]
        }
        set {
            if self.stack.isEmpty {
                self.stack.append(MemoCache.init())
            }
            self.stack[self.stack.count - 1][key] = newValue
        }
    }

    func push() {
        self.stack.append(MemoCache.init())
    }

    func pop() {
        guard !self.stack.isEmpty else {
            return
        }
        self.stack.removeLast()
    }

    /// withPush returns the result of calling the provided closure with
    /// a fresh memoCache pushed on the stack. The memoCache will only be
    /// active during that call, and discarded when it completes.
    func withPush<T>(_ body: () async throws -> T) async rethrows -> T {
        self.push()
        defer {
            self.pop()
        }
        return try await body()
    }
}
