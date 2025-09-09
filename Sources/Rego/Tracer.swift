import Foundation
import IR

extension OPA {
    /// Namespace for tracing-related types
    public enum Trace {
    }
}

extension OPA.Trace {
    /// Specifies the tracing verbosity
    public enum Level: String, Codable, Hashable, Sendable {
        // Subset of the standard OPA "explain" levels, add more as needed
        case none
        case full
        case note
    }

    /// Describes the type of traceable operation that occured
    public enum Operation: String, Codable, Hashable, Sendable {
        // Subset of the Go OPA topdown trace op's, add more as needed
        case enter
        case eval
        case fail
        case exit
        case note
    }

    /// Describes the source location at which a trace event occured
    public struct Location: Codable, Hashable, Sendable {
        public var row: Int = 0
        public var col: Int = 0
        public var file: String = "<unknown>"

        var string: String {
            return "\(file):\(row):\(col)"
        }
    }

    /// A tracer records events during evaluation
    public protocol QueryTracer {
        func traceEvent(_ event: any TraceableEvent)
    }

    /// A tracer which can be used when no tracing is desired
    public struct NoOpQueryTracer: QueryTracer {
        public func traceEvent(_ event: any TraceableEvent) {}
        public init() {}
    }

    /// A tracer which buffers events
    public class BufferedQueryTracer: QueryTracer {
        var level: OPA.Trace.Level
        var traceEvents: [any TraceableEvent] = []

        public init(level: OPA.Trace.Level) {
            self.level = level
        }
    }

    /// TraceEvent is defined as a protocol and may be implemented by the
    /// different evaluators as they will likely have additional metadata and
    /// requirements for serialization/formatting
    public protocol TraceableEvent: Encodable, Sendable {
        var operation: OPA.Trace.Operation { get }
        var message: String { get }
        var location: OPA.Trace.Location { get }
    }
}

extension OPA.Trace.BufferedQueryTracer {
    public func traceEvent(_ event: any OPA.Trace.TraceableEvent) {
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
    public func prettyPrint(to file: FileHandle) {
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
            file.write(event.location.string.data(using: .utf8)!)

            // computed padding to align the op + message plus a little extra space between
            // the location and op strings
            let padding = widestLocationStringSize - event.location.string.count + 4
            for _ in 0..<padding {
                file.write(" ".data(using: .utf8)!)
            }

            for _ in 0..<currentIndent {
                file.write("| ".data(using: .utf8)!)
            }

            file.write("\(event.operation) \(event.message)".data(using: .utf8)!)

            switch event.operation {
            case .enter:
                currentIndent += 1
            case .exit:
                currentIndent -= 1
            default:
                break
            }
            file.write("\n".data(using: .utf8)!)
        }
    }
}
