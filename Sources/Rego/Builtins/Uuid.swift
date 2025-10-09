import AST
import Foundation

private let uuidNamespace: String = "uuid"

extension BuiltinFuncs {
    /// Returns a RFC 4122 UUID string.
    /// In future implementations, this can become a custom UUID generation based on a random number generator
    /// correctly seeded with value derived from the key that is passed in the arguments.
    /// However, the spec just required UUID generation to be consistent *within* en evaluation, so caching the values is okay.
    static func makeRfc4122UUID(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let key) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "k", got: args[0].typeName, want: "string")
        }

        let existing: RegoValue? = ctx.cache[key, .namespace(uuidNamespace)]
        guard let existing else {
            let newUUID = RegoValue.string(UUID().uuidString)
            ctx.cache[key, .namespace(uuidNamespace)] = newUUID

            return newUUID
        }

        return existing
    }

    static func parseUUID(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let uuidString) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "uuid", got: args[0].typeName, want: "string")
        }

        guard let uuid = UUID(extended: uuidString) else {
            throw BuiltinError.evalError(msg: "invalid UUID format")
        }

        return .object(propertiesOf(uuid))
    }

    private static func propertiesOf(_ uuid: UUID) -> [RegoValue: RegoValue] {
        var p: [RegoValue: RegoValue] = [:]

        let version = uuid.version
        p["version"] = .number(NSNumber(value: version))
        p["variant"] = .string(uuid.variant)

        if version == 1 || version == 2 {
            let time = uuid.time
            if time > Int64.min {
                p["time"] = .number(NSNumber(value: time))
            }

            p["clocksequence"] = .number(NSNumber(value: uuid.clockSequence))
            p["nodeid"] = .string(Data(uuid.nodeId).hexEncodedWithSeparator(separator: "-"))
            p["macvariables"] = .string(uuid.macVars)

            if version == 2 {
                p["id"] = .number(NSNumber(value: uuid.idForV2))
                p["domain"] = .string(uuid.domain)
            }
        }

        return p
    }
}

///100s of a nanoseconds between epochs
private let g1582ns100: Int64 = 122_192_928_000_000_000
private let billion = Int64(1_000_000_000)

/// This UUID extension targets relaxed parsing from strings as well as
/// supports parsing of individual UUID properties
extension UUID {
    /// Creates a UUID from an extended string representation.
    /// To be backwards compatible with Golang implementation of the UUID
    /// this supports parsing UUID that start and end with {}, have urn:uuid: prefix
    /// or do not contain dashes in their string representation.
    /// - Parameter value: The extended string representation of the UUID.
    init?(extended value: String) {
        var maybeUuid = value
        // Preemptively remove first and last brace
        if maybeUuid.hasPrefix("{") { maybeUuid.removeFirst() }
        if maybeUuid.hasSuffix("}") { maybeUuid.removeLast() }
        // Preemptively remove urn:uuid:
        if maybeUuid.hasPrefix("urn:uuid:") { maybeUuid.trimPrefix("urn:uuid:") }
        // Account for uuidString having no dashes - insert them
        if maybeUuid.count == 32 && !maybeUuid.contains("-") {
            // Convert to xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx to xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
            maybeUuid =
                String(maybeUuid.prefix(8)) + "-" + String(maybeUuid.dropFirst(8).prefix(4)) + "-"
                + String(maybeUuid.dropFirst(12).prefix(4)) + "-" + String(maybeUuid.dropFirst(16).prefix(4)) + "-"
                + String(maybeUuid.dropFirst(20))
        }

        let u = UUID(uuidString: maybeUuid)
        guard u != nil else {
            return nil
        }
        self = u!
    }

    fileprivate var version: UInt8 {
        return self.uuid.6 >> 4
    }

    fileprivate var variant: String {
        if (uuid.8 & 0xc0) == 0x80 {
            return "RFC4122"
        }
        if (uuid.8 & 0xe0) == 0xc0 {
            return "Microsoft"
        }
        if (uuid.8 & 0xe0) == 0xe0 {
            return "Future"
        }
        return "Reserved"
    }

    /// Time returns the time in 100s of nanoseconds since 15 Oct 1582 encoded in the uuid.
    /// The time is only defined for version 1, 2, 6 and 7 UUIDs.
    /// For other UUID versions, this returns Int64.min
    fileprivate var time: Int64 {
        let version = self.version
        var t: Int64 = 0

        guard version == 1 || version == 2 || version == 6 || version == 7 else {
            return Int64.min
        }

        switch version {
        case 6:
            let time = bigEndianUInt64([uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7])
            t = Int64(time)
        case 7:
            let time = bigEndianUInt64([uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7])
            t = Int64(Int64((time >> 16)) * 10000 + g1582ns100)
        default:
            var time = Int64(bigEndianUInt32([uuid.0, uuid.1, uuid.2, uuid.3]))
            time |= Int64(bigEndianUInt16([uuid.4, uuid.5])) << 32
            time |= Int64(bigEndianUInt16([uuid.6, uuid.7]) & 0xfff) << 48
            t = Int64(time)
        }

        // Now we convert time to the number of seconds and nanoseconds using the Unix
        // epoch of 1 Jan 1970.
        var seconds = Int64(t - g1582ns100)
        let nanoseconds = (seconds % 10_000_000) * 100
        seconds /= 10_000_000

        return seconds * billion + nanoseconds
    }

    fileprivate var clockSequence: Int {
        return Int(bigEndianUInt16([uuid.8, uuid.9]) & 0x3fff)
    }

    fileprivate var nodeId: [UInt8] {
        return [uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15]
    }

    fileprivate var idForV2: UInt32 {
        return bigEndianUInt32([uuid.0, uuid.1, uuid.2, uuid.3])
    }

    fileprivate var macVars: String {
        let input = uuid.10  // first byte of NodeId
        if input & 0b11 == 0b11 {
            return "local:multicast"
        }
        if input & 0b01 == 0b01 {
            return "global:multicast"
        }
        if input & 0b10 == 0b10 {
            return "local:unicast"
        }
        return "global:unicast"
    }

    fileprivate var domain: String {
        let d = uuid.9
        switch d {
        case 0:
            return "Person"
        case 1:
            return "Group"
        case 2:
            return "Org"
        default:
            return String(format: "Domain%d", Int(d))
        }
    }
}

private func bigEndianUInt64(_ b: [UInt8]) -> UInt64 {
    return UInt64(b[7]) | UInt64(b[6]) << 8 | UInt64(b[5]) << 16 | UInt64(b[4]) << 24 | UInt64(b[3]) << 32 | UInt64(
        b[2]) << 40 | UInt64(b[1]) << 48 | UInt64(b[0]) << 56
}

private func bigEndianUInt32(_ b: [UInt8]) -> UInt32 {
    return UInt32(b[3]) | UInt32(b[2]) << 8 | UInt32(b[1]) << 16 | UInt32(b[0]) << 24
}

private func bigEndianUInt16(_ b: [UInt8]) -> UInt16 {
    return UInt16(b[1]) | UInt16(b[0]) << 8
}
