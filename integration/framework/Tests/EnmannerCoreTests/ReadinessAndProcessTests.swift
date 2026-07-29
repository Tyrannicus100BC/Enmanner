import Darwin
import XCTest
@testable import EnmannerCore

final class ReadinessAndProcessTests: XCTestCase {
    func testLogBufferCollapsesConsecutiveRepeatedLines() {
        let logs = LogBuffer()
        logs.append("noisy line", stream: .stdout)
        logs.append("noisy line", stream: .stdout)
        logs.append("noisy line", stream: .stdout)

        let snapshot = logs.snapshot()

        XCTAssertEqual(
            snapshot.components(separatedBy: "noisy line").count - 1,
            1
        )
        XCTAssertTrue(snapshot.contains("repeated 3×"))
    }

    func testReadinessPollingStopsAfterSuccess() async {
        let attempts = AttemptCounter()
        let checker = ReadinessChecker { _ in
            await attempts.increment() >= 3
        }

        let ready = await checker.waitUntilReady(
            url: URL(string: "http://127.0.0.1:43120/")!,
            timeout: 1,
            intervalNanoseconds: 1_000_000
        )

        XCTAssertTrue(ready)
        let attemptCount = await attempts.value
        XCTAssertEqual(attemptCount, 3)
    }

    func testReadinessPollingTimesOut() async {
        let checker = ReadinessChecker { _ in false }
        let ready = await checker.waitUntilReady(
            url: URL(string: "http://127.0.0.1:43120/")!,
            timeout: 0.02,
            intervalNanoseconds: 1_000_000
        )
        XCTAssertFalse(ready)
    }

    func testSupervisorTerminatesChildProcess() throws {
        let logs = LogBuffer()
        let supervisor = ProcessSupervisor(logBuffer: logs)
        let exited = expectation(description: "child exits")
        supervisor.onExit = { exit in
            XCTAssertTrue(exit.expected)
            exited.fulfill()
        }
        let configuration = ProcessConfiguration(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
            environment: ProcessInfo.processInfo.environment
        )

        try supervisor.start(configuration)
        XCTAssertTrue(supervisor.isRunning)
        let processIdentifier = try XCTUnwrap(
            supervisor.processIdentifier
        )
        supervisor.stop(gracePeriod: 0.5)
        wait(for: [exited], timeout: 2)
        XCTAssertFalse(supervisor.isRunning)
        XCTAssertNotEqual(Darwin.kill(-processIdentifier, 0), 0)
    }

    func testRuntimeSupervisorStartsGraphStopsServicesAndRunsTasksOnce() async throws {
        let directory = try temporaryDirectory()
        let taskOutput = directory.appendingPathComponent("task-complete")
        let manifest = EnmannerManifest(
            version: 3,
            name: "Runtime Graph",
            identifier: "local.enmanner.runtime-graph",
            application: .init(component: "frontend", endpoint: "http"),
            components: [
                "database": .init(
                    kind: .prerequisite,
                    check: .init(
                        type: .command,
                        endpoint: nil,
                        command: ["/usr/bin/true"],
                        timeoutSeconds: 2
                    )
                ),
                "migrate": .init(
                    kind: .task,
                    command: ["/usr/bin/touch", taskOutput.path],
                    dependsOn: ["database"]
                ),
                "backend": .init(
                    command: ["/bin/sleep", "30"],
                    dependsOn: ["migrate"],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ]
                ),
                "frontend": .init(
                    command: ["/bin/sleep", "30"],
                    environment: [
                        "BACKEND_URL":
                            "${components.backend.endpoints.http.url}"
                    ],
                    dependsOn: ["backend"],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ]
                )
            ]
        )
        XCTAssertEqual(
            ManifestValidator.validate(manifest, projectURL: directory),
            []
        )
        let supervisor = RuntimeSupervisor(logBuffer: LogBuffer())

        let launch = try await supervisor.start(
            manifest: manifest,
            projectURL: directory
        )
        let processIdentifiers = supervisor.processIdentifiers

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: taskOutput.path)
        )
        XCTAssertEqual(Set(processIdentifiers.keys), ["backend", "frontend"])
        XCTAssertEqual(launch.applicationURL.host, "127.0.0.1")

        supervisor.stop(gracePeriod: 0.2)

        XCTAssertFalse(supervisor.isRunning)
        for processIdentifier in processIdentifiers.values {
            XCTAssertNotEqual(Darwin.kill(-processIdentifier, 0), 0)
        }

        try FileManager.default.removeItem(at: taskOutput)
        _ = try await supervisor.start(
            manifest: manifest,
            projectURL: directory
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: taskOutput.path)
        )
        supervisor.stop(gracePeriod: 0.2)
    }
}

private actor AttemptCounter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
