import AppKit
import EnmannerCore
import XCTest
@testable import EnmannerLauncher

@MainActor
final class MainWindowControllerTests: XCTestCase {
    func testFailureLogsShowLatestOutputWithoutCoveringControls() async throws {
        _ = NSApplication.shared
        let controller = MainWindowController(
            manifest: EnmannerManifest(
                version: 3,
                name: "Failure Logs Test",
                identifier: "local.enmanner.failure-logs",
                application: .init(command: ["/usr/bin/false"], readiness: .init(path: "/"))
            )
        )
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        window.setContentSize(NSSize(width: 520, height: 420))
        let root = try XCTUnwrap(window.contentView)
        let logs = (1...80)
            .map { "[backend] Startup output line \($0)" }
            .joined(separator: "\n")
        controller.updateLogs(logs)
        controller.showFailure(
            message: String(repeating: "Could not connect to the database. ", count: 8),
            command: ["/usr/bin/false"],
            exitStatus: 1
        )

        let toggle = try XCTUnwrap(button(titled: "View Logs", in: root))
        let retry = try XCTUnwrap(button(titled: "Try Again", in: root))
        let scrollView = try XCTUnwrap(
            root.subviews.compactMap { $0 as? NSScrollView }.first
        )
        let textView = try XCTUnwrap(scrollView.documentView as? NSTextView)
        XCTAssertTrue(scrollView.isHidden)

        toggle.performClick(nil)
        root.layoutSubtreeIfNeeded()

        XCTAssertFalse(scrollView.isHidden)
        XCTAssertEqual(toggle.title, "Hide Logs")
        XCTAssertEqual(textView.string, logs)
        XCTAssertGreaterThanOrEqual(textView.frame.width, scrollView.contentSize.width - 1)
        XCTAssertGreaterThan(textView.frame.height, scrollView.contentSize.height)
        for button in [retry, toggle] {
            let frame = button.convert(button.bounds, to: root)
            XCTAssertTrue(root.bounds.contains(frame))
            XCTAssertFalse(scrollView.frame.intersects(frame))
        }

        let layout = try XCTUnwrap(textView.layoutManager)
        let container = try XCTUnwrap(textView.textContainer)
        let lastGlyphIndex = try XCTUnwrap((0..<layout.numberOfGlyphs).last)
        let lastGlyph = NSRange(location: lastGlyphIndex, length: 1)
        let glyphRect = layout.boundingRect(forGlyphRange: lastGlyph, in: container)
            .offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
        XCTAssertFalse(glyphRect.isEmpty)
        XCTAssertTrue(textView.visibleRect.intersects(glyphRect))

        toggle.performClick(nil)
        XCTAssertTrue(scrollView.isHidden)
        XCTAssertEqual(toggle.title, "View Logs")
    }

    private func button(titled title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let button = button(titled: title, in: subview) { return button }
        }
        return nil
    }
}
