import Foundation
import IR

public protocol QueryTracer {
    func traceEvent(_ event: any TraceableEvent)
}

public enum TraceLevel: String, Codable, Equatable, Sendable {
    // Subset of the standard OPA "explain" levels, add more as needed
    case none
    case full
    case note
}

public enum TraceOperation: String, Codable, Equatable, Sendable {
    // Subset of the Go OPA topdown trace op's, add more as needed
    case enter
    case eval
    case fail
    case exit
    case note
}

// TraceEvent is defined as a protocol and may be implemented by the
// different evaluators as they will likely have additional metadata and
// requirements for serialization/formatting
public protocol TraceableEvent: Encodable, Sendable {
    var operation: TraceOperation { get }
    var message: String { get }
    var location: TraceLocation { get }
}

public struct TraceLocation: Codable, Equatable, Sendable {
    public var row: Int = 0
    public var col: Int = 0
    public var file: String = "<unknown>"

    var string: String {
        return "\(file):\(row):\(col)"
    }
}

public struct NoOpQueryTracer: QueryTracer {
    public func traceEvent(_ event: any TraceableEvent) {}
    public init() {}
}

public class BufferedQueryTracer: QueryTracer {
    var level: TraceLevel
    var traceEvents: [any TraceableEvent] = []

    public init(level: TraceLevel) {
        self.level = level
    }

    public func traceEvent(_ event: any TraceableEvent) {
        guard level != .none else {
            return
        }
        if level == .note && event.operation != .note {
            // in "note" mode, skip everything except those operations
            return
        }
        self.traceEvents.append(event)
    }

    // TODO: Where's the io.Writer at?
    public func prettyPrint(out: FileHandle) {
        var currentIndent = 0

        var widestLocationStringSize = 0
        for event in self.traceEvents {
            if event.location.string.count > widestLocationStringSize {
                widestLocationStringSize = event.location.string.count
            }
        }

        // format follows this pattern for nested events (keying off "enter" and "exit")
        // <location> <computed padding> <op> <message>
        // <location> <computed padding> | <op> <message>
        // <location> <computed padding> | | <op> <message>
        // <location> <computed padding> | <op> <message>
        // <location> <computed padding> <op> <message>

        for event in traceEvents {
            // location
            out.write(event.location.string.data(using: .utf8)!)

            // computed padding to align the op + message plus a little extra space between
            // the location and op strings
            let padding = widestLocationStringSize - event.location.string.count + 4
            for _ in 0..<padding {
                out.write(" ".data(using: .utf8)!)
            }

            for _ in 0..<currentIndent {
                out.write("| ".data(using: .utf8)!)
            }

            out.write("\(event.operation) \(event.message)".data(using: .utf8)!)

            switch event.operation {
            case .enter:
                currentIndent += 1
            case .exit:
                currentIndent -= 1
            default:
                break
            }
            out.write("\n".data(using: .utf8)!)
        }
    }
}
