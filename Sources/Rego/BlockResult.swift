import AST

// BlockResult is the result of evaluating a block.
// It contains control flow information (break counter and function return value).
struct BlockResult {
    var breakCounter: UInt32?
    var functionReturnValue: AST.RegoValue?

    init(breakCounter: UInt32? = nil, functionReturnValue: AST.RegoValue? = nil) {
        self.breakCounter = breakCounter
        self.functionReturnValue = functionReturnValue
    }

    // undefined initializes an undefined BlockResult
    static var undefined: BlockResult {
        return .init(breakCounter: 0)
    }

    static var success: BlockResult {
        return .init()
    }

    // isUndefined indicates whether the block evaluated to undefined.
    var isUndefined: Bool {
        return self.breakCounter != nil
    }

    // If shouldBreak is true, evaluation of the calling block should
    // break (by calling breakByOne()).
    var shouldBreak: Bool {
        guard let breakCounter = self.breakCounter else {
            return false
        }
        return breakCounter > 0
    }

    // breakByOne returns a new BlockResult whose breakCounter has been
    // decremented by 1 - this simulates "breaking" one level.
    func breakByOne() -> BlockResult {
        guard let breakCounter = self.breakCounter else {
            return BlockResult(breakCounter: 0)
        }
        return BlockResult(breakCounter: breakCounter - 1)
    }
}
