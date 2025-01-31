import AST

// TrieNode is a node in a trie for comparing roots/paths
struct TrieNode: Sendable, Equatable {
    var value: String
    var isLeaf: Bool = false
    var children: [String: TrieNode] = [:]
}

extension TrieNode {
    public static func build(from segments: [String]) -> TrieNode? {
        return TrieNode.build(from: segments[...])
    }

    private static func build(from segments: ArraySlice<String>) -> TrieNode? {
        guard let rootSegment = segments.first else {
            return nil
        }

        let isLeaf = segments.count == 1
        let i = segments.startIndex
        let child = TrieNode.build(from: segments[i.advanced(by: 1)...])
        var children: [String: TrieNode] = [:]
        if let child {
            children[child.value] = child
        }

        return TrieNode(
            value: rootSegment,
            isLeaf: isLeaf,
            children: children
        )
    }

    // merge will merge the tree represented by segments under the provided node, and return the newly merged tree.
    public static func merge(node: TrieNode, withSegments segments: ArraySlice<String>) -> (TrieNode, Bool) {
        guard !segments.isEmpty else {
            let isPrefix = !node.children.isEmpty
            return (TrieNode(value: node.value, isLeaf: true, children: node.children), isPrefix)
        }

        let i = segments.startIndex
        let pathValue = segments[i]
        let childIsLeaf = segments.count == 1

        let child = node.children[pathValue] ?? TrieNode(value: pathValue, isLeaf: childIsLeaf, children: [:])
        let (newChild, conflict) = merge(node: child, withSegments: segments[segments.index(after: i)...])

        // Splice in the new subtree
        var newChildren = node.children
        newChildren[newChild.value] = newChild
        return (TrieNode(value: node.value, isLeaf: node.isLeaf, children: newChildren), conflict || node.isLeaf)
    }

    // overlaps returns true if one of the trees overlaps with the other,
    // in that one is a strict ancestor of the other.
    public func overlaps(with other: TrieNode) -> Bool {
        if self.value != other.value {
            return false
        }
        if self.isLeaf || other.isLeaf {
            return true
        }

        for (k, child) in self.children {
            guard let otherChild = other.children[k] else {
                continue
            }
            if child.overlaps(with: otherChild) {
                return true
            }
        }
        return false
    }

    // overlaps returns true if one of the trees overlaps with the other,
    // in that one is a strict ancestor of the other.
    public func contains(dataTree other: AST.RegoValue) -> Bool {
        if self.isLeaf {
            return true
        }

        guard case .object(let otherObj) = other else {
            return false
        }

        // Empty objects are considered "contained" by any roots
        var allContained = true
        for (k, v) in otherObj {
            guard case .string(let k) = k else {
                // Non-string keys are invalid
                return false
            }

            let root = self.children[k]
            if self.value == "" {
                // Magic [""] root exemption - matches all
                return true
            }
            guard let root else {
                // Must find a corresponding root
                return false
            }

            let isContained = root.contains(dataTree: v)
            allContained = allContained && isContained
        }

        return allContained
    }
}
