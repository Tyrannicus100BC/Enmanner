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

    func testProcessCommandConstructionDoesNotUseShell() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Example",
            identifier: "local.enmanner.example",
            application: .init(
                command: [
                    "/bin/echo",
                    "port=${self.endpoints.http.port}",
                    "two words"
                ],
                environment: ["PORT": "${self.endpoints.http.port}"],
                preferredPort: 43210,
                readiness: .init(path: "/")
            )
        )
        let graph = try RuntimeGraph.make(from: manifest)
        let componentName = graph.applicationComponent
        let plan = try RuntimePlan.make(
            manifest: manifest,
            retainedPorts: [
                .init(component: componentName, endpoint: "http"): 43210
            ]
        )
        let component = try XCTUnwrap(plan.graph.components[componentName])

        let configuration = try ProcessConfigurationBuilder.make(
            componentName: componentName,
            component: component,
            plan: plan,
            projectURL: directory,
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
            version: 3,
            name: "Example",
            identifier: "local.enmanner.example",
            application: .init(
                command: ["./enmanner/start"],
                workingDirectory: "Project Files",
                readiness: .init(path: "/")
            )
        )
        let plan = try RuntimePlan.make(manifest: manifest)
        let componentName = plan.graph.applicationComponent
        let component = try XCTUnwrap(plan.graph.components[componentName])

        let configuration = try ProcessConfigurationBuilder.make(
            componentName: componentName,
            component: component,
            plan: plan,
            projectURL: directory,
            baseEnvironment: ["PATH": "/usr/bin:/bin"]
        )

        XCTAssertEqual(configuration.executableURL.path, executable.path)
    }

    func testRelativeExecutableCannotLeaveProject() throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Example",
            identifier: "local.enmanner.example",
            application: .init(
                command: ["../../bin/sh"],
                readiness: .init(path: "/")
            )
        )
        let plan = try RuntimePlan.make(manifest: manifest)
        let componentName = plan.graph.applicationComponent
        let component = try XCTUnwrap(plan.graph.components[componentName])

        XCTAssertThrowsError(
            try ProcessConfigurationBuilder.make(
                componentName: componentName,
                component: component,
                plan: plan,
                projectURL: directory,
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
