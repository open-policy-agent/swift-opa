import Foundation

/// Prefix-compressed (radix) trie for efficient prefix matching on UTF-8 strings.
///
/// Each node stores a byte sequence prefix rather than a single byte, reducing
/// node count when keys share long common prefixes (typical for path-based
/// OPA policies). Modeled after the patricia trie used by the Go OPA
/// implementation (github.com/tchap/go-patricia).
///
/// Insert keys, then query with `matchSubtree(utf8Of:)` to check if any
/// inserted key starts with the given prefix. Used by `strings.any_prefix_match`
/// and `strings.any_suffix_match` builtins.
///
/// ## Design tradeoffs vs Go's patricia trie
///
/// Go uses a two-tier child list: a linear scan (sparseChildList, up to 8
/// children) that upgrades to a byte-indexed array (denseChildList) for high
/// fanout. We use `Dictionary<UInt8, Node>` throughout, which gives O(1)
/// amortized lookup via hashing without the complexity of managing two list
/// types. The hash overhead is higher than a direct array index, but after
/// prefix compression most nodes have low fanout (typically 2-5 children),
/// where dictionary performance is comparable. If profiling shows child lookup
/// as a bottleneck, a dense byte-indexed array (keyed by `byte - minByte`)
/// would be the next optimization to add.
struct ByteTrie {
    private let root = Node()

    private final class Node {
        var prefix: [UInt8]
        var children: [UInt8: Node]?

        init(prefix: [UInt8] = []) {
            self.prefix = prefix
        }
    }

    // MARK: - Insert

    /// Insert a string's UTF-8 bytes into the trie.
    mutating func insert(utf8Of string: String) {
        withUTF8Bytes(of: string) { buf in
            insertBytes(buf, offset: 0, into: root)
        }
    }

    /// Insert a string's UTF-8 bytes in reverse order.
    mutating func insertReversed(utf8Of string: String) {
        withUTF8Bytes(of: string) { buf in
            guard buf.count > 0 else { return }
            let reversed = [UInt8](unsafeUninitializedCapacity: buf.count) { out, count in
                for i in 0..<buf.count {
                    out[buf.count - 1 - i] = buf[i]
                }
                count = buf.count
            }
            reversed.withUnsafeBufferPointer { rbuf in
                insertBytes(rbuf, offset: 0, into: root)
            }
        }
    }

    private func insertBytes(
        _ key: UnsafeBufferPointer<UInt8>, offset: Int, into node: Node
    ) {
        guard offset < key.count else { return }

        let byte = key[offset]

        guard let child = node.children?[byte] else {
            let leaf = Node(prefix: Array(key[offset..<key.count]))
            if node.children == nil {
                node.children = [byte: leaf]
            } else {
                node.children![byte] = leaf
            }
            return
        }

        let common = commonPrefixLength(child.prefix, key, keyOffset: offset)

        if common == child.prefix.count {
            insertBytes(key, offset: offset + common, into: child)
        } else {
            let splitNode = Node(prefix: Array(child.prefix[0..<common]))
            child.prefix = Array(child.prefix[common...])
            splitNode.children = [child.prefix[0]: child]

            if offset + common < key.count {
                let leaf = Node(prefix: Array(key[(offset + common)..<key.count]))
                splitNode.children![leaf.prefix[0]] = leaf
            }

            node.children![byte] = splitNode
        }
    }

    // MARK: - Query

    /// Returns true if any inserted key starts with the given prefix.
    func matchSubtree(utf8Of prefix: String) -> Bool {
        withUTF8Bytes(of: prefix) { buf in
            matchBytes(buf, offset: 0, in: root)
        }
    }

    /// Returns true if any inserted (reversed) key starts with the reversed prefix.
    func matchSubtreeReversed(utf8Of suffix: String) -> Bool {
        withUTF8Bytes(of: suffix) { buf in
            guard buf.count > 0 else { return root.children != nil }
            let reversed = [UInt8](unsafeUninitializedCapacity: buf.count) { out, count in
                for i in 0..<buf.count {
                    out[buf.count - 1 - i] = buf[i]
                }
                count = buf.count
            }
            return reversed.withUnsafeBufferPointer { rbuf in
                matchBytes(rbuf, offset: 0, in: root)
            }
        }
    }

    private func matchBytes(
        _ query: UnsafeBufferPointer<UInt8>, offset: Int, in node: Node
    ) -> Bool {
        guard offset < query.count else { return true }

        guard let child = node.children?[query[offset]] else { return false }

        let remaining = query.count - offset
        let prefixLen = child.prefix.count
        let compareLen = min(prefixLen, remaining)

        for i in 0..<compareLen {
            if child.prefix[i] != query[offset + i] { return false }
        }

        if remaining <= prefixLen {
            return true
        }

        return matchBytes(query, offset: offset + prefixLen, in: child)
    }

    // MARK: - Helpers

    private func commonPrefixLength(
        _ prefix: [UInt8], _ key: UnsafeBufferPointer<UInt8>, keyOffset: Int
    ) -> Int {
        let maxLen = min(prefix.count, key.count - keyOffset)
        for i in 0..<maxLen {
            if prefix[i] != key[keyOffset + i] { return i }
        }
        return maxLen
    }

    /// Access a string's UTF-8 bytes via contiguous pointer (fast path)
    /// or by copying to an array (fallback).
    private func withUTF8Bytes<R>(of string: String, _ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        if let result = string.utf8.withContiguousStorageIfAvailable({ body($0) }) {
            return result
        }
        return Array(string.utf8).withUnsafeBufferPointer { body($0) }
    }
}
