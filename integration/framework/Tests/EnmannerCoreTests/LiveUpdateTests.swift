import XCTest
@testable import EnmannerCore

final class LiveUpdateTests: XCTestCase {
    func testSessionPersistsPauseAndResumeAndRemovesEphemeralFiles() throws {
        let session = try LiveUpdateSession()
        defer { session.stop() }
        let file = URL(fileURLWithPath: try XCTUnwrap(session.environment["ENMANNER_LIVE_UPDATES_FILE"]))
        func state() throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        }
        XCTAssertFalse(session.isConnected)
        XCTAssertEqual(try state()["revision"] as? Int, 0)
        try session.setPaused(true)
        XCTAssertEqual(try state()["paused"] as? Bool, true)
        try session.setPaused(false)
        XCTAssertEqual(try state()["revision"] as? Int, 1)
        try session.setPaused(false)
        XCTAssertEqual(try state()["revision"] as? Int, 1)
        let ack = session.directory.appendingPathComponent("state.json.ack")
        try JSONSerialization.data(withJSONObject: ["adapter": "vite", "timestamp": Date().timeIntervalSince1970]).write(to: ack)
        XCTAssertTrue(session.isConnected)
        try JSONSerialization.data(withJSONObject: ["adapter": "vite", "timestamp": Date().timeIntervalSince1970 - 10]).write(to: ack)
        XCTAssertFalse(session.isConnected)
        session.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.directory.path))
    }

    func testLiveUpdatesCapabilityValidationAndRoundTrip() throws {
        let base = #"{"version":3,"name":"Test","identifier":"local.test.app","application":{"command":["/usr/bin/true"]},CONFIGURATION}"#
        let configurations = [
            (#""liveUpdates":{"adapter":"vite"}"#, "vite", true),
            (#""liveUpdates":{"adapter":"unknown"}"#, "unknown", true),
            (#""liveUpdates":{"enabled":false}"#, "vite", false)
        ]
        for (configuration, adapter, enabled) in configurations {
            let data = Data(base.replacingOccurrences(of: "CONFIGURATION", with: configuration).utf8)
            let manifest = try JSONDecoder().decode(EnmannerManifest.self, from: data)
            XCTAssertEqual(manifest.liveUpdates, .init(adapter: adapter, enabled: enabled))
            let issues = ManifestValidator.validate(manifest, projectURL: URL(fileURLWithPath: "/tmp"))
            XCTAssertEqual(issues.contains("liveUpdates.adapter must be vite."), adapter != "vite")
            XCTAssertEqual(try JSONDecoder().decode(EnmannerManifest.self, from: JSONEncoder().encode(manifest)), manifest)
        }
    }
}
