import Darwin
import Foundation

public struct ProcessConfiguration: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let workingDirectoryURL: URL
    public let environment: [String: String]

    public init(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        environment: [String: String]
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectoryURL = workingDirectoryURL
        self.environment = environment
    }
}

public enum ProcessConfigurationBuilder {
    public static func make(
        manifest: EnmannerManifest,
        projectURL: URL,
        port: UInt16,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ProcessConfiguration {
        let launchEnvironment = environmentForGUIApplication(
            baseEnvironment
        )
        let variables = [
            "ENMANNER_PORT": String(port),
            "ENMANNER_PROJECT_DIR": projectURL.path
        ]
        let expandedCommand = try manifest.server.command.map {
            try EnvironmentInterpolator.expand($0, variables: variables)
        }
        guard let executable = expandedCommand.first else {
            throw EnmannerError.invalidManifest(["server.command is empty."])
        }
        let workingDirectoryURL = try ProjectPaths.resolve(
            manifest.server.workingDirectory,
            inside: projectURL
        )
        let executableURL = try resolveExecutable(
            executable,
            environment: launchEnvironment,
            workingDirectoryURL: workingDirectoryURL,
            projectURL: projectURL
        )
        var environment = launchEnvironment
        let configuredEnvironment = try EnvironmentInterpolator.expand(
            manifest.server.environment,
            variables: variables
        )
        environment.merge(configuredEnvironment) { _, configured in configured }
        environment["ENMANNER_PORT"] = String(port)
        environment["ENMANNER_PROJECT_DIR"] = projectURL.path

        return ProcessConfiguration(
            executableURL: executableURL,
            arguments: Array(expandedCommand.dropFirst()),
            workingDirectoryURL: workingDirectoryURL,
            environment: environment
        )
    }

    public static func environmentForGUIApplication(
        _ environment: [String: String]
    ) -> [String: String] {
        var result = environment
        let inherited = environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
        let commonRuntimeDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        var directories: [String] = []
        for directory in inherited + commonRuntimeDirectories
            where !directory.isEmpty && !directories.contains(directory) {
            directories.append(directory)
        }
        result["PATH"] = directories.joined(separator: ":")
        return result
    }

    public static func resolveExecutable(
        _ executable: String,
        environment: [String: String],
        workingDirectoryURL: URL? = nil,
        projectURL: URL? = nil
    ) throws -> URL {
        let fileManager = FileManager.default
        if executable.contains("/") {
            let url: URL
            if executable.hasPrefix("/") {
                url = URL(fileURLWithPath: executable).standardizedFileURL
            } else {
                guard let workingDirectoryURL, let projectURL else {
                    throw EnmannerError.executableNotFound(executable)
                }
                let candidate = workingDirectoryURL
                    .appendingPathComponent(executable)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                let root = projectURL.standardizedFileURL.resolvingSymlinksInPath()
                let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
                guard candidate.path == root.path ||
                        candidate.path.hasPrefix(rootPath) else {
                    throw EnmannerError.invalidManifest([
                        "The configured executable must stay inside the project."
                    ])
                }
                url = candidate
            }
            guard fileManager.isExecutableFile(atPath: url.path) else {
                throw EnmannerError.executableNotFound(executable)
            }
            return url
        }

        let fallbackPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        for directory in environment["PATH", default: fallbackPath].split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent(executable)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw EnmannerError.executableNotFound(executable)
    }
}

public final class ProcessSupervisor: @unchecked Sendable {
    public struct Exit: Equatable, Sendable {
        public let status: Int32
        public let expected: Bool
    }

    private let queue = DispatchQueue(label: "local.enmanner.process-supervisor")
    private var process: Process?
    private var stopping = false
    private let logBuffer: LogBuffer

    public var onExit: (@Sendable (Exit) -> Void)?

    public init(logBuffer: LogBuffer) {
        self.logBuffer = logBuffer
    }

    public var isRunning: Bool {
        queue.sync { process?.isRunning == true }
    }

    public var processIdentifier: Int32? {
        queue.sync {
            guard let process, process.isRunning else { return nil }
            return process.processIdentifier
        }
    }

    public func start(_ configuration: ProcessConfiguration) throws {
        try queue.sync {
            guard process?.isRunning != true else {
                throw EnmannerError.processAlreadyRunning
            }
            stopping = false

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = configuration.executableURL
            process.arguments = configuration.arguments
            process.currentDirectoryURL = configuration.workingDirectoryURL
            process.environment = configuration.environment
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            attach(pipe: outputPipe, stream: .stdout)
            attach(pipe: errorPipe, stream: .stderr)
            process.terminationHandler = { [weak self] completed in
                guard let self else { return }
                let expected = self.queue.sync { self.stopping }
                self.logBuffer.append(
                    "Server exited with status \(completed.terminationStatus)."
                )
                self.queue.async {
                    self.process = nil
                }
                self.onExit?(
                    Exit(status: completed.terminationStatus, expected: expected)
                )
            }

            do {
                try process.run()
                Darwin.setpgid(process.processIdentifier, process.processIdentifier)
                self.process = process
                logBuffer.append(
                    "Started server process \(process.processIdentifier): " +
                    ([configuration.executableURL.path] + configuration.arguments)
                        .joined(separator: " ")
                )
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                throw EnmannerError.processLaunchFailed(error.localizedDescription)
            }
        }
    }

    public func stop(gracePeriod: TimeInterval = 2) {
        let processToStop: Process? = queue.sync {
            stopping = true
            return process
        }
        guard let processToStop, processToStop.isRunning else { return }

        let pid = processToStop.processIdentifier
        logBuffer.append("Stopping server process \(pid).")
        Darwin.kill(-pid, SIGTERM)

        let deadline = Date().addingTimeInterval(gracePeriod)
        while processToStop.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if processToStop.isRunning {
            logBuffer.append("Server did not stop gracefully; forcing shutdown.")
            Darwin.kill(-pid, SIGKILL)
            processToStop.waitUntilExit()
        }
    }

    private func attach(pipe: Pipe, stream: LogBuffer.Stream) {
        pipe.fileHandleForReading.readabilityHandler = { [weak logBuffer] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }
            for line in text.split(whereSeparator: \.isNewline) {
                logBuffer?.append(String(line), stream: stream)
            }
        }
    }
}
