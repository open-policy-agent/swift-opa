import Foundation
import Testing

@testable import BundleSigningInternals

/// Unit tests for the hidden bundle-signing internals.
/// These exercise the module directly, so the public Rego test suite does not need to import it.
@Suite("BundleSigningInternals")
struct BundleSigningInternalsTests {

    // MARK: CanonicalJSON

    @Test
    func canonicalJSONPreservesNumberLiteralsAndSortsKeysByBytes() throws {
        // Numbers verbatim (1.0 not 1, 1e3 not 1000, big int intact). Keys sorted by
        // UTF-8 byte order (Z < a < b).
        let out = try CanonicalJSON.canonicalize(
            Data(#"{ "b": 1.0, "a": 1e3, "Z": 10000000000000000000 }"#.utf8))
        #expect(
            String(decoding: out, as: UTF8.self) == #"{"Z":10000000000000000000,"a":1e3,"b":1.0}"#)
    }

    @Test
    func canonicalJSONStringEscaping() throws {
        // `<>&/` and non-ASCII stay raw. A normalizes to A. `\n` stays short-escaped.
        let out = try CanonicalJSON.canonicalize(Data(#"{"k":"a<b>c&d/eA\n"}"#.utf8))
        #expect(String(decoding: out, as: UTF8.self) == #"{"k":"a<b>c&d/eA\n"}"#)
    }

    // MARK: base64url (JWS segment encoding)

    @Test
    func base64URLRoundTrips() throws {
        let raw = Data((0...255).map { UInt8($0) })
        let encoded = raw.base64URLNoPad
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(Data(base64URLNoPad: encoded) == raw)
    }
}
