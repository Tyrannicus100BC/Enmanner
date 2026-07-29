import Darwin
import Foundation

private actor ProcessExitWaiter {
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

public final class RuntimeSupervisor: @unchecked Sendable {
    public struct ComponentExit: Equatable, Sendable {
        public let component: String
        public let status: Int32
        public let expected: Bool
    }

    public struct Launch: Equatable, Sendable {
        public let applicationURL: URL
        public let applicationPort: UInt16
        public let selectedPorts: [RuntimePlan.EndpointKey: UInt16]
    }

    private let queue = DispatchQueue(label: "local.enmanner.runtime-supervisor")
    private let logBuffer: LogBuffer
    private var supervisors: [String: ProcessSupervisor] = [:]
    private var currentPlan: RuntimePlan?
    private var retainedPorts: [RuntimePlan.EndpointKey: UInt16] = [:]
    private var succeededTasks: Set<String> = []
    private var starting = false
    private var stopping = false
    private var launchComplete = false
    private var startupFailure: ComponentExit?

    public var onExit: (@Sendable (ComponentExit) -> Void)?

    public init(logBuffer: LogBuffer) {
        self.logBuffer = logBuffer
    }

    public var isRunning: Bool {
        queue.sync { supervisors.values.contains(where: \.isRunning) }
    }

    public var processIdentifiers: [String: Int32] {
        queue.sync {
            supervisors.compactMapValues(\.processIdentifier)
        }
    }

    public var plan: RuntimePlan? {
        queue.sync { currentPlan }
    }

    public func start(
        manifest: EnmannerManifest,
        projectURL: URL,
        reallocateEndpoints: Bool = false
    ) async throws -> Launch {
        let ports = try queue.sync { () throws -> [RuntimePlan.EndpointKey: UInt16] in
            guard !starting &&
                    !supervisors.values.contains(where: \.isRunning) else {
                throw EnmannerError.processAlreadyRunning
            }
            starting = true
            if reallocateEndpoints {
                retainedPorts = [:]
            }
            return retainedPorts
        }
        defer {
            queue.sync { starting = false }
        }

        let plan = try RuntimePlan.make(
            manifest: manifest,
            retainedPorts: ports
        )
        queue.sync {
            currentPlan = plan
            retainedPorts = plan.ports
            stopping = false
            launchComplete = false
            startupFailure = nil
        }
        logBuffer.append(
            "Resolved \(plan.graph.components.count) runtime component" +
                (plan.graph.components.count == 1 ? "." : "s.")
        )

        do {
            for name in plan.graph.startupOrder {
                try Task.checkCancellation()
                guard let component = plan.graph.components[name] else { continue }
                switch component.kind {
                case .prerequisite:
                    try await checkPrerequisite(
                        name: name,
                        component: component,
                        plan: plan,
                        projectURL: projectURL
                    )
                case .task:
                    if queue.sync(execute: { succeededTasks.contains(name) }) {
                        logBuffer.append(
                            "Startup task already succeeded in this launcher session.",
                            component: name
                        )
                    } else {
                        try await runTask(
                            name: name,
                            component: component,
                            plan: plan,
                            projectURL: projectURL
                        )
                        queue.sync {
                            _ = succeededTasks.insert(name)
                        }
                    }
                case .service:
                    try await startService(
                        name: name,
                        component: component,
                        plan: plan,
                        projectURL: projectURL
                    )
                }
            }

            let failure = queue.sync { () -> ComponentExit? in
                if let startupFailure {
                    return startupFailure
                }
                if let stopped = supervisors.first(
                    where: { !$0.value.isRunning }
                ) {
                    return ComponentExit(
                        component: stopped.key,
                        status: -1,
                        expected: false
                    )
                }
                launchComplete = true
                return nil
            }
            if let failure {
                throw EnmannerError.processLaunchFailed(
                    "Component \(failure.component) exited during startup" +
                        (failure.status >= 0
                            ? " with status \(failure.status)."
                            : ".")
                )
            }
        } catch {
            stop()
            throw error
        }

        logBuffer.append(
            "Application runtime is ready at \(plan.applicationURL.absoluteString)."
        )
        return Launch(
            applicationURL: plan.applicationURL,
            applicationPort: plan.applicationPort,
            selectedPorts: plan.ports
        )
    }

    public func stop(gracePeriod: TimeInterval = 2) {
        let values: [(String, ProcessSupervisor)] = queue.sync {
            stopping = true
            let order = currentPlan?.graph.startupOrder.reversed() ?? []
            return order.compactMap { name in
                supervisors[name].map { (name, $0) }
            }
        }
        for (_, supervisor) in values {
            supervisor.stop(gracePeriod: gracePeriod)
        }
        queue.sync {
            supervisors.removeAll()
            stopping = false
            launchComplete = false
            startupFailure = nil
        }
    }

    private func checkPrerequisite(
        name: String,
        component: EnmannerManifest.Component,
        plan: RuntimePlan,
        projectURL: URL
    ) async throws {
        guard let check = component.check else {
            throw EnmannerError.invalidManifest([
                "component \(name) has no prerequisite check."
            ])
        }
        logBuffer.append("Checking prerequisite.", component: name)
        let ready = try await ProbeRunner.wait(
            probe: check,
            componentName: name,
            component: component,
            plan: plan,
            projectURL: projectURL
        )
        guard ready else {
            let detail = component.failureMessage ??
                "Prerequisite \(name) did not become available."
            throw EnmannerError.processLaunchFailed(detail)
        }
        logBuffer.append("Prerequisite is available.", component: name)
    }

    private func runTask(
        name: String,
        component: EnmannerManifest.Component,
        plan: RuntimePlan,
        projectURL: URL
    ) async throws {
        let configuration = try ProcessConfigurationBuilder.make(
            componentName: name,
            component: component,
            plan: plan,
            projectURL: projectURL
        )
        let supervisor = ProcessSupervisor(
            logBuffer: logBuffer,
            componentName: name
        )
        let waiter = ProcessExitWaiter()
        supervisor.onExit = { exit in
            Task { await waiter.record(exit) }
        }
        queue.sync { supervisors[name] = supervisor }
        logBuffer.append("Running startup task.", component: name)
        try supervisor.start(configuration)
        let exit = await waiter.wait()
        let leftDescendants = supervisor.hasLiveProcessGroup
        if leftDescendants {
            supervisor.stop(gracePeriod: 0.2)
        }
        queue.sync { supervisors[name] = nil }
        guard !leftDescendants else {
            throw EnmannerError.processLaunchFailed(
                "Task \(name) left processes running after its command exited."
            )
        }
        guard exit.status == 0 else {
            throw EnmannerError.processLaunchFailed(
                "Task \(name) exited with status \(exit.status)."
            )
        }
        logBuffer.append("Startup task succeeded.", component: name)
    }

    private func startService(
        name: String,
        component: EnmannerManifest.Component,
        plan: RuntimePlan,
        projectURL: URL
    ) async throws {
        let configuration = try ProcessConfigurationBuilder.make(
            componentName: name,
            component: component,
            plan: plan,
            projectURL: projectURL
        )
        let supervisor = ProcessSupervisor(
            logBuffer: logBuffer,
            componentName: name
        )
        supervisor.onExit = { [weak self, weak supervisor] exit in
            guard let self else { return }
            let componentExit = ComponentExit(
                component: name,
                status: exit.status,
                expected: exit.expected
            )
            let shouldReport = self.queue.sync {
                guard !self.stopping, !exit.expected else { return false }
                if self.launchComplete {
                    return true
                }
                self.startupFailure = componentExit
                return false
            }
            if shouldReport {
                self.onExit?(componentExit)
            }
            if supervisor?.isRunning == false &&
                supervisor?.hasLiveProcessGroup == false {
                self.queue.async {
                    if self.supervisors[name] === supervisor {
                        self.supervisors[name] = nil
                    }
                }
            }
        }
        queue.sync { supervisors[name] = supervisor }
        try supervisor.start(configuration)

        guard let readiness = component.readiness else {
            logBuffer.append(
                "Service is running; no readiness probe is configured.",
                component: name
            )
            return
        }
        logBuffer.append("Waiting for readiness.", component: name)
        let ready = try await ProbeRunner.wait(
            probe: readiness,
            componentName: name,
            component: component,
            plan: plan,
            projectURL: projectURL,
            processIsRunning: { supervisor.isRunning }
        )
        guard ready else {
            if supervisor.isRunning {
                throw EnmannerError.processLaunchFailed(
                    "Component \(name) did not become ready within " +
                        "\(Int(readiness.timeoutSeconds)) seconds."
                )
            }
            throw EnmannerError.processLaunchFailed(
                "Component \(name) exited before becoming ready."
            )
        }
        logBuffer.append("Service is ready.", component: name)
    }
}

private enum ProbeRunner {
    static func wait(
        probe: EnmannerManifest.Probe,
        componentName: String,
        component: EnmannerManifest.Component,
        plan: RuntimePlan,
        projectURL: URL,
        processIsRunning: (@Sendable () -> Bool)? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(probe.timeoutSeconds)
        while !Task.isCancelled && Date() < deadline {
            if let processIsRunning, !processIsRunning() {
                return false
            }
            if try await check(
                probe: probe,
                componentName: componentName,
                component: component,
                plan: plan,
                projectURL: projectURL
            ) {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        try Task.checkCancellation()
        return false
    }

    private static func check(
        probe: EnmannerManifest.Probe,
        componentName: String,
        component: EnmannerManifest.Component,
        plan: RuntimePlan,
        projectURL: URL
    ) async throws -> Bool {
        switch probe.type {
        case .http:
            guard let endpointName = probe.endpoint,
                  let endpoint = plan.endpoints[
                    .init(component: componentName, endpoint: endpointName)
                  ],
                  let url = endpoint.url(path: probe.path) else {
                return false
            }
            return await ReadinessChecker.checkHTTP(
                url: url,
                acceptableStatusCodes: probe.acceptableStatusCodes,
                contentTypeContains: probe.contentTypeContains,
                bodyContains: probe.bodyContains
            )
        case .tcp:
            guard let endpointName = probe.endpoint,
                  let endpoint = plan.endpoints[
                    .init(component: componentName, endpoint: endpointName)
                  ] else {
                return false
            }
            return TCPProbe.canConnect(host: endpoint.host, port: endpoint.port)
        case .command:
            guard let command = probe.command else { return false }
            var probeComponent = component
            probeComponent = .init(
                kind: .task,
                command: command,
                workingDirectory: component.workingDirectory,
                environment: component.environment
            )
            let configuration = try ProcessConfigurationBuilder.make(
                componentName: componentName,
                component: probeComponent,
                plan: plan,
                projectURL: projectURL
            )
            let result = try await OneShotProbe.run(
                configuration: configuration,
                timeout: min(probe.timeoutSeconds, 10)
            )
            guard result.status == 0 else { return false }
            let stdout = result.stdout.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if let expected = probe.success?.stdoutEquals {
                return stdout == expected
            }
            if let contained = probe.success?.stdoutContains {
                return stdout.contains(contained)
            }
            return true
        }
    }
}

private enum TCPProbe {
    static func canConnect(host: String, port: UInt16) -> Bool {
        var hints = addrinfo(
            ai_flags: AI_NUMERICSERV,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &result) == 0,
              let first = result else {
            return false
        }
        defer { freeaddrinfo(first) }

        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let info = cursor?.pointee {
            let descriptor = socket(
                info.ai_family,
                info.ai_socktype,
                info.ai_protocol
            )
            if descriptor >= 0 {
                let connected = Darwin.connect(
                    descriptor,
                    info.ai_addr,
                    info.ai_addrlen
                ) == 0
                close(descriptor)
                if connected { return true }
            }
            cursor = info.ai_next
        }
        return false
    }
}

private enum OneShotProbe {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
    }

    static func run(
        configuration: ProcessConfiguration,
        timeout: TimeInterval
    ) async throws -> Result {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.currentDirectoryURL = configuration.workingDirectoryURL
        process.environment = configuration.environment
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        let output = ProbeOutput()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                output.append(data)
            }
        }
        try process.run()
        Darwin.setpgid(process.processIdentifier, process.processIdentifier)

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if process.isRunning {
            Darwin.kill(-process.processIdentifier, SIGTERM)
            try? await Task.sleep(nanoseconds: 100_000_000)
            if process.isRunning {
                Darwin.kill(-process.processIdentifier, SIGKILL)
            }
        }
        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        output.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        return Result(
            status: process.terminationStatus,
            stdout: output.string
        )
    }
}

private final class ProbeOutput: @unchecked Sendable {
    private static let maximumBytes = 65_536
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        let remaining = Self.maximumBytes - data.count
        guard remaining > 0 else { return }
        data.append(newData.prefix(remaining))
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
