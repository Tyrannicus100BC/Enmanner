import XCTest
@testable import EnmannerCore

final class ManifestTests: XCTestCase {
    func testDecodesVersionThreeInlineApplication() throws {
        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: Data(
                """
                {
                  "version": 3,
                  "name": "Minimal",
                  "identifier": "local.enmanner.minimal",
                  "application": {
                    "command": ["/usr/bin/true"],
                    "environment": {
                      "PORT": "${self.endpoints.http.port}"
                    },
                    "preferredPort": 43120,
                    "readiness": {
                      "path": "/",
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
        )

        let graph = try RuntimeGraph.make(from: manifest)

        XCTAssertEqual(manifest.version, 3)
        XCTAssertEqual(manifest.components, [:])
        XCTAssertEqual(graph.applicationCommand, ["/usr/bin/true"])
        XCTAssertEqual(graph.applicationPreferredPort, 43120)
        XCTAssertEqual(graph.applicationComponent, "__application")
    }

    func testDecodesComponentGraphAndOrdersDependencies() throws {
        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: Data(
                """
                {
                  "version": 3,
                  "name": "Graph",
                  "identifier": "local.enmanner.graph",
                  "components": {
                    "database": {
                      "kind": "prerequisite",
                      "endpoints": {
                        "postgres": {
                          "protocol": "tcp",
                          "port": {"fixed": 5432}
                        }
                      },
                      "check": {
                        "type": "tcp",
                        "endpoint": "postgres"
                      }
                    },
                    "api": {
                      "dependsOn": ["database"],
                      "command": ["/usr/bin/true"],
                      "endpoints": {
                        "http": {
                          "protocol": "http",
                          "port": {}
                        }
                      },
                      "readiness": {
                        "endpoint": "http",
                        "path": "/health"
                      }
                    },
                    "frontend": {
                      "dependsOn": ["api"],
                      "command": ["/usr/bin/true"],
                      "environment": {
                        "API_URL": "${components.api.endpoints.http.url}"
                      },
                      "endpoints": {
                        "web": {
                          "protocol": "http",
                          "port": {"preferred": 45123}
                        }
                      },
                      "readiness": {
                        "endpoint": "web",
                        "path": "/"
                      }
                    }
                  },
                  "application": {
                    "component": "frontend",
                    "endpoint": "web"
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
        )

        let graph = try RuntimeGraph.make(from: manifest)

        XCTAssertLessThan(
            try XCTUnwrap(graph.startupOrder.firstIndex(of: "database")),
            try XCTUnwrap(graph.startupOrder.firstIndex(of: "api"))
        )
        XCTAssertLessThan(
            try XCTUnwrap(graph.startupOrder.firstIndex(of: "api")),
            try XCTUnwrap(graph.startupOrder.firstIndex(of: "frontend"))
        )
        XCTAssertEqual(graph.applicationComponent, "frontend")
        XCTAssertEqual(graph.applicationEndpoint, "web")
    }

    func testValidationRejectsCyclesAndUnknownReferences() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Cycle",
            identifier: "local.enmanner.cycle",
            application: .init(component: "first", endpoint: "http"),
            components: [
                "first": .init(
                    command: ["/usr/bin/true"],
                    dependsOn: ["second"],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ]
                ),
                "second": .init(
                    command: ["/usr/bin/true"],
                    dependsOn: ["first"]
                )
            ]
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: directory
        )

        XCTAssertTrue(issues.contains { $0.contains("dependency cycle") })
    }

    func testValidationRequiresExplicitDependencyForEndpointReference() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "References",
            identifier: "local.enmanner.references",
            application: .init(component: "frontend", endpoint: "http"),
            components: [
                "api": .init(
                    command: ["/usr/bin/true"],
                    endpoints: ["http": .init(protocol: .http)]
                ),
                "frontend": .init(
                    command: ["/usr/bin/true"],
                    environment: [
                        "API_URL": "${components.api.endpoints.http.url}"
                    ],
                    endpoints: ["http": .init(protocol: .http)]
                )
            ]
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: directory
        )

        XCTAssertTrue(
            issues.contains { $0.contains("without declaring it in dependsOn") }
        )
    }

    func testValidationRejectsInvalidProbeAndPublicEndpoint() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Unsafe",
            identifier: "local.enmanner.unsafe",
            application: .init(component: "web", endpoint: "listener"),
            components: [
                "web": .init(
                    command: ["/usr/bin/true"],
                    workingDirectory: "..",
                    endpoints: [
                        "listener": .init(
                            protocol: .tcp,
                            host: "0.0.0.0",
                            port: .init(preferred: 80)
                        )
                    ],
                    readiness: .init(
                        type: .http,
                        endpoint: "missing",
                        timeoutSeconds: 90_000
                    )
                )
            ]
        )

        let issues = ManifestValidator.validate(manifest, projectURL: directory)

        XCTAssertTrue(issues.contains { $0.contains("inside the project") })
        XCTAssertTrue(issues.contains { $0.contains("loopback") })
        XCTAssertTrue(issues.contains { $0.contains("preferred") })
        XCTAssertTrue(issues.contains { $0.contains("timeoutSeconds") })
        XCTAssertTrue(issues.contains { $0.contains("declared endpoint") })
        XCTAssertTrue(issues.contains { $0.contains("HTTP or HTTPS") })
    }

    func testDecodesTaskCompletionAndProcessReadiness() throws {
        let data = Data(
            """
            {
              "version": 3,
              "name": "Lifecycle Probes",
              "identifier": "local.enmanner.lifecycle-probes",
              "components": {
                "prepare": {
                  "kind": "task",
                  "command": ["/usr/bin/true"],
                  "endpoints": {
                    "http": {"protocol": "http", "port": {}}
                  },
                  "completion": {
                    "type": "http",
                    "endpoint": "http",
                    "timeoutSeconds": 1200
                  }
                },
                "worker": {
                  "kind": "service",
                  "dependsOn": ["prepare"],
                  "command": ["/usr/bin/true"],
                  "readiness": {
                    "type": "process",
                    "minimumUptimeSeconds": 3,
                    "timeoutSeconds": 10
                  }
                },
                "web": {
                  "kind": "service",
                  "dependsOn": ["worker"],
                  "command": ["/usr/bin/true"],
                  "endpoints": {
                    "http": {"protocol": "http", "port": {}}
                  },
                  "readiness": {"endpoint": "http"}
                }
              },
              "application": {"component": "web", "endpoint": "http"},
              "window": {
                "mode": "browser",
                "width": 1200,
                "height": 800,
                "resizable": true
              }
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: data
        )

        XCTAssertEqual(manifest.components["prepare"]?.completion?.type, .http)
        XCTAssertEqual(
            manifest.components["worker"]?.readiness?.minimumUptimeSeconds,
            3
        )
    }

    func testCommandPrerequisiteDecodesOutputMatcher() throws {
        let data = Data(
            """
            {
              "version": 3,
              "name": "Checks",
              "identifier": "local.enmanner.checks",
              "components": {
                "database": {
                  "kind": "prerequisite",
                  "check": {
                    "type": "command",
                    "command": ["/usr/bin/printf", "healthy"],
                    "success": {"stdoutEquals": "healthy"},
                    "timeoutSeconds": 3
                  }
                },
                "web": {
                  "dependsOn": ["database"],
                  "command": ["/usr/bin/true"],
                  "endpoints": {
                    "http": {"protocol": "http", "port": {}}
                  }
                }
              },
              "application": {"component": "web", "endpoint": "http"},
              "window": {
                "mode": "browser",
                "width": 800,
                "height": 600,
                "resizable": true
              }
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(EnmannerManifest.self, from: data)

        XCTAssertEqual(
            manifest.components["database"]?.check?.success?.stdoutEquals,
            "healthy"
        )
    }

    func testDecodesUserConfigurationDefaults() throws {
        let manifest = EnmannerManifest(
            version: 3,
            name: "Configured",
            identifier: "local.enmanner.configured",
            application: inlineApplication(),
            userConfiguration: .init(
                template: ".env.example",
                fields: [
                    .init(
                        key: "API_KEY",
                        label: "API key",
                        type: .secret,
                        required: true
                    ),
                    .init(key: "FEATURE_ENABLED", label: "Feature enabled")
                ]
            )
        )

        XCTAssertEqual(manifest.userConfiguration?.file, ".env")
        XCTAssertEqual(manifest.userConfiguration?.fields[0].type, .secret)
        XCTAssertEqual(manifest.userConfiguration?.fields[1].type, .string)
    }

    func testMalformedManifestProducesUsefulError() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("enmanner.json")
        try Data(#"{"version":"wrong"}"#.utf8).write(to: url)

        XCTAssertThrowsError(try ManifestLoader.load(from: url)) { error in
            XCTAssertEqual(
                (error as? EnmannerError)?.diagnosticPath,
                "version"
            )
        }
    }

    func testWindowModeLifecycleBehavior() {
        XCTAssertEqual(EnmannerManifest.Window().mode, .browser)
        XCTAssertFalse(EnmannerManifest.Window.Mode.embedded.launchesWindowless)
        XCTAssertTrue(
            EnmannerManifest.Window.Mode.browser.keepsRunningAfterLastWindowClosed
        )
    }

    func testValidationRejectsWrongManifestVersion() {
        let manifest = EnmannerManifest(
            version: 2,
            name: "Legacy",
            identifier: "local.enmanner.legacy",
            application: inlineApplication()
        )

        let issues = ManifestValidator.validate(
            manifest,
            projectURL: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertTrue(issues.contains("version must be 3."))
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
                version: 3,
                name: "Icon App",
                identifier: "local.enmanner.icon-app",
                application: inlineApplication(),
                icon: .init(path: icon)
            )

            let issues = ManifestValidator.validate(
                manifest,
                projectURL: directory
            )

            XCTAssertFalse(issues.contains { $0.contains("icon must be") })
        }

        let dualIconManifest = EnmannerManifest(
            version: 3,
            name: "Icon App",
            identifier: "local.enmanner.icon-app",
            application: inlineApplication(),
            icon: .init(
                modern: "enmanner/icon/Modern.icon",
                legacy: "enmanner/icon/Legacy.icns"
            )
        )

        XCTAssertTrue(
            ManifestValidator.validate(
                dualIconManifest,
                projectURL: directory
            ).isEmpty
        )
    }

    func testDecodesAndSelectsModernIconWithLegacyFallback() throws {
        let manifest = try JSONDecoder().decode(
            EnmannerManifest.self,
            from: Data(
                """
                {
                  "version": 3,
                  "name": "Icon App",
                  "identifier": "local.enmanner.icon-app",
                  "application": {
                    "command": ["/usr/bin/true"],
                    "readiness": {"path": "/"}
                  },
                  "window": {
                    "mode": "browser",
                    "width": 800,
                    "height": 600,
                    "resizable": true
                  },
                  "icon": {
                    "modern": "enmanner/icon/AppIcon.icon",
                    "legacy": "enmanner/icon/AppIcon.icns"
                  }
                }
                """.utf8
            )
        )

        XCTAssertEqual(manifest.icon?.modern, "enmanner/icon/AppIcon.icon")
        XCTAssertEqual(manifest.icon?.legacy, "enmanner/icon/AppIcon.icns")
        XCTAssertEqual(
            manifest.icon?.selectedPath(modernToolingAvailable: true),
            "enmanner/icon/AppIcon.icon"
        )
        XCTAssertEqual(
            manifest.icon?.selectedPath(modernToolingAvailable: false),
            "enmanner/icon/AppIcon.icns"
        )
    }

    func testLegacyStringIconRemainsCompatible() throws {
        let icon = try JSONDecoder().decode(
            EnmannerManifest.Icon.self,
            from: Data(#""enmanner/icon/AppIcon.icns""#.utf8)
        )

        XCTAssertNil(icon.modern)
        XCTAssertEqual(icon.legacy, "enmanner/icon/AppIcon.icns")
    }

    func testValidationRejectsUnsafeUserConfiguration() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Unsafe Configuration",
            identifier: "local.enmanner.unsafe-configuration",
            application: inlineApplication(),
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
    }

    func testValidationRejectsTrackedUserConfigurationFile() throws {
        let directory = try temporaryDirectory()
        try Data("API_KEY=\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        try runGit(["init", "--quiet"], in: directory)
        try runGit(["add", ".env"], in: directory)

        let manifest = EnmannerManifest(
            version: 3,
            name: "Tracked Configuration",
            identifier: "local.enmanner.tracked-configuration",
            application: inlineApplication(),
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

    private func inlineApplication() -> EnmannerManifest.Application {
        .init(
            command: ["/usr/bin/true"],
            readiness: .init(path: "/")
        )
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
            .appendingPathComponent(
                "enmanner-tests-\(UUID().uuidString)",
                isDirectory: true
            )
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
