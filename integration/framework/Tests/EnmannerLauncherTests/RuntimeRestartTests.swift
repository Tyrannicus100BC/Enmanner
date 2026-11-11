import AppKit
import XCTest
@testable import EnmannerLauncher

@MainActor
final class RuntimeRestartTests: XCTestCase {
    func testFullRestartAndTryAgainRerunStartupTasks() async throws {
        let fileManager = FileManager.default
        let project = fileManager.temporaryDirectory
            .appendingPathComponent("Runtime Restart \(UUID())", isDirectory: true)
        let integration = project.appendingPathComponent("enmanner", isDirectory: true)
        try fileManager.createDirectory(at: integration, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: project) }

        let identifier = "local.enmanner.restart-\(UUID().uuidString.lowercased())"
        let name = "Runtime Restart Test"
        try """
        {
          "version": 3,
          "name": "\(name)",
          "identifier": "\(identifier)",
          "application": {"component": "web", "endpoint": "http"},
          "components": {
            "prepare": {"kind": "task", "command": ["/usr/bin/touch", "prepared"]},
            "web": {
              "dependsOn": ["prepare"],
              "command": ["/usr/bin/python3", "server.py", "${self.endpoints.http.port}"],
              "endpoints": {"http": {"protocol": "http"}},
              "readiness": {"endpoint": "http", "timeoutSeconds": 5}
            }
          }
        }
        """.write(to: integration.appendingPathComponent("enmanner.json"), atomically: true, encoding: .utf8)
        try """
        from http.server import HTTPServer, SimpleHTTPRequestHandler
        from pathlib import Path
        import sys

        if not Path("prepared").is_file():
            sys.exit(41)
        if Path("block-startup").exists():
            sys.exit(42)
        HTTPServer(("127.0.0.1", int(sys.argv[1])), SimpleHTTPRequestHandler).serve_forever()
        """.write(to: project.appendingPathComponent("server.py"), atomically: true, encoding: .utf8)

        let app = NSApplication.shared
        let delegate = AppDelegate(
            bundleURL: project.appendingPathComponent("\(name).app"),
            environment: [
                "ENMANNER_TEST_STATUS_FILE": project.appendingPathComponent("ready.json").path,
                "ENMANNER_TEST_SUPPRESS_BROWSER": "1",
                "ENMANNER_TEST_ENABLE_RUNTIME_CONTROL": "1",
            ]
        )
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification, object: app)
        )
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification, object: app)
            )
            app.windows.first(where: { $0.title == name })?.close()
        }

        let control = URL(fileURLWithPath: "/tmp/enmanner-\(getuid())")
            .appendingPathComponent(identifier)
        let statusURL = control.appendingPathComponent("status.json")
        let marker = project.appendingPathComponent("prepared")
        let startupBlock = project.appendingPathComponent("block-startup")

        let initial = try await waitForStatus("ready", generation: 1, at: statusURL)
        XCTAssertTrue(fileManager.fileExists(atPath: marker.path))
        try fileManager.removeItem(at: marker)
        try requestFullRestart(in: control)
        let restarted = try await waitForStatus("ready", generation: 2, at: statusURL)
        XCTAssertTrue(fileManager.fileExists(atPath: marker.path))
        XCTAssertEqual(restarted.applicationURL, initial.applicationURL)

        try fileManager.removeItem(at: marker)
        try Data().write(to: startupBlock)
        try requestFullRestart(in: control)
        _ = try await waitForStatus("failed", generation: 2, at: statusURL)
        XCTAssertTrue(fileManager.fileExists(atPath: marker.path))

        let window = try XCTUnwrap(app.windows.first(where: { $0.title == name }))
        let content = try XCTUnwrap(window.contentView)
        let retry = try XCTUnwrap(retryButton(in: content))
        XCTAssertFalse(retry.isHiddenOrHasHiddenAncestor)
        try fileManager.removeItem(at: startupBlock)
        try fileManager.removeItem(at: marker)
        retry.performClick(nil)
        _ = try await waitForStatus("ready", generation: 3, at: statusURL)
        XCTAssertTrue(fileManager.fileExists(atPath: marker.path))
    }

    private struct Status: Decodable {
        let state: String
        let runtimeGeneration: Int
        let applicationURL: String
    }

    private func waitForStatus(
        _ state: String,
        generation: Int,
        at url: URL
    ) async throws -> Status {
        var lastStatus: Status?
        let deadline = ContinuousClock.now + .seconds(8)
        while ContinuousClock.now < deadline {
            if let data = try? Data(contentsOf: url),
               let status = try? JSONDecoder().decode(Status.self, from: data) {
                lastStatus = status
                if status.state == state && status.runtimeGeneration == generation {
                    return status
                }
                if status.state == "failed" && state != "failed" {
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        return try XCTUnwrap(nil as Status?, "Expected \(state) generation \(generation), got \(String(describing: lastStatus))")
    }

    private func requestFullRestart(in directory: URL) throws {
        let id = UUID().uuidString
        try """
        {"schemaVersion": 1, "requestID": "\(id)", "action": "restart"}
        """.write(
            to: directory.appendingPathComponent("request-\(id).json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func retryButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == "Try Again" {
            return button
        }
        for subview in view.subviews {
            if let button = retryButton(in: subview) { return button }
        }
        return nil
    }
}
