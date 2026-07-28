import XCTest
@testable import EnmannerCore

final class ReadinessAndProcessTests: XCTestCase {
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
        supervisor.stop(gracePeriod: 0.5)
        wait(for: [exited], timeout: 2)
        XCTAssertFalse(supervisor.isRunning)
    }
}

private actor AttemptCounter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
