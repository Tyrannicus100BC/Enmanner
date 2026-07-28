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
        if let exit {
            return exit
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

private enum RuntimeValidationOutcome {
    case readiness(Bool)
    case exited(ProcessSupervisor.Exit)
}

@main
struct EnmannerValidatorCommand {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(
                Data(("Error: \(error.localizedDescription)\n").utf8)
            )
            Foundation.exit(1)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let projectPath = value(after: "--project", in: arguments) ??
            FileManager.default.currentDirectoryPath
        let runtime = arguments.contains("--runtime")
        let printField = value(after: "--print", in: arguments)
        let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
        let manifestURL = projectURL.appendingPathComponent("enmanner.json")
        let manifest = try ManifestLoader.load(from: manifestURL)
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
                throw EnmannerError.invalidManifest(["Unknown build field \(printField)."])
            }
            return
        }

        print("✓ enmanner.json is valid")
        print("✓ configured paths stay inside the project")
        print("✓ readiness is limited to loopback")
        print("✓ no obvious secrets or global-install flags were found")

        guard runtime else { return }
        try await validateRuntime(manifest: manifest, projectURL: projectURL)
    }

    private static func validateRuntime(
        manifest: EnmannerManifest,
        projectURL: URL
    ) async throws {
        let logBuffer = LogBuffer(maximumEntries: 100)
        let supervisor = ProcessSupervisor(logBuffer: logBuffer)
        let port = try PortAllocator.allocateLoopbackPort(
            preferredPort: manifest.server.preferredPort
        )
        if let preferredPort = manifest.server.preferredPort,
           preferredPort != port {
            print("! preferred port \(preferredPort) is unavailable; using \(port)")
        }
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
            throw EnmannerError.invalidManifest(["Readiness URL could not be expanded."])
        }

        let exitWaiter = RuntimeExitWaiter()
        supervisor.onExit = { exit in
            Task {
                await exitWaiter.record(exit)
            }
        }
        try supervisor.start(configuration)
        defer { supervisor.stop() }

        let outcome = await withTaskGroup(
            of: RuntimeValidationOutcome.self
        ) { group in
            group.addTask {
                let ready = await ReadinessChecker().waitUntilReady(
                    url: url,
                    timeout: manifest.server.readiness.timeoutSeconds
                )
                return .readiness(ready)
            }
            group.addTask {
                .exited(await exitWaiter.wait())
            }

            let first = await group.next()!
            supervisor.stop()
            group.cancelAll()
            return first
        }

        switch outcome {
        case .readiness(true):
            print("✓ server started and became ready at \(url.absoluteString)")
            print("✓ server stopped with Enmanner")
        case .readiness(false):
            throw EnmannerError.processLaunchFailed(
                "Runtime check timed out.\nRecent output:\n\(logBuffer.snapshot())"
            )
        case .exited(let exit):
            throw EnmannerError.processLaunchFailed(
                "Server exited before becoming ready (status \(exit.status)).\n" +
                "Recent output:\n\(logBuffer.snapshot())"
            )
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
