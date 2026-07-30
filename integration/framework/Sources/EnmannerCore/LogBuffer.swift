import Foundation

public final class LogBuffer: @unchecked Sendable {
    public enum Stream: String, Codable, Sendable {
        case launcher = "enmanner"
        case stdout
        case stderr
    }

    private let queue = DispatchQueue(label: "local.enmanner.log-buffer")
    private var entries: [String] = []
    private var lastMessageKey: String?
    private var repeatedCount = 0
    private var sensitiveValues: [String] = []
    private let maximumEntries: Int
    public var onChange: (@Sendable (String) -> Void)?

    public init(maximumEntries: Int = 500) {
        self.maximumEntries = maximumEntries
    }

    public func setSensitiveValues(_ values: [String]) {
        queue.sync {
            sensitiveValues = Array(
                Set(values.filter { $0.count >= 8 })
            ).sorted { $0.count > $1.count }
        }
    }

    public func redact(_ message: String) -> String {
        queue.sync {
            sensitiveValues.reduce(message) { result, value in
                result.replacingOccurrences(of: value, with: "[REDACTED]")
            }
        }
    }

    public func append(
        _ message: String,
        stream: Stream = .launcher,
        component: String? = nil
    ) {
        let cleanMessage = redact(message).trimmingCharacters(in: .newlines)
        guard !cleanMessage.isEmpty else { return }

        let timestamp = Self.timestampFormatter.string(from: Date())
        let source = component.map { "[\($0)] " } ?? ""
        let entry = "[\(timestamp)] \(source)[\(stream.rawValue)] \(cleanMessage)"
        let messageKey = "\(component ?? "")\u{0}\(stream.rawValue)\u{0}\(cleanMessage)"
        queue.sync {
            if lastMessageKey == messageKey, !entries.isEmpty {
                repeatedCount += 1
                entries[entries.count - 1] =
                    "\(entry) (repeated \(repeatedCount)×)"
            } else {
                lastMessageKey = messageKey
                repeatedCount = 1
                entries.append(entry)
            }
            if entries.count > maximumEntries {
                entries.removeFirst(entries.count - maximumEntries)
            }
            let snapshot = entries.joined(separator: "\n")
            onChange?(snapshot)
        }
    }

    public func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    public func recentEntries(limit: Int = 20) -> [String] {
        queue.sync {
            Array(entries.suffix(max(0, limit)))
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
