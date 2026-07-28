import Foundation

public actor ReadinessChecker {
    public typealias Probe = @Sendable (URL) async -> Bool

    private let probe: Probe

    public init(probe: Probe? = nil) {
        self.probe = probe ?? { url in
            await Self.httpProbe(url: url)
        }
    }

    public func waitUntilReady(
        url: URL,
        timeout: TimeInterval,
        intervalNanoseconds: UInt64 = 300_000_000
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !Task.isCancelled && Date() < deadline {
            if await probe(url) {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return false
    }

    private static func httpProbe(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...399).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
