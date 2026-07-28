import XCTest
@testable import EnmannerCore

final class ManifestTests: XCTestCase {
    func testDecodesVersionOneManifest() throws {
        let data = Data(
            """
            {
              "version": 1,
              "name": "Household Finances",
              "identifier": "local.enmanner.household-finances",
              "server": {
                "command": ["npm", "run", "dev"],
                "workingDirectory": ".",
                "environment": {"PORT": "${ENMANNER_PORT}"},
                "preferredPort": 43120,
                "readiness": {
                  "url": "http://127.0.0.1:${ENMANNER_PORT}/",
                  "timeoutSeconds": 30
                }
              },
              "window": {
                "mode": "embedded",
                "width": 1200,
                "height": 800,
                "resizable": true
              },
              "development": {"reload": "auto"}
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(EnmannerManifest.self, from: data)

        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.name, "Household Finances")
        XCTAssertEqual(manifest.server.command, ["npm", "run", "dev"])
        XCTAssertEqual(manifest.server.preferredPort, 43120)
        XCTAssertEqual(manifest.window.mode, .embedded)
    }

    func testMalformedManifestProducesUsefulError() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("enmanner.json")
        try Data(#"{"version":"wrong"}"#.utf8).write(to: url)

        XCTAssertThrowsError(try ManifestLoader.load(from: url)) { error in
            guard case EnmannerError.malformedManifest = error else {
                return XCTFail("Expected malformedManifest, received \(error)")
            }
        }
    }

    func testWindowModeLifecycleBehavior() {
        XCTAssertFalse(EnmannerManifest.Window.Mode.embedded.launchesWindowless)
        XCTAssertTrue(
            EnmannerManifest.Window.Mode.embedded.keepsRunningAfterLastWindowClosed
        )
        XCTAssertTrue(EnmannerManifest.Window.Mode.external.launchesWindowless)
        XCTAssertTrue(
            EnmannerManifest.Window.Mode.external.keepsRunningAfterLastWindowClosed
        )
    }

    func testValidationRejectsNonLoopbackAndTraversal() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 1,
            name: "Unsafe App",
            identifier: "local.enmanner.unsafe",
            server: .init(
                command: ["npm", "run", "dev"],
                workingDirectory: "..",
                readiness: .init(url: "http://0.0.0.0:${ENMANNER_PORT}/")
            )
        )

        let issues = ManifestValidator.validate(manifest, projectURL: directory)

        XCTAssertTrue(issues.contains { $0.contains("inside the project") })
        XCTAssertTrue(issues.contains { $0.contains("loopback") })
    }

    func testValidationRejectsPrivilegedPreferredPort() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 1,
            name: "Unsafe Port",
            identifier: "local.enmanner.unsafe-port",
            server: .init(
                command: ["npm", "run", "dev"],
                preferredPort: 80,
                readiness: .init(url: "http://127.0.0.1:${ENMANNER_PORT}/")
            )
        )

        let issues = ManifestValidator.validate(manifest, projectURL: directory)

        XCTAssertTrue(issues.contains { $0.contains("preferredPort") })
    }

    func testValidationAcceptsModernAndLegacyIconFormats() throws {
        let directory = try temporaryDirectory()
        let modernIcon = directory.appendingPathComponent(
            "Modern.icon",
            isDirectory: true
        )
        let legacyIcon = directory.appendingPathComponent("Legacy.icns")
        try FileManager.default.createDirectory(
            at: modernIcon,
            withIntermediateDirectories: true
        )
        try Data().write(to: legacyIcon)

        for icon in ["Modern.icon", "Legacy.icns"] {
            let manifest = EnmannerManifest(
                version: 1,
                name: "Icon App",
                identifier: "local.enmanner.icon-app",
                server: .init(
                    command: ["npm", "run", "dev"],
                    readiness: .init(
                        url: "http://127.0.0.1:${ENMANNER_PORT}/"
                    )
                ),
                icon: icon
            )

            let issues = ManifestValidator.validate(
                manifest,
                projectURL: directory
            )

            XCTAssertFalse(issues.contains { $0.contains("icon must be") })
        }
    }
}

extension XCTestCase {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("enmanner-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
