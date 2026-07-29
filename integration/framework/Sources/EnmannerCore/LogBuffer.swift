import Foundation

public final class LogBuffer: @unchecked Sendable {
    public enum Stream: String, Sendable {
        case launcher = "enmanner"
        case stdout
        case stderr
    }

    private let queue = DispatchQueue(label: "local.enmanner.log-buffer")
    private var entries: [String] = []
    private var lastMessageKey: String?
    private var repeatedCount = 0
    private let maximumEntries: Int
    public var onChange: (@Sendable (String) -> Void)?

    public init(maximumEntries: Int = 500) {
        self.maximumEntries = maximumEntries
    }

    public func append(
        _ message: String,
        stream: Stream = .launcher,
        component: String? = nil
    ) {
        let cleanMessage = message.trimmingCharacters(in: .newlines)
        guard !cleanMessage.isEmpty else { return }

        let timestamp = Self.timestampFormatter.string(from: Date())
        let source = component.map { "[\($0)] " } ?? ""
        let entry = "[\(timestamp)] \(source)[\(stream.rawValue)] \(cleanMessage)"
        let messageKey = "\(component ?? "")\u{0}\(stream.rawValue)\u{0}\(cleanMessage)"
        queue.async { [weak self] in
            guard let self else { return }
            if self.lastMessageKey == messageKey, !self.entries.isEmpty {
                self.repeatedCount += 1
                self.entries[self.entries.count - 1] =
                    "\(entry) (repeated \(self.repeatedCount)×)"
            } else {
                self.lastMessageKey = messageKey
                self.repeatedCount = 1
                self.entries.append(entry)
            }
            if self.entries.count > self.maximumEntries {
                self.entries.removeFirst(self.entries.count - self.maximumEntries)
            }
            let snapshot = self.entries.joined(separator: "\n")
            self.onChange?(snapshot)
        }
    }

    public func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
