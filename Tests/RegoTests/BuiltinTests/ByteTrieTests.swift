import Foundation
import Testing

@testable import Rego

@Suite
struct ByteTrieTests {

    // MARK: - matchSubtree (prefix matching)

    @Test func singleKeyExactMatch() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abc")
        #expect(trie.matchSubtree(utf8Of: "abc"))
    }

    @Test func singleKeyPrefixMatch() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abcdef")
        #expect(trie.matchSubtree(utf8Of: "abc"))
    }

    @Test func singleKeyNoMatch() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abcdef")
        #expect(!trie.matchSubtree(utf8Of: "xyz"))
    }

    @Test func prefixLongerThanKeyReturnsFalse() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abc")
        #expect(!trie.matchSubtree(utf8Of: "abcdef"))
    }

    @Test func emptyPrefixMatchesAnyKey() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abc")
        #expect(trie.matchSubtree(utf8Of: ""))
    }

    @Test func emptyKeyMatchedByEmptyPrefix() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "")
        #expect(trie.matchSubtree(utf8Of: ""))
    }

    @Test func emptyKeyNotMatchedByNonEmptyPrefix() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "")
        #expect(!trie.matchSubtree(utf8Of: "a"))
    }

    @Test func multipleKeysSharePrefix() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "a/b/c")
        trie.insert(utf8Of: "a/b/d")
        trie.insert(utf8Of: "e/f/g")
        #expect(trie.matchSubtree(utf8Of: "a/"))
        #expect(trie.matchSubtree(utf8Of: "a/b/"))
        #expect(trie.matchSubtree(utf8Of: "e/f"))
        #expect(!trie.matchSubtree(utf8Of: "x/"))
        #expect(!trie.matchSubtree(utf8Of: "a/c"))
    }

    @Test func multiByteUTF8() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "caf\u{00E9}")
        #expect(trie.matchSubtree(utf8Of: "caf"))
        #expect(trie.matchSubtree(utf8Of: "caf\u{00E9}"))
        #expect(!trie.matchSubtree(utf8Of: "cafe"))
    }

    // MARK: - matchSubtreeReversed (suffix matching)

    @Test func reversedSuffixMatch() {
        var trie = ByteTrie()
        trie.insertReversed(utf8Of: "a/b/c")
        #expect(trie.matchSubtreeReversed(utf8Of: "/c"))
        #expect(trie.matchSubtreeReversed(utf8Of: "b/c"))
    }

    @Test func reversedSuffixNoMatch() {
        var trie = ByteTrie()
        trie.insertReversed(utf8Of: "a/b/c")
        #expect(!trie.matchSubtreeReversed(utf8Of: "/d"))
        #expect(!trie.matchSubtreeReversed(utf8Of: "a/"))
    }

    @Test func reversedExactMatch() {
        var trie = ByteTrie()
        trie.insertReversed(utf8Of: "abc")
        #expect(trie.matchSubtreeReversed(utf8Of: "abc"))
    }

    @Test func reversedEmptySuffix() {
        var trie = ByteTrie()
        trie.insertReversed(utf8Of: "abc")
        #expect(trie.matchSubtreeReversed(utf8Of: ""))
    }

    @Test func reversedMultipleKeys() {
        var trie = ByteTrie()
        trie.insertReversed(utf8Of: "a/b/c")
        trie.insertReversed(utf8Of: "x/y/c")
        trie.insertReversed(utf8Of: "e/f/g")
        #expect(trie.matchSubtreeReversed(utf8Of: "/c"))
        #expect(trie.matchSubtreeReversed(utf8Of: "/g"))
        #expect(!trie.matchSubtreeReversed(utf8Of: "/z"))
    }

    // MARK: - Prefix compression (node splitting)

    @Test func insertCausesSplitAtDivergence() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abc")
        trie.insert(utf8Of: "abd")
        #expect(trie.matchSubtree(utf8Of: "ab"))
        #expect(trie.matchSubtree(utf8Of: "abc"))
        #expect(trie.matchSubtree(utf8Of: "abd"))
        #expect(!trie.matchSubtree(utf8Of: "abe"))
    }

    @Test func insertShorterKeySplitsExistingNode() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "abcdef")
        trie.insert(utf8Of: "ab")
        #expect(trie.matchSubtree(utf8Of: "a"))
        #expect(trie.matchSubtree(utf8Of: "ab"))
        #expect(trie.matchSubtree(utf8Of: "abcdef"))
        #expect(!trie.matchSubtree(utf8Of: "abcxyz"))
    }

    @Test func manyKeysWithSharedPrefix() {
        var trie = ByteTrie()
        trie.insert(utf8Of: "/api/v1/users")
        trie.insert(utf8Of: "/api/v1/roles")
        trie.insert(utf8Of: "/api/v2/users")
        trie.insert(utf8Of: "/health")
        #expect(trie.matchSubtree(utf8Of: "/api"))
        #expect(trie.matchSubtree(utf8Of: "/api/v1"))
        #expect(trie.matchSubtree(utf8Of: "/api/v1/u"))
        #expect(trie.matchSubtree(utf8Of: "/api/v2"))
        #expect(trie.matchSubtree(utf8Of: "/h"))
        #expect(!trie.matchSubtree(utf8Of: "/api/v3"))
        #expect(!trie.matchSubtree(utf8Of: "/other"))
    }
}
