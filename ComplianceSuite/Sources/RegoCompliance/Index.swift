import Foundation

// CaseIndex is an index of test cases.
// [ {"file": "...", "note": ["", "", ...] } ]
struct CaseIndex: Codable {
    let index: [IndexEntry]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var out: [IndexEntry] = []
        if let count = container.count {
            out.reserveCapacity(count)
        }
        while !container.isAtEnd {
            out.append(try container.decode(IndexEntry.self))
        }
        self.index = out
    }
}

struct IndexEntry: Codable {
    let file: String
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case file = "file"
        case notes = "note"
    }
}

// TestFilter is a test case filter supporting filtering by filename and individual note
// annotations.
public struct TestFilter {
    public var file: Regex<AnyRegexOutput>? = nil
    public var note: Regex<AnyRegexOutput>? = nil

    public init(from s: String) throws {
        let parts = s.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        switch parts.count {
        case 0:
            break
        case 1:
            let f = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !f.isEmpty else {
                break
            }
            self.file = try Regex(f)
        default:
            let f = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let n = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !f.isEmpty {
                self.file = try Regex(f)
            }
            if !n.isEmpty {
                self.note = try Regex(n)
            }
        }
    }
}

extension CaseIndex {
    static func load(fromURL url: URL) throws -> CaseIndex {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CaseIndex.self, from: data)
    }

    func filter(withFilter filter: TestFilter?, andBase base: URL) -> [URL] {
        var out: Set<URL> = []

        for entry in self.index {
            let url = URL(string: entry.file, relativeTo: base)!
            guard let filter else {
                out.insert(url)
                continue
            }
            let components = url.pathComponents
            var filename: String
            switch components.count {
            case 1:
                filename = components[0]
            case 2...:
                filename = components[components.count - 2] + "/" + components[components.count - 1]
            default:
                // Includes ...0
                // Invalid file entry, skip it
                continue
            }

            // If a file pattern is defined, ensure the current file matches
            if let pattern = filter.file {
                guard filename.contains(pattern) else {
                    continue
                }
            }

            guard let pattern = filter.note else {
                // No notes pattern, so all match.
                out.insert(url)
                continue
            }

            // Check if any notes from the index match
            guard entry.notes.contains(where: { $0.contains(pattern) }) else {
                // No matches, skip the file
                continue
            }
            out.insert(url)
        }

        return out.sorted(by: { $0.path() < $1.path() })
    }
}
