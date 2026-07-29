import XCTest
@testable import EnmannerCore

final class ManifestTests: XCTestCase {
    func testDecodesVersionTwoBrowserManifest() throws {
        let json = """
        {
          "version": 2,
          "name": "Minimal",
          "identifier": "local.enmanner.minimal",
          "server": {
            "command": ["/usr/bin/true"],
            "workingDirectory": ".",
            "environment": {},
            "readiness": {
              "url": "http://127.0.0.1:${ENMANNER_PORT}/",
              "timeoutSeconds": 5
            }
          },
          "window": {
            "mode": "browser",
            "width": 800,
            "height": 600,
            "resizable": true
          }
        }
        """

        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(manifest.window.mode, .browser)
    }

    func testValidationRejectsInvalidReadinessMatchers() {
        let manifest = EnmannerManifest(
            version: 2,
            name: "Matchers",
            identifier: "local.enmanner.matchers",
            server: .init(
                command: ["/usr/bin/true"],
                readiness: .init(
                    url: "http://127.0.0.1:43120/",
                    acceptableStatusCodes: [],
                    contentTypeContains: ""
                )
            )
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertTrue(
            issues.contains { $0.contains("acceptableStatusCodes") }
        )
        XCTAssertTrue(
            issues.contains { $0.contains("contentTypeContains") }
        )
    }

    func testDecodesEmbeddedVersionTwoManifest() throws {
        let data = Data(
            """
            {
              "version": 2,
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
              }
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(EnmannerManifest.self, from: data)

        XCTAssertEqual(manifest.version, 2)
        XCTAssertEqual(manifest.name, "Household Finances")
        XCTAssertEqual(manifest.server.command, ["npm", "run", "dev"])
        XCTAssertEqual(manifest.server.preferredPort, 43120)
        XCTAssertEqual(manifest.window.mode, .embedded)
    }

    func testDecodesUserConfigurationDefaults() throws {
        let data = Data(
            """
            {
              "version": 2,
              "name": "Configured",
              "identifier": "local.enmanner.configured",
              "userConfiguration": {
                "template": ".env.example",
                "fields": [
                  {
                    "key": "API_KEY",
                    "label": "API key",
                    "type": "secret",
                    "required": true
                  },
                  {
                    "key": "FEATURE_ENABLED",
                    "label": "Feature enabled"
                  }
                ]
              },
              "server": {
                "command": ["/usr/bin/true"],
                "workingDirectory": ".",
                "readiness": {
                  "url": "http://127.0.0.1:${ENMANNER_PORT}/",
                  "timeoutSeconds": 5
                }
              },
              "window": {
                "mode": "browser",
                "width": 800,
                "height": 600,
                "resizable": true
              }
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: data
        )

        XCTAssertEqual(manifest.userConfiguration?.file, ".env")
        XCTAssertEqual(
            manifest.userConfiguration?.fields[0].type,
            .secret
        )
        XCTAssertEqual(
            manifest.userConfiguration?.fields[1].type,
            .string
        )
        XCTAssertFalse(
            manifest.userConfiguration?.fields[1].required ?? true
        )
    }

    func testMalformedManifestProducesUsefulError() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("enmanner.json")
        try Data(#"{"version":"wrong"}"#.utf8).write(to: url)

        XCTAssertThrowsError(try ManifestLoader.load(from: url)) { error in
            guard case EnmannerError.malformedManifest = error else {
                return XCTFail("Expected malformedManifest, received \(error)")
            }
            XCTAssertEqual(
                (error as? EnmannerError)?.diagnosticPath,
                "version"
            )
        }
    }

    func testMissingEnvironmentDefaultsToEmptyDictionary() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("enmanner.json")
        try Data(
            """
            {
              "version": 2,
              "name": "Defaults",
              "identifier": "local.enmanner.defaults",
              "server": {
                "command": ["/usr/bin/true"],
                "workingDirectory": ".",
                "readiness": {
                  "url": "http://127.0.0.1:${ENMANNER_PORT}/",
                  "timeoutSeconds": 5
                }
              },
              "window": {
                "mode": "browser",
                "width": 800,
                "height": 600,
                "resizable": true
              }
            }
            """.utf8
        ).write(to: url)

        let manifest = try ManifestLoader.load(from: url)

        XCTAssertEqual(manifest.server.environment, [:])
    }

    func testMissingRequiredFieldReportsCodingPath() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("enmanner.json")
        try Data(
            """
            {
              "version": 2,
              "name": "Missing readiness",
              "identifier": "local.enmanner.missing",
              "server": {
                "command": ["/usr/bin/true"],
                "workingDirectory": "."
              },
              "window": {
                "mode": "browser",
                "width": 800,
                "height": 600,
                "resizable": true
              }
            }
            """.utf8
        ).write(to: url)

        XCTAssertThrowsError(try ManifestLoader.load(from: url)) { error in
            XCTAssertEqual(
                (error as? EnmannerError)?.diagnosticPath,
                "server.readiness"
            )
            XCTAssertTrue(error.localizedDescription.contains("Missing required field"))
        }
    }

    func testWindowModeLifecycleBehavior() {
        XCTAssertEqual(EnmannerManifest.Window().mode, .browser)
        XCTAssertFalse(EnmannerManifest.Window.Mode.embedded.launchesWindowless)
        XCTAssertTrue(
            EnmannerManifest.Window.Mode.embedded.keepsRunningAfterLastWindowClosed
        )
        XCTAssertTrue(EnmannerManifest.Window.Mode.browser.launchesWindowless)
        XCTAssertTrue(
            EnmannerManifest.Window.Mode.browser.keepsRunningAfterLastWindowClosed
        )
    }

    func testValidationRejectsVersionOneManifest() {
        let manifest = EnmannerManifest(
            version: 1,
            name: "Legacy",
            identifier: "local.enmanner.legacy",
            server: .init(
                command: ["/usr/bin/true"],
                readiness: .init(url: "http://127.0.0.1:43120/")
            )
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertTrue(issues.contains("version must be 2."))
    }

    func testValidationRejectsNonLoopbackAndTraversal() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 2,
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
            version: 2,
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
        let iconDirectory = directory.appendingPathComponent(
            "enmanner/icon",
            isDirectory: true
        )
        let modernIcon = iconDirectory.appendingPathComponent(
            "Modern.icon",
            isDirectory: true
        )
        let legacyIcon = iconDirectory.appendingPathComponent("Legacy.icns")
        try FileManager.default.createDirectory(
            at: modernIcon,
            withIntermediateDirectories: true
        )
        try Data().write(to: legacyIcon)

        for icon in [
            "enmanner/icon/Modern.icon",
            "enmanner/icon/Legacy.icns"
        ] {
            let manifest = EnmannerManifest(
                version: 2,
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

    func testValidationRejectsIconOutsideIntegrationDirectory() throws {
        let directory = try temporaryDirectory()
        try Data().write(
            to: directory.appendingPathComponent("RootIcon.icns")
        )
        let manifest = EnmannerManifest(
            version: 2,
            name: "Untidy Icon",
            identifier: "local.enmanner.untidy-icon",
            server: .init(
                command: ["/usr/bin/true"],
                readiness: .init(url: "http://127.0.0.1:43120/")
            ),
            icon: "RootIcon.icns"
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: directory
        )

        XCTAssertTrue(
            issues.contains { $0.contains("project-owned enmanner/ directory") }
        )
    }

    func testValidationRejectsUnsafeUserConfiguration() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 2,
            name: "Unsafe Configuration",
            identifier: "local.enmanner.unsafe-configuration",
            server: .init(
                command: ["/usr/bin/true"],
                readiness: .init(url: "http://127.0.0.1:43120/")
            ),
            userConfiguration: .init(
                file: ".enmanner/secrets.env",
                template: "missing.example",
                fields: [
                    .init(key: "NOT-VALID", label: ""),
                    .init(key: "NOT-VALID", label: "Duplicate")
                ]
            )
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: directory
        )

        XCTAssertTrue(issues.contains { $0.contains("outside .enmanner") })
        XCTAssertTrue(issues.contains { $0.contains("not a valid") })
        XCTAssertTrue(issues.contains { $0.contains("duplicated") })
        XCTAssertTrue(issues.contains { $0.contains("must have a label") })
        XCTAssertTrue(issues.contains { $0.contains("template does not exist") })
    }

    func testValidationRejectsTrackedUserConfigurationFile() throws {
        let directory = try temporaryDirectory()
        try Data("API_KEY=\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        try runGit(["init", "--quiet"], in: directory)
        try runGit(["add", ".env"], in: directory)

        let manifest = EnmannerManifest(
            version: 2,
            name: "Tracked Configuration",
            identifier: "local.enmanner.tracked-configuration",
            server: .init(
                command: ["/usr/bin/true"],
                readiness: .init(url: "http://127.0.0.1:43120/")
            ),
            userConfiguration: .init(
                fields: [
                    .init(key: "API_KEY", label: "API key", type: .secret)
                ]
            )
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: directory
        )

        XCTAssertTrue(issues.contains { $0.contains("tracked by Git") })
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
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
