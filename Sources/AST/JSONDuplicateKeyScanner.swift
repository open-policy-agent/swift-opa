import Foundation

/// The result of scanning raw JSON for duplicate object keys.
enum JSONKeyScan: Equatable {
    case unique
    case duplicate
    case nulByte
}

/// Objects below this many keys check each new key against the earlier ones, since giving every object a Set makes
/// typical JSON about 3x slower to scan. Larger objects switch to a Set, because linear checks grow quadratically
/// with an object's key count. Near this size, comparing is still faster than hashing.
let jsonKeyScanLinearLimit = 32

/// Scans raw UTF-8 JSON for objects with duplicate keys, without building a value tree.
///
/// Keys are decoded, escapes included, and compared as Swift `String`s, so keys that are canonically equivalent
/// (such as a precomposed "é" and "e" plus a combining accent) collide just as they merge in a Swift dictionary.
/// Values are skipped. Scanning stops at the first duplicate or NUL byte. NUL bytes are rejected because UTF-16
/// and UTF-32 input would defeat a byte-level scan, and OPA only accepts UTF-8.
///
/// The scanner doesn't validate JSON, so callers must also parse the input. Malformed escapes and lone surrogate
/// escapes in keys decode to U+FFFD, which can make two malformed keys collide in input the parser would reject
/// anyway.
func scanJSONObjectKeys(_ data: Data) -> JSONKeyScan {
    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> JSONKeyScan in
        let bytes = raw.bindMemory(to: UInt8.self)
        // We track the keys of every open object. Containers close in reverse order, so all of those keys fit in one
        // array, `keys`, outermost object first. Each `{` pushes a frame start (the index in `keys` where that
        // object's keys begin), and each `[` pushes -1, so every `}` or `]` pops exactly one frame start. Closing an
        // object drops its keys, so the keys from an open object's frame start onward are always its own. For
        // example, after the "c" in {"a":1,"b":[{"c":2}]}, `keys` is [a, b, c] and `frameStarts` is [0, -1, 2].
        var keys: [String] = []
        var frameStarts: [Int] = []
        // When an object reaches `jsonKeyScanLinearLimit` keys, they're copied into a Set, stored under the object's
        // depth (`frameStarts.count - 1`), and its later keys go only into that Set. `keys` retains those initial
        // keys, and drops them later when the object closes, along with the set.
        var largeObjects: [Int: Set<String>] = [:]
        var expectKey = false
        var i = 0

        while i < bytes.count {
            switch bytes[i] {
            case 0:
                return .nulByte
            case UInt8(ascii: "{"):
                frameStarts.append(keys.count)
                expectKey = true
            case UInt8(ascii: "["):
                frameStarts.append(-1)
                expectKey = false
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                if let start = frameStarts.popLast(), start >= 0 {
                    keys.removeSubrange(start...)
                    if !largeObjects.isEmpty {
                        largeObjects[frameStarts.count] = nil
                    }
                }
                expectKey = false
            case UInt8(ascii: ","):
                // Strings inside arrays aren't keys, which the frame check below handles.
                expectKey = true
            case UInt8(ascii: "\""):
                // Find the closing quote, returning `.nulByte` if the string contains a NUL byte, and noting
                // whether it needs more than UTF-8 decoding.
                let start = i + 1
                var end = start
                var plain = true
                while end < bytes.count, bytes[end] != UInt8(ascii: "\"") {
                    if bytes[end] == 0 {
                        return .nulByte
                    }
                    if bytes[end] == UInt8(ascii: "\\") {
                        plain = false
                        end += 1
                        if end < bytes.count, bytes[end] == 0 {
                            return .nulByte
                        }
                    }
                    end += 1
                }
                end = min(end, bytes.count)
                // A string right after `{` or `,` in an object is a key. We compare it with the object's earlier
                // keys, then record it. This will be a linear scan for small objects, and a set lookup for larger
                // objects.
                if expectKey, let frameStart = frameStarts.last, frameStart >= 0 {
                    // A view of the key's bytes in the input, so they're copied only once, into the String. It's
                    // only used inside `withUnsafeBytes`, where the input stays valid.
                    let contents = UnsafeBufferPointer(rebasing: bytes[start..<end])
                    let key = plain ? String(decoding: contents, as: UTF8.self) : decodeJSONStringContents(contents)
                    let depth = frameStarts.count - 1
                    let count = keys.count - frameStart
                    if count < jsonKeyScanLinearLimit {
                        if keys[frameStart...].contains(key) {
                            return .duplicate
                        }
                        keys.append(key)
                        if count + 1 == jsonKeyScanLinearLimit {
                            largeObjects[depth] = Set(keys[frameStart...])
                        }
                    } else if largeObjects[depth]!.insert(key).inserted == false {
                        return .duplicate
                    }
                }
                expectKey = false
                i = end
            default:
                break
            }
            i += 1
        }
        return .unique
    }
}

/// Decodes the contents of a JSON string literal, without its quotes. This ensures keys will compare in the same way
/// the `JSONSerialization`/`JSONDecoder` parsers will compare them.
/// Escapes like `\n` are expanded in-place to the characters they represent. A `\uXXXX` escape holds one UTF-16 code
/// unit, so a character above U+FFFF (most emoji, for example) is written as two escapes, a high surrogate escape
/// followed by a low surrogate escape, which combine into one character. Malformed escapes and lone surrogate escapes
/// become U+FFFD.
private func decodeJSONStringContents(_ bytes: UnsafeBufferPointer<UInt8>) -> String {
    var out: [UInt8] = []
    out.reserveCapacity(bytes.count)

    // Reads the four hex digits of a `\uXXXX` escape starting at `index`, or returns nil if they're malformed.
    func hex4(at index: Int) -> UInt32? {
        guard index + 4 <= bytes.count else {
            return nil
        }
        var value: UInt32 = 0
        for byte in bytes[index..<index + 4] {
            let digit: UInt8
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = byte - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = byte - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = byte - UInt8(ascii: "A") + 10
            default: return nil
            }
            value = value << 4 | UInt32(digit)
        }
        return value
    }

    func append(_ scalar: Unicode.Scalar) {
        out.append(contentsOf: String(scalar).utf8)
    }

    // We copy bytes through unchanged until we encounter a backslash. Then we replace the escape sequence with the
    // character it stands for. A backslash as the last character has nothing to escape, so we copy that verbatim.
    var i = 0
    while i < bytes.count {
        let byte = bytes[i]
        guard byte == UInt8(ascii: "\\"), i + 1 < bytes.count else {
            out.append(byte)
            i += 1
            continue
        }
        let escape = bytes[i + 1]
        i += 2
        // JSON has two kinds of escapes: a backslash and one character (\" \\ \/ \b \f \n \r \t), and `\uXXXX`, which
        // gives a UTF-16 code unit in hex. Any other character after a backslash is malformed.
        switch escape {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): out.append(escape)
        case UInt8(ascii: "b"): out.append(0x08)
        case UInt8(ascii: "f"): out.append(0x0C)
        case UInt8(ascii: "n"): out.append(0x0A)
        case UInt8(ascii: "r"): out.append(0x0D)
        case UInt8(ascii: "t"): out.append(0x09)
        case UInt8(ascii: "u"):
            guard let high = hex4(at: i) else {
                append("\u{FFFD}")
                continue
            }
            i += 4
            // A high surrogate escape followed by a low surrogate escape encodes one scalar.
            if (0xD800...0xDBFF).contains(high), i + 6 <= bytes.count, bytes[i] == UInt8(ascii: "\\"),
                bytes[i + 1] == UInt8(ascii: "u"), let low = hex4(at: i + 2), (0xDC00...0xDFFF).contains(low)
            {
                i += 6
                append(Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00))!)
            } else {
                append(Unicode.Scalar(high) ?? "\u{FFFD}")
            }
        default:
            append("\u{FFFD}")
        }
    }
    return String(decoding: out, as: UTF8.self)
}
