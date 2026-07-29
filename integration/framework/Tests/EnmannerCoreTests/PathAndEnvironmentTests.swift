import XCTest
@testable import EnmannerCore

final class PathAndEnvironmentTests: XCTestCase {
    func testProjectIsResolvedBesideAppBundle() {
        let app = URL(fileURLWithPath: "/Users/Test/My Project/My App.app")
        XCTAssertEqual(
            ProjectPaths.projectURL(forAppBundleURL: app).path,
            "/Users/Test/My Project"
        )
        XCTAssertEqual(
            ProjectPaths.manifestURL(forAppBundleURL: app).path,
            "/Users/Test/My Project/enmanner/enmanner.json"
        )
    }

    func testPathResolutionKeepsPathsInsideProject() throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

        XCTAssertEqual(
            try ProjectPaths.resolve("src", inside: directory).path,
            source.path
        )
        XCTAssertThrowsError(
            try ProjectPaths.resolve("../elsewhere", inside: directory)
        )
        XCTAssertThrowsError(
            try ProjectPaths.resolve("/tmp/elsewhere", inside: directory)
        )
    }

    func testEnvironmentInterpolationUsesOnlyProvidedVariables() throws {
        let value = try EnvironmentInterpolator.expand(
            "http://127.0.0.1:${ENMANNER_PORT}/${ENMANNER_PROJECT_DIR}",
            variables: [
                "ENMANNER_PORT": "43120",
                "ENMANNER_PROJECT_DIR": "project"
            ]
        )
        XCTAssertEqual(value, "http://127.0.0.1:43120/project")
        XCTAssertThrowsError(
            try EnvironmentInterpolator.expand(
                "${HOME}",
                variables: ["ENMANNER_PORT": "43120"]
            )
        )
    }

    func testProcessCommandConstructionDoesNotUseShell() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 2,
            name: "Example",
            identifier: "local.enmanner.example",
            server: .init(
                command: ["/bin/echo", "port=${ENMANNER_PORT}", "two words"],
                environment: ["PORT": "${ENMANNER_PORT}"],
                readiness: .init(url: "http://127.0.0.1:${ENMANNER_PORT}/")
            )
        )

        let configuration = try ProcessConfigurationBuilder.make(
            manifest: manifest,
            projectURL: directory,
            port: 43210,
            baseEnvironment: ["PATH": "/usr/bin:/bin"]
        )

        XCTAssertEqual(configuration.executableURL.path, "/bin/echo")
        XCTAssertEqual(configuration.arguments, ["port=43210", "two words"])
        XCTAssertEqual(configuration.environment["PORT"], "43210")
    }

    func testRelativeExecutableResolvesFromWorkingDirectoryWithSpaces() throws {
        let directory = try temporaryDirectory()
        let workingDirectory = directory
            .appendingPathComponent("Project Files", isDirectory: true)
        let integrationDirectory = workingDirectory
            .appendingPathComponent("enmanner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: integrationDirectory,
            withIntermediateDirectories: true
        )
        let executable = integrationDirectory.appendingPathComponent("start")
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: executable.path,
                contents: Data("#!/bin/sh\nexit 0\n".utf8)
            )
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let manifest = EnmannerManifest(
            version: 2,
            name: "Example",
            identifier: "local.enmanner.example",
            server: .init(
                command: ["./enmanner/start"],
                workingDirectory: "Project Files",
                readiness: .init(url: "http://127.0.0.1:${ENMANNER_PORT}/")
            )
        )

        let configuration = try ProcessConfigurationBuilder.make(
            manifest: manifest,
            projectURL: directory,
            port: 43210,
            baseEnvironment: ["PATH": "/usr/bin:/bin"]
        )

        XCTAssertEqual(configuration.executableURL.path, executable.path)
    }

    func testRelativeExecutableCannotLeaveProject() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 2,
            name: "Example",
            identifier: "local.enmanner.example",
            server: .init(
                command: ["../../bin/sh"],
                readiness: .init(url: "http://127.0.0.1:${ENMANNER_PORT}/")
            )
        )

        XCTAssertThrowsError(
            try ProcessConfigurationBuilder.make(
                manifest: manifest,
                projectURL: directory,
                port: 43210,
                baseEnvironment: ["PATH": "/usr/bin:/bin"]
            )
        )
    }

    func testGUIEnvironmentIncludesCommonProjectRuntimeLocations() {
        let environment = ProcessConfigurationBuilder.environmentForGUIApplication(
            ["PATH": "/usr/bin:/bin"]
        )
        let paths = environment["PATH"]?.split(separator: ":").map(String.init)

        XCTAssertTrue(paths?.contains("/opt/homebrew/bin") == true)
        XCTAssertTrue(paths?.contains("/usr/local/bin") == true)
        XCTAssertEqual(paths?.filter { $0 == "/usr/bin" }.count, 1)
    }

    func testGUIEnvironmentExpandsTildePathEntries() {
        let environment = ProcessConfigurationBuilder.environmentForGUIApplication(
            [
                "HOME": "/Users/Test Person",
                "PATH": "~/.local/bin:/usr/bin"
            ]
        )

        let paths = environment["PATH"]?.split(separator: ":").map(String.init)
        XCTAssertTrue(paths?.contains("/Users/Test Person/.local/bin") == true)
        XCTAssertFalse(paths?.contains("~/.local/bin") == true)
    }
}
