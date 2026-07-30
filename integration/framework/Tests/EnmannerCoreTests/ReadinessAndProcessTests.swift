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

    func testLogBufferRedactsDeclaredSecretValues() {
        let logs = LogBuffer()
        logs.setSensitiveValues([
            "sk-example-secret-value",
            "short"
        ])

        logs.append(
            "key=sk-example-secret-value short=short",
            stream: .stdout
        )

        XCTAssertTrue(logs.snapshot().contains("key=[REDACTED]"))
        XCTAssertTrue(logs.snapshot().contains("short=short"))
        XCTAssertFalse(logs.snapshot().contains("sk-example-secret-value"))
        XCTAssertEqual(
            logs.redact("sk-example-secret-value"),
            "[REDACTED]"
        )
    }

    func testProcessOutputCallbackReceivesRedactedText() throws {
        let logs = LogBuffer()
        logs.setSensitiveValues(["sk-example-secret-value"])
        let supervisor = ProcessSupervisor(logBuffer: logs)
        let output = expectation(description: "redacted output")
        let exited = expectation(description: "process exits")
        supervisor.onOutput = { stream, message in
            guard stream == .stdout else { return }
            XCTAssertEqual(message, "token=[REDACTED]")
            output.fulfill()
        }
        supervisor.onExit = { _ in exited.fulfill() }

        try supervisor.start(.init(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["token=sk-example-secret-value"],
            workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
            environment: ProcessInfo.processInfo.environment
        ))

        wait(for: [output, exited], timeout: 2)
        XCTAssertFalse(logs.snapshot().contains("sk-example-secret-value"))
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
                    ],
                    readiness: .init(
                        type: .process,
                        endpoint: nil,
                        timeoutSeconds: 1,
                        minimumUptimeSeconds: 0.05
                    )
                ),
                "frontend": .init(
                    command: [
                        "/usr/bin/python3", "-m", "http.server",
                        "${self.endpoints.http.port}", "--bind", "127.0.0.1"
                    ],
                    environment: [
                        "BACKEND_URL":
                            "${components.backend.endpoints.http.url}"
                    ],
                    dependsOn: ["backend"],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ],
                    readiness: .init(
                        endpoint: "http",
                        timeoutSeconds: 5
                    )
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

    func testCompletionProbeStopsLongRunningTaskAndEmitsOutput() async throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Completion",
            identifier: "local.enmanner.completion",
            application: .init(component: "web", endpoint: "http"),
            components: [
                "prepare": .init(
                    kind: .task,
                    command: [
                        "/usr/bin/python3", "-c",
                        "import http.server, os; http.server.HTTPServer(('127.0.0.1', int(os.environ['PORT'])), http.server.SimpleHTTPRequestHandler).serve_forever()"
                    ],
                    environment: [
                        "PORT": "${self.endpoints.http.port}"
                    ],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ],
                    completion: .init(
                        endpoint: "http",
                        timeoutSeconds: 5
                    )
                ),
                "web": .init(
                    command: [
                        "/usr/bin/python3", "-m", "http.server",
                        "${self.endpoints.http.port}", "--bind", "127.0.0.1"
                    ],
                    dependsOn: ["prepare"],
                    endpoints: [
                        "http": .init(protocol: .http)
                    ],
                    readiness: .init(
                        endpoint: "http",
                        timeoutSeconds: 5
                    )
                )
            ]
        )
        let events = EventRecorder()
        let supervisor = RuntimeSupervisor(logBuffer: LogBuffer())
        supervisor.onEvent = { event in events.append(event) }

        let launch = try await supervisor.start(
            manifest: manifest,
            projectURL: directory
        )

        XCTAssertNotNil(launch.ownedPorts.first {
            $0.key.component == "prepare"
        })
        XCTAssertNil(supervisor.processIdentifiers["prepare"])
        XCTAssertTrue(events.snapshot.contains {
            $0.kind == .taskCompleted && $0.component == "prepare"
        })
        supervisor.stop(gracePeriod: 0.2)
    }

    func testRuntimePlanSeparatesOwnedAndObservedPorts() throws {
        let manifest = EnmannerManifest(
            version: 3,
            name: "Ownership",
            identifier: "local.enmanner.ownership",
            application: .init(component: "web", endpoint: "http"),
            components: [
                "database": .init(
                    kind: .prerequisite,
                    endpoints: [
                        "postgres": .init(
                            protocol: .tcp,
                            port: .init(fixed: 54_321)
                        )
                    ],
                    check: .init(type: .tcp, endpoint: "postgres")
                ),
                "web": .init(
                    command: ["/bin/sleep", "30"],
                    dependsOn: ["database"],
                    endpoints: ["http": .init(protocol: .http)],
                    readiness: .init(
                        type: .process,
                        endpoint: nil,
                        minimumUptimeSeconds: 0.05
                    )
                )
            ]
        )

        let plan = try RuntimePlan.make(manifest: manifest)

        XCTAssertEqual(plan.observedPorts.count, 1)
        XCTAssertEqual(plan.ownedPorts.count, 1)
        XCTAssertEqual(plan.observedPorts.values.first, 54_321)
    }

    func testTaskFailureIsStructuredAndIncludesRecentOutput() async throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Failure",
            identifier: "local.enmanner.failure",
            application: .init(component: "web", endpoint: "http"),
            components: [
                "prepare": .init(
                    kind: .task,
                    command: [
                        "/usr/bin/python3", "-c",
                        "import sys; print('preparation detail', flush=True); sys.exit(7)"
                    ]
                ),
                "web": .init(
                    command: ["/bin/sleep", "30"],
                    dependsOn: ["prepare"],
                    endpoints: ["http": .init(protocol: .http)],
                    readiness: .init(
                        type: .process,
                        endpoint: nil,
                        minimumUptimeSeconds: 0.05
                    )
                )
            ]
        )
        let supervisor = RuntimeSupervisor(logBuffer: LogBuffer())

        do {
            _ = try await supervisor.start(
                manifest: manifest,
                projectURL: directory
            )
            XCTFail("Expected task failure.")
        } catch let EnmannerError.runtimeFailure(failure) {
            XCTAssertEqual(failure.code, .taskExited)
            XCTAssertEqual(failure.phase, .startup)
            XCTAssertEqual(failure.component, "prepare")
            XCTAssertEqual(failure.exitStatus, 7)
            XCTAssertEqual(failure.command?.first, "/usr/bin/python3")
            XCTAssertEqual(failure.workingDirectory, directory.path)
            XCTAssertTrue(
                failure.recentLogs.contains {
                    $0.contains("preparation detail")
                }
            )
        }
    }

    func testServiceExitBeforeReadinessIncludesStatusAndLaunchContext() async throws {
        let directory = try temporaryDirectory()
        let manifest = EnmannerManifest(
            version: 3,
            name: "Service Failure",
            identifier: "local.enmanner.service-failure",
            application: .init(component: "web", endpoint: "http"),
            components: [
                "web": .init(
                    command: [
                        "/usr/bin/python3", "-c",
                        "import sys; print('service detail', flush=True); sys.exit(9)"
                    ],
                    endpoints: ["http": .init(protocol: .http)],
                    readiness: .init(endpoint: "http", timeoutSeconds: 2)
                )
            ]
        )
        let supervisor = RuntimeSupervisor(logBuffer: LogBuffer())

        do {
            _ = try await supervisor.start(
                manifest: manifest,
                projectURL: directory
            )
            XCTFail("Expected service failure.")
        } catch let EnmannerError.runtimeFailure(failure) {
            XCTAssertEqual(failure.code, .componentExited)
            XCTAssertEqual(failure.phase, .readiness)
            XCTAssertEqual(failure.component, "web")
            XCTAssertEqual(failure.exitStatus, 9)
            XCTAssertEqual(failure.command?.first, "/usr/bin/python3")
            XCTAssertEqual(failure.workingDirectory, directory.path)
            XCTAssertTrue(
                failure.recentLogs.contains {
                    $0.contains("service detail")
                }
            )
        }
    }

    func testRecoveryCircuitBreakerUsesRollingFailureWindow() {
        var breaker = RecoveryCircuitBreaker(
            maximumFailures: 2,
            windowSeconds: 60
        )
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(breaker.recordFailure(at: start), 1)
        XCTAssertEqual(
            breaker.recordFailure(at: start.addingTimeInterval(10)),
            2
        )
        XCTAssertNil(
            breaker.recordFailure(at: start.addingTimeInterval(20))
        )
        XCTAssertEqual(
            breaker.recordFailure(at: start.addingTimeInterval(81)),
            1
        )
    }

    func testRecoveryRestartsOnlyFailedServiceAndDependents() async throws {
        let directory = try temporaryDirectory()
        let processReadiness = EnmannerManifest.Probe(
            type: .process,
            endpoint: nil,
            timeoutSeconds: 1,
            minimumUptimeSeconds: 0.05
        )
        let manifest = EnmannerManifest(
            version: 3,
            name: "Recovery",
            identifier: "local.enmanner.recovery",
            application: .init(component: "frontend", endpoint: "http"),
            components: [
                "backend": .init(
                    command: ["/bin/sleep", "30"],
                    readiness: processReadiness
                ),
                "worker": .init(
                    command: ["/bin/sleep", "30"],
                    dependsOn: ["backend"],
                    readiness: processReadiness
                ),
                "consumer": .init(
                    command: ["/bin/sleep", "30"],
                    dependsOn: ["worker"],
                    readiness: processReadiness
                ),
                "metrics": .init(
                    command: ["/bin/sleep", "30"],
                    readiness: processReadiness
                ),
                "frontend": .init(
                    command: [
                        "/usr/bin/python3", "-m", "http.server",
                        "${self.endpoints.http.port}", "--bind", "127.0.0.1"
                    ],
                    dependsOn: ["backend"],
                    endpoints: ["http": .init(protocol: .http)],
                    readiness: .init(endpoint: "http", timeoutSeconds: 5)
                )
            ]
        )
        XCTAssertEqual(
            ManifestValidator.validate(manifest, projectURL: directory),
            []
        )
        let supervisor = RuntimeSupervisor(logBuffer: LogBuffer())
        let workerExited = expectation(description: "worker exited")
        supervisor.onExit = { exit in
            if exit.component == "worker" {
                workerExited.fulfill()
            }
        }
        _ = try await supervisor.start(
            manifest: manifest,
            projectURL: directory
        )
        let before = supervisor.processIdentifiers
        let workerPID = try XCTUnwrap(before["worker"])

        XCTAssertEqual(Darwin.kill(workerPID, SIGKILL), 0)
        await fulfillment(of: [workerExited], timeout: 2)

        let recovery = try await supervisor.recover(
            components: ["worker"],
            projectURL: directory
        )
        let after = supervisor.processIdentifiers

        XCTAssertEqual(
            recovery.affectedComponents,
            Set(["worker", "consumer"])
        )
        XCTAssertEqual(after["backend"], before["backend"])
        XCTAssertEqual(after["frontend"], before["frontend"])
        XCTAssertEqual(after["metrics"], before["metrics"])
        XCTAssertNotEqual(after["worker"], before["worker"])
        XCTAssertNotEqual(after["consumer"], before["consumer"])
        supervisor.stop(gracePeriod: 0.2)
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [RuntimeEvent] = []

    func append(_ event: RuntimeEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    var snapshot: [RuntimeEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

private actor AttemptCounter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
