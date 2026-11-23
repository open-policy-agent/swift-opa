import Foundation
import Testing

@testable import AST

#if canImport(Darwin)
    // JSONObject is Darwin-only.
    @Suite
    struct JSONObjectTests {
        struct DynamicKey: CodingKey {
            let stringValue: String
            init(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }

        // Decodes the member named by the "key" user info entry, as a JSONDecoder-backed decoder would.
        struct Lookup: Decodable {
            static let keyInfo = CodingUserInfoKey(rawValue: "key")!
            let value: Int?
            init(from decoder: Decoder) throws {
                let key = DynamicKey(stringValue: decoder.userInfo[Self.keyInfo] as! String)
                value = try decoder.container(keyedBy: DynamicKey.self).decodeIfPresent(Int.self, forKey: key)
            }
        }

        // Pairs of (key we look up, key spelled in the input).
        static let keys: [(String, String)] = [
            ("Kind", "Kind"),
            ("Kind", "\u{212A}ind"),
            ("a;b", "a\u{037E}b"),
            ("a`b", "a\u{1FEF}b"),
            ("\u{00E9}", "e\u{0301}"),
            ("Kind", "kind"),
            ("Kind", "other"),
        ]

        // Lookups must match JSONDecoder, which compares keys by canonical equivalence.
        @Test(arguments: keys)
        func lookupMatchesJSONDecoder(lookup: String, input: String) throws {
            let data = try JSONSerialization.data(withJSONObject: [input: 1])
            let decoder = JSONDecoder()
            decoder.userInfo[Lookup.keyInfo] = lookup
            let expected = try decoder.decode(Lookup.self, from: data).value
            let got: Int? = try JSONObject(JSONObject.parse(data)).integerIfPresent(lookup)
            #expect(got == expected)
        }

        // Catches any Unicode decomposition changes we don't already handle. We check every non-ASCII scalar, and any
        // that Swift's String equality or Foundation's canonical decomposition treats as an ASCII string must map to
        // a key that `needsCanonicalLookup` sends to the slower String comparison.
        @Test
        func canonicalLookupCoversEveryASCIIEquivalent() {
            var ascii: [String: String] = [:]
            for a in 0x20..<0x7F {
                let one = String(Unicode.Scalar(UInt8(a)))
                ascii[one] = one
                for b in 0x20..<0x7F {
                    let two = one + String(Unicode.Scalar(UInt8(b)))
                    ascii[two] = two
                }
            }
            var equivalents: [UInt32: String] = [:]
            for v in UInt32(0x80)...0x10FFFF {
                guard let scalar = Unicode.Scalar(v) else {
                    continue
                }
                let s = String(scalar)
                if let match = ascii[s] {
                    equivalents[v] = match
                }
                let decomposed = s.decomposedStringWithCanonicalMapping
                if decomposed.utf8.allSatisfy({ $0 < 0x80 }) {
                    equivalents[v] = decomposed
                }
            }
            #expect(!equivalents.isEmpty)
            for (v, match) in equivalents.sorted(by: { $0.key < $1.key }) {
                #expect(
                    JSONObject.needsCanonicalLookup(match),
                    "U+\(String(v, radix: 16, uppercase: true)) is equivalent to \"\(match)\"")
            }
        }
    }
#endif
