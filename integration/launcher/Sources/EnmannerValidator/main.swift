import Darwin
import Foundation
import EnmannerCore

private actor RuntimeExitWaiter {
    private var exit: ProcessSupervisor.Exit?
    private var continuation: CheckedContinuation<ProcessSupervisor.Exit, Never>?

    func record(_ exit: ProcessSupervisor.Exit) {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: exit)
        } else {
            self.exit = exit
        }
    }

    func wait() async -> ProcessSupervisor.Exit {
        if let exit { return exit }
        return await withCheckedContinuation { continuation = $0 }
    }
}

private enum RuntimeValidationOutcome {
    case readiness(Bool)
    case exited(ProcessSupervisor.Exit)
}

private struct RuntimeObservation {
    let outcome: RuntimeValidationOutcome
    let trackedProcesses: [Int32: String]
    let nonLoopbackListeners: [String]
}

private struct RuntimeReport: Codable {
    let selectedPort: UInt16
    let readinessURL: String
    let readinessPassed: Bool
    let supervisorExited: Bool
    let processGroupStopped: Bool
    let readinessUnavailable: Bool
    let portReleased: Bool
    let nonLoopbackListeners: [String]
    let remainingProcesses: [String]
    let workspaceMutations: [String]

    var passed: Bool {
        readinessPassed && supervisorExited && processGroupStopped &&
            readinessUnavailable && portReleased &&
            nonLoopbackListeners.isEmpty && remainingProcesses.isEmpty
    }
}

private struct ValidationReport: Codable {
    let valid: Bool
    let project: String
    let resolvedExecutable: String
    let arguments: [String]
    let workingDirectory: String
    let effectivePath: String
    let envFileLoading: String
    let swiftVersion: String
    let modernIconToolingAvailable: Bool
    let deprecatedFields: [String]
    let warnings: [String]
    let runtime: RuntimeReport?
}

@main
struct EnmannerValidatorCommand {
    static func main() async {
        let json = CommandLine.arguments.contains("--json")
        do {
            try await run(json: json)
        } catch {
            if json {
                print(
                    "{\"valid\":false,\"error\":\"" +
                    jsonEscaped(error.localizedDescription) + "\"}"
                )
            } else {
                FileHandle.standardError.write(
                    Data(("Error: \(error.localizedDescription)\n").utf8)
                )
            }
            Foundation.exit(1)
        }
    }

    private static func run(json: Bool) async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let projectPath = value(after: "--project", in: arguments) ??
            FileManager.default.currentDirectoryPath
        let runtime = arguments.contains("--runtime")
        let printField = value(after: "--print", in: arguments)
        let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
        let manifest = try ManifestLoader.load(
            from: projectURL.appendingPathComponent("enmanner.json")
        )
        let issues = ManifestValidator.validate(manifest, projectURL: projectURL)
        guard issues.isEmpty else {
            throw EnmannerError.invalidManifest(issues)
        }

        if let printField {
            switch printField {
            case "name": print(manifest.name)
            case "identifier": print(manifest.identifier)
            case "icon": print(manifest.icon ?? "")
            default:
                throw EnmannerError.invalidManifest(
                    ["Unknown build field \(printField)."]
                )
            }
            return
        }

        let diagnosticPort = try PortAllocator.allocateLoopbackPort(
            preferredPort: manifest.server.preferredPort
        )
        let configuration = try ProcessConfigurationBuilder.make(
            manifest: manifest,
            projectURL: projectURL,
            port: diagnosticPort
        )
        let runtimeReport = runtime
            ? try await validateRuntime(manifest: manifest, projectURL: projectURL)
            : nil
        let report = ValidationReport(
            valid: runtimeReport?.passed ?? true,
            project: projectURL.path,
            resolvedExecutable: configuration.executableURL.path,
            arguments: configuration.arguments,
            workingDirectory: configuration.workingDirectoryURL.path,
            effectivePath: configuration.environment["PATH", default: ""],
            envFileLoading: "project-managed",
            swiftVersion: processOutput(
                executable: "/usr/bin/xcrun",
                arguments: ["swift", "--version"]
            ).trimmingCharacters(in: .whitespacesAndNewlines),
            modernIconToolingAvailable: !processOutput(
                executable: "/usr/bin/xcrun",
                arguments: ["--find", "actool"]
            ).isEmpty,
            deprecatedFields: manifest.development == nil
                ? [] : ["development.reload"],
            warnings: manifest.identifier.hasPrefix("local.enmanner.")
                ? ["identifier uses Enmanner's inferred local namespace"]
                : [],
            runtime: runtimeReport
        )

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            print(String(data: try encoder.encode(report), encoding: .utf8)!)
        } else {
            print("✓ enmanner.json is valid")
            print("✓ configured paths stay inside the project")
            print("✓ readiness is limited to loopback")
            print("✓ no obvious secrets or global-install flags were found")
            print("✓ executable resolves to \(configuration.executableURL.path)")
            print("  Effective GUI PATH: \(report.effectivePath)")
            print("  .env loading: project-managed (Enmanner does not load it)")
            if manifest.development != nil {
                print("! development.reload is deprecated and ignored; remove it")
            }
            report.warnings.forEach { print("! \($0)") }
            if let runtimeReport {
                printRuntimeReport(runtimeReport)
            }
        }

        if let runtimeReport, !runtimeReport.passed {
            if json {
                Foundation.exit(1)
            }
            throw EnmannerError.processLaunchFailed(
                "Shutdown postconditions failed; inspect the runtime report."
            )
        }
    }

    private static func validateRuntime(
        manifest: EnmannerManifest,
        projectURL: URL
    ) async throws -> RuntimeReport {
        let beforeStatus = gitStatus(projectURL: projectURL)
        let logBuffer = LogBuffer(maximumEntries: 100)
        let supervisor = ProcessSupervisor(logBuffer: logBuffer)
        let port = try PortAllocator.allocateLoopbackPort(
            preferredPort: manifest.server.preferredPort
        )
        let configuration = try ProcessConfigurationBuilder.make(
            manifest: manifest,
            projectURL: projectURL,
            port: port
        )
        let variables = [
            "ENMANNER_PORT": String(port),
            "ENMANNER_PROJECT_DIR": projectURL.path
        ]
        let urlString = try EnvironmentInterpolator.expand(
            manifest.server.readiness.url,
            variables: variables
        )
        guard let url = URL(string: urlString) else {
            throw EnmannerError.invalidManifest(
                ["Readiness URL could not be expanded."]
            )
        }

        let exitWaiter = RuntimeExitWaiter()
        supervisor.onExit = { exit in
            Task { await exitWaiter.record(exit) }
        }
        try supervisor.start(configuration)
        guard let processIdentifier = supervisor.processIdentifier else {
            throw EnmannerError.processLaunchFailed(
                "The launched process did not remain running."
            )
        }

        let observation = await withTaskGroup(
            of: RuntimeValidationOutcome.self
        ) { group in
            group.addTask {
                let readiness = manifest.server.readiness
                let ready = await ReadinessChecker().waitUntilReady(
                    url: url,
                    timeout: readiness.timeoutSeconds,
                    acceptableStatusCodes: readiness.acceptableStatusCodes,
                    contentTypeContains: readiness.contentTypeContains,
                    bodyContains: readiness.bodyContains
                )
                return .readiness(ready)
            }
            group.addTask { .exited(await exitWaiter.wait()) }
            let first = await group.next()!
            let tracked = processTree(rootPID: processIdentifier)
            let publicListeners = self.nonLoopbackListeners(
                processIdentifiers: Array(tracked.keys)
            )
            supervisor.stop()
            group.cancelAll()
            return RuntimeObservation(
                outcome: first,
                trackedProcesses: tracked,
                nonLoopbackListeners: publicListeners
            )
        }

        switch observation.outcome {
        case .readiness(false):
            throw EnmannerError.processLaunchFailed(
                "Runtime check timed out.\nRecent output:\n\(logBuffer.snapshot())"
            )
        case .exited(let exit):
            throw EnmannerError.processLaunchFailed(
                "Server exited before becoming ready (status \(exit.status)).\n" +
                "Recent output:\n\(logBuffer.snapshot())"
            )
        case .readiness(true):
            break
        }

        let supervisorExited = !supervisor.isRunning
        let processGroupStopped = await waitForProcessGroupToStop(
            processIdentifier,
            timeout: 3
        )
        let readinessUnavailable = await ReadinessChecker().waitUntilUnavailable(
            url: url,
            timeout: 4
        )
        let portReleased = !PortAllocator.isLoopbackPortListening(port)
        let remainingProcesses = survivingProcesses(
            observation.trackedProcesses
        )
        let afterStatus = gitStatus(projectURL: projectURL)
        let mutations = Array(afterStatus.subtracting(beforeStatus)).sorted()

        return RuntimeReport(
            selectedPort: port,
            readinessURL: url.absoluteString,
            readinessPassed: true,
            supervisorExited: supervisorExited,
            processGroupStopped: processGroupStopped,
            readinessUnavailable: readinessUnavailable,
            portReleased: portReleased,
            nonLoopbackListeners: observation.nonLoopbackListeners,
            remainingProcesses: remainingProcesses,
            workspaceMutations: mutations
        )
    }

    private static func printRuntimeReport(_ report: RuntimeReport) {
        print("✓ server became ready at \(report.readinessURL)")
        print("\(mark(report.supervisorExited)) supervisor process exited")
        print("\(mark(report.processGroupStopped)) process group stopped")
        print("\(mark(report.readinessUnavailable)) readiness became unavailable")
        print("\(mark(report.portReleased)) selected port \(report.selectedPort) was released")
        if !report.nonLoopbackListeners.isEmpty {
            print("✗ launched process tree exposed non-loopback listeners:")
            report.nonLoopbackListeners.forEach { print("  \($0)") }
        }
        if !report.remainingProcesses.isEmpty {
            print("✗ remaining tracked processes:")
            report.remainingProcesses.forEach { print("  \($0)") }
        }
        if !report.workspaceMutations.isEmpty {
            print("! workspace changes observed during runtime validation:")
            report.workspaceMutations.forEach { print("  \($0)") }
        }
        print("  External resources outside the process tree remain project-managed.")
    }

    private static func mark(_ passed: Bool) -> String { passed ? "✓" : "✗" }

    private static func waitForProcessGroupToStop(
        _ processGroup: Int32,
        timeout: TimeInterval
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            errno = 0
            if Darwin.kill(-processGroup, 0) != 0 && errno == ESRCH {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        errno = 0
        return Darwin.kill(-processGroup, 0) != 0 && errno == ESRCH
    }

    private static func processTree(rootPID: Int32) -> [Int32: String] {
        let rows = processOutput(
            executable: "/bin/ps",
            arguments: ["-axo", "pid=,ppid=,command="]
        ).split(whereSeparator: \.isNewline)
        var parents: [Int32: Int32] = [:]
        var commands: [Int32: String] = [:]
        for row in rows {
            let pieces = row.split(
                maxSplits: 2,
                whereSeparator: \.isWhitespace
            )
            guard pieces.count == 3,
                  let pid = Int32(pieces[0]),
                  let parent = Int32(pieces[1]) else { continue }
            parents[pid] = parent
            commands[pid] = String(pieces[2])
        }
        var included: Set<Int32> = [rootPID]
        var changed = true
        while changed {
            changed = false
            for (pid, parent) in parents where
                included.contains(parent) && !included.contains(pid) {
                included.insert(pid)
                changed = true
            }
        }
        return Dictionary(
            uniqueKeysWithValues: included.map { ($0, commands[$0, default: ""]) }
        )
    }

    private static func survivingProcesses(
        _ tracked: [Int32: String]
    ) -> [String] {
        tracked.compactMap { pid, command in
            errno = 0
            guard Darwin.kill(pid, 0) == 0 || errno == EPERM else { return nil }
            return "PID \(pid): \(command)"
        }.sorted()
    }

    private static func nonLoopbackListeners(
        processIdentifiers: [Int32]
    ) -> [String] {
        guard !processIdentifiers.isEmpty else { return [] }
        let pidList = processIdentifiers.map(String.init).joined(separator: ",")
        let output = processOutput(
            executable: "/usr/sbin/lsof",
            arguments: [
                "-nP", "-a", "-p", pidList, "-iTCP", "-sTCP:LISTEN", "-Fn"
            ]
        )
        return output.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.hasPrefix("n") }
            .map { String($0.dropFirst()) }
            .filter {
                !$0.hasPrefix("127.0.0.1:") &&
                !$0.hasPrefix("[::1]:") &&
                !$0.hasPrefix("localhost:")
            }
            .sorted()
    }

    private static func gitStatus(projectURL: URL) -> Set<String> {
        let root = processOutput(
            executable: "/usr/bin/git",
            arguments: ["-C", projectURL.path, "rev-parse", "--show-toplevel"]
        )
        guard !root.isEmpty else { return [] }
        let output = processOutput(
            executable: "/usr/bin/git",
            arguments: [
                "-C", projectURL.path, "status", "--porcelain=v1",
                "--untracked-files=all", "--", "."
            ]
        )
        return Set(output.split(whereSeparator: \.isNewline).map(String.init))
    }

    private static func processOutput(
        executable: String,
        arguments: [String]
    ) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func jsonEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
