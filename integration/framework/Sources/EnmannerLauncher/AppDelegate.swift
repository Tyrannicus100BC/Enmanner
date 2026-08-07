import AppKit
import EnmannerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let logBuffer = LogBuffer()
    private let settings = AppSettings()
    private lazy var supervisor = RuntimeSupervisor(logBuffer: logBuffer)
    private var backupSupervisor: ProcessSupervisor?
    private var backupRunning = false
    private var backupStatusMenuItem: NSMenuItem?
    private var windowController: MainWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var logWindowController: LogWindowController?
    private var manifest: EnmannerManifest?
    private var projectURL: URL?
    private var applicationURL: URL?
    private var readinessTask: Task<Void, Never>?
    private var currentLaunch: RuntimeSupervisor.Launch?
    private var reachedReadyState = false
    private var isRecovering = false
    private var recoveryCircuitBreaker = RecoveryCircuitBreaker()
    private var pendingRecoveryComponents: Set<String> = []
    private var hasOpenedBrowserAutomatically = false
    private var shuttingDown = false
    private var lastAgentDiagnostic = ""
    private var browserReopenNeedsForegroundOnly = true
    private var activationSequence = 0
    private let testStatusFile = ProcessInfo.processInfo.environment[
        "ENMANNER_TEST_STATUS_FILE"
    ]
    private let suppressBrowserForTesting =
        ProcessInfo.processInfo.environment[
            "ENMANNER_TEST_SUPPRESS_BROWSER"
        ] == "1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        observeLogs()
        // Activation lets macOS resolve access to projects in protected folders
        // such as Desktop before Enmanner reads the manifest. The launcher still
        // remains windowless because no window controller is created here.
        if testStatusFile == nil {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.async { [weak self] in
            self?.beginLaunch()
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        browserReopenNeedsForegroundOnly = true
        activationSequence += 1
        let sequence = activationSequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self,
                  self.activationSequence == sequence,
                  NSApplication.shared.isActive else {
                return
            }
            self.browserReopenNeedsForegroundOnly = false
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        browserReopenNeedsForegroundOnly = true
    }

    private func beginLaunch() {
        do {
            try prepare()
            if try prepareProjectConfigurationForLaunch() {
                return
            }
            startServer()
        } catch {
            presentPreparationFailure(error)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !flag else { return true }
        // A Dock click that activates the app should only foreground it, leaving
        // the menu bar available for Quit. A later click while it is already
        // active reopens the browser. AppKit does not include the prior
        // activation state in the reopen event, so retain the adjacent
        // activation transition briefly to distinguish the two cases.
        guard !browserReopenNeedsForegroundOnly else { return false }
        if reachedReadyState, let applicationURL {
            NSWorkspace.shared.open(applicationURL)
        } else {
            showLauncherWindow()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        shuttingDown = true
        readinessTask?.cancel()
        backupSupervisor?.stop()
        supervisor.stop()
    }

    private func prepare() throws {
        let bundleURL = Bundle.main.bundleURL
        let projectURL = ProjectPaths.projectURL(forAppBundleURL: bundleURL)
        let manifest = try ManifestLoader.load(
            from: ProjectPaths.manifestURL(forAppBundleURL: bundleURL)
        )
        let issues = ManifestValidator.validate(manifest, projectURL: projectURL)
        guard issues.isEmpty else {
            throw EnmannerError.invalidManifest(issues)
        }

        self.projectURL = projectURL
        self.manifest = manifest
        try configureSecretRedaction(
            manifest: manifest,
            projectURL: projectURL
        )
        configureMainMenu(appName: manifest.name)
        supervisor.onExit = { [weak self] exit in
            DispatchQueue.main.async {
                self?.componentDidExit(exit)
            }
        }
        logBuffer.append("Resolved project at \(projectURL.path).")
    }

    private func prepareProjectConfigurationForLaunch() throws -> Bool {
        guard let projectURL, let manifest,
              let configuration = manifest.userConfiguration else {
            return false
        }

        let store = DotEnvConfigurationStore(
            projectURL: projectURL,
            configuration: configuration
        )
        if try store.materializeIfNeeded() {
            logBuffer.append(
                "Created \(configuration.file) from " +
                "\(configuration.template ?? "the declared project settings")."
            )
        }
        try configureSecretRedaction(
            manifest: manifest,
            projectURL: projectURL
        )

        let missingFields = try store.missingRequiredFields()
        guard !missingFields.isEmpty else { return false }
        let labels = missingFields.map(\.label).joined(separator: ", ")
        logBuffer.append(
            "Server launch is waiting for required project settings: \(labels)."
        )
        showSettings(
            nil,
            projectMessage:
                "Complete the required settings before starting the server."
        )
        return true
    }

    private func configureSecretRedaction(
        manifest: EnmannerManifest,
        projectURL: URL
    ) throws {
        guard let configuration = manifest.userConfiguration else {
            logBuffer.setSensitiveValues([])
            return
        }
        let secretKeys = Set(
            configuration.fields
                .filter { $0.type == .secret }
                .map(\.key)
        )
        guard !secretKeys.isEmpty else {
            logBuffer.setSensitiveValues([])
            return
        }
        let values = try DotEnvConfigurationStore(
            projectURL: projectURL,
            configuration: configuration
        ).load()
        logBuffer.setSensitiveValues(
            secretKeys.compactMap { values[$0] }
        )
    }

    private func startServer(reallocateEndpoints: Bool = false) {
        guard let manifest, let projectURL else { return }
        let conflicts = LaunchConflictDetector.detect(
            manifest: manifest,
            projectURL: projectURL
        )
        if !conflicts.isEmpty && !presentLaunchConflictWarning(conflicts) {
            return
        }
        readinessTask?.cancel()
        isRecovering = false
        windowController?.showStarting()

        readinessTask = Task { [weak self] in
            guard let self else { return }
            do {
                let launch = try await supervisor.start(
                    manifest: manifest,
                    projectURL: projectURL,
                    reallocateEndpoints: reallocateEndpoints
                )
                guard !Task.isCancelled else { return }
                currentLaunch = launch
                applicationURL = launch.applicationURL
                reachedReadyState = true
                isRecovering = false
                logBuffer.append("Application is ready.")
                writeTestStatus(launch: launch)
                windowController?.showBrowserRunning(
                    at: launch.applicationURL
                )
                windowController?.hideWindow()
                if !suppressBrowserForTesting &&
                    !hasOpenedBrowserAutomatically {
                    hasOpenedBrowserAutomatically = true
                    NSWorkspace.shared.open(launch.applicationURL)
                }
            } catch {
                guard !Task.isCancelled else { return }
                showFailure(error: error)
            }
        }
    }

    private func writeTestStatus(launch: RuntimeSupervisor.Launch) {
        guard let testStatusFile else { return }
        let selectedPorts = Dictionary(
            uniqueKeysWithValues: launch.selectedPorts.map { key, value in
                ("\(key.component).\(key.endpoint)", Int(value))
            }
        )
        let status: [String: Any] = [
            "ready": true,
            "selectedPort": Int(launch.applicationPort),
            "selectedPorts": selectedPorts,
            "readinessURL": launch.applicationURL.absoluteString,
            "componentProcessIdentifiers": launch.componentProcessIdentifiers.mapValues(Int.init),
            "processIdentifier": Int(ProcessInfo.processInfo.processIdentifier)
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: status,
            options: [.sortedKeys]
        ) else { return }
        do {
            try data.write(
                to: URL(fileURLWithPath: testStatusFile),
                options: .atomic
            )
        } catch {
            logBuffer.append(
                "Could not write native launch test status: \(error.localizedDescription)"
            )
        }
    }

    private func componentDidExit(_ exit: RuntimeSupervisor.ComponentExit) {
        guard !shuttingDown, !exit.expected else { return }
        readinessTask?.cancel()

        guard reachedReadyState else {
            showFailure(
                error: EnmannerError.runtimeFailure(.init(
                    code: .componentExited,
                    phase: .startup,
                    component: exit.component,
                    message: "Component \(exit.component) exited unexpectedly.",
                    exitStatus: exit.status,
                    command: exit.command,
                    workingDirectory: exit.workingDirectory,
                    recentLogs: exit.recentLogs
                )),
                exitStatus: exit.status
            )
            return
        }

        guard let attempt = recoveryCircuitBreaker.recordFailure() else {
            pendingRecoveryComponents.removeAll()
            supervisor.stop()
            showFailure(
                error: EnmannerError.runtimeFailure(.init(
                    code: .componentExited,
                    phase: .stability,
                    component: exit.component,
                    message: "Component \(exit.component) repeatedly exited; automatic recovery stopped after more than five failures within 60 seconds.",
                    exitStatus: exit.status,
                    command: exit.command,
                    workingDirectory: exit.workingDirectory,
                    recentLogs: exit.recentLogs
                )),
                exitStatus: exit.status
            )
            return
        }

        pendingRecoveryComponents.insert(exit.component)
        if isRecovering {
            logBuffer.append(
                "Component \(exit.component) also stopped while recovery was pending."
            )
            return
        }

        isRecovering = true
        let affected = supervisor.recoveryComponents(
            for: pendingRecoveryComponents
        )
        if let applicationComponent = applicationComponentName(),
           affected.contains(applicationComponent) {
            windowController?.showReconnecting()
        }
        let delay = min(pow(2.0, Double(attempt - 1)) * 0.6, 5)
        logBuffer.append(
            "Component \(exit.component) stopped unexpectedly; recovery attempt \(attempt) starts in \(String(format: "%.1f", delay)) seconds."
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.shuttingDown else { return }
            self.recoverPendingComponents()
        }
    }

    private func recoverPendingComponents() {
        guard let projectURL, !pendingRecoveryComponents.isEmpty else {
            isRecovering = false
            return
        }
        let components = pendingRecoveryComponents
        pendingRecoveryComponents.removeAll()
        readinessTask = Task { [weak self] in
            guard let self else { return }
            do {
                let recovery = try await supervisor.recover(
                    components: components,
                    projectURL: projectURL
                )
                guard !Task.isCancelled else { return }
                let launch = recovery.launch
                currentLaunch = launch
                applicationURL = launch.applicationURL
                reachedReadyState = true
                isRecovering = false
                logBuffer.append("Application recovery is ready.")

                guard let applicationComponent = applicationComponentName(),
                      recovery.affectedComponents.contains(
                        applicationComponent
                      ) else {
                    return
                }
                windowController?.showBrowserRunning(
                    at: launch.applicationURL
                )
                windowController?.hideWindow()
            } catch {
                guard !Task.isCancelled else { return }
                showFailure(error: error)
            }
        }
    }

    private func applicationComponentName() -> String? {
        guard let manifest else { return nil }
        return try? RuntimeGraph.make(from: manifest).applicationComponent
    }

    private func retry() {
        restartServer(
            reallocatingPort: true,
            logMessage: "Retry requested."
        )
    }

    private func restartAfterConfigurationChange() {
        if let manifest, let projectURL {
            try? configureSecretRedaction(
                manifest: manifest,
                projectURL: projectURL
            )
        }
        restartServer(
            reallocatingPort: false,
            logMessage: "Project configuration saved; restarting server."
        )
    }

    private func restartServer(
        reallocatingPort: Bool,
        logMessage: String
    ) {
        logBuffer.append(logMessage)
        readinessTask?.cancel()
        supervisor.stop()
        reachedReadyState = false
        isRecovering = false
        recoveryCircuitBreaker.reset()
        pendingRecoveryComponents.removeAll()
        if reallocatingPort {
            currentLaunch = nil
        }
        startServer(reallocateEndpoints: reallocatingPort)
    }

    private func showFailure(error: Error, exitStatus: Int32? = nil) {
        logBuffer.append(error.localizedDescription)
        reachedReadyState = false
        isRecovering = false
        NSApplication.shared.activate(ignoringOtherApps: true)
        let controller = ensureWindowController()
        let runtimeFailure = (error as? EnmannerError)?.runtimeFailure
        if let projectURL {
            lastAgentDiagnostic = AgentDiagnostic.make(
                projectURL: projectURL,
                failure: runtimeFailure,
                message: error.localizedDescription,
                selectedPorts: currentLaunch?.selectedPorts ?? [:],
                fallbackLogs: logBuffer.recentEntries()
            )
        }
        controller?.updateDiagnostic(lastAgentDiagnostic)
        controller?.showFailure(
            message: error.localizedDescription,
            command: runtimeFailure?.command ?? manifest.flatMap {
                try? RuntimeGraph.make(from: $0).applicationCommand
            } ?? [],
            workingDirectory: runtimeFailure?.workingDirectory,
            exitStatus: exitStatus ?? runtimeFailure?.exitStatus,
            includesRecentOutput: settings.includesRecentOutputInErrors,
            recentOutput: runtimeFailure?.recentLogs
        )
        controller?.showWindow(nil)
    }

    private func presentPreparationFailure(_ error: Error) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let fallbackProjectURL = ProjectPaths.projectURL(
            forAppBundleURL: Bundle.main.bundleURL
        )
        lastAgentDiagnostic = AgentDiagnostic.make(
            projectURL: fallbackProjectURL,
            failure: (error as? EnmannerError)?.runtimeFailure,
            message: error.localizedDescription,
            fallbackLogs: logBuffer.recentEntries()
        )
        let fallbackManifest = EnmannerManifest(
            version: 3,
            name: "Enmanner",
            identifier: "local.enmanner.launcher",
            application: .init(
                command: ["/usr/bin/false"],
                readiness: .init(path: "/")
            )
        )
        configureMainMenu(appName: fallbackManifest.name)
        let controller = MainWindowController(
            manifest: fallbackManifest
        )
        controller.onRevealProject = { [bundleURL = Bundle.main.bundleURL] in
            let project = ProjectPaths.projectURL(forAppBundleURL: bundleURL)
            NSWorkspace.shared.activateFileViewerSelecting([project])
        }
        controller.onCopyDiagnostic = { [weak self] in
            self?.lastAgentDiagnostic ?? ""
        }
        windowController = controller
        logBuffer.append(error.localizedDescription)
        controller.updateLogs(logBuffer.snapshot())
        controller.updateDiagnostic(lastAgentDiagnostic)
        controller.showFailure(
            message: error.localizedDescription,
            command: [],
            includesRecentOutput: settings.includesRecentOutputInErrors
        )
        showLauncherWindow()
    }

    private func showLauncherWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard let controller = ensureWindowController() else { return }
        if isRecovering {
            controller.showReconnecting()
        } else if reachedReadyState, let applicationURL {
            controller.showBrowserRunning(at: applicationURL)
        } else {
            controller.showStarting()
        }
        controller.showWindow(nil)
    }

    private func ensureWindowController() -> MainWindowController? {
        if let windowController {
            return windowController
        }
        guard let manifest, let projectURL else { return nil }

        let controller = MainWindowController(manifest: manifest)
        controller.onRetry = { [weak self] in
            self?.retry()
        }
        controller.onRevealProject = {
            NSWorkspace.shared.activateFileViewerSelecting([projectURL])
        }
        controller.onCopyDiagnostic = { [weak self] in
            self?.lastAgentDiagnostic ?? ""
        }
        controller.updateLogs(logBuffer.snapshot())
        windowController = controller
        return controller
    }

    private func observeLogs() {
        logBuffer.onChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.windowController?.updateLogs(snapshot)
                if let self, let controller = self.logWindowController {
                    controller.updateLogs(self.logs(for: controller.filterKey))
                }
            }
        }
    }

    @objc private func showSettings(_ sender: Any?) {
        showSettings(sender, projectMessage: nil)
    }

    private func showSettings(
        _ sender: Any?,
        projectMessage: String?
    ) {
        if settingsWindowController == nil {
            guard let projectURL else { return }
            let controller = SettingsWindowController(
                settings: settings,
                projectURL: projectURL,
                userConfiguration: manifest?.userConfiguration
            )
            controller.onSaveAndRestart = { [weak self] in
                self?.restartAfterConfigurationChange()
            }
            settingsWindowController = controller
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(sender)
        if let projectMessage {
            settingsWindowController?.showProjectMessage(projectMessage)
        }
    }

    @objc private func openApplicationInBrowser(_ sender: Any?) {
        guard let applicationURL else { return }
        NSWorkspace.shared.open(applicationURL)
    }

    @objc private func revealProject(_ sender: Any?) {
        guard let projectURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([projectURL])
    }

    private func presentLaunchConflictWarning(
        _ conflicts: [LaunchConflict]
    ) -> Bool {
        guard let projectURL else { return false }
        lastAgentDiagnostic = AgentDiagnostic.make(
            projectURL: projectURL,
            conflicts: conflicts
        )
        while true {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "This project appears to be running elsewhere"
            let details = conflicts.map { conflict in
                let processes = conflict.processes.isEmpty
                    ? "another process"
                    : conflict.processes.joined(separator: ", ")
                return "• \(conflict.resource): \(processes)"
            }.joined(separator: "\n")
            alert.informativeText =
                "Starting another copy may create competing writers or corrupt local data.\n\n\(details)"
            alert.addButton(withTitle: "Cancel Launch")
            alert.addButton(withTitle: "Launch Anyway")
            alert.addButton(withTitle: "Copy for Coding Agent")
            switch alert.runModal() {
            case .alertSecondButtonReturn:
                logBuffer.append("Launch guard was overridden by the user.")
                return true
            case .alertThirdButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    lastAgentDiagnostic,
                    forType: .string
                )
            default:
                logBuffer.append("Launch cancelled because guarded resources are in use.")
                let controller = ensureWindowController()
                controller?.updateDiagnostic(lastAgentDiagnostic)
                controller?.showFailure(
                    message: "Launch was cancelled because guarded project resources are already in use.",
                    command: [],
                    includesRecentOutput: false
                )
                controller?.showWindow(nil)
                return false
            }
        }
    }

    @objc private func backUpNow(_ sender: Any?) {
        guard !backupRunning, let backup = manifest?.backup,
              let projectURL, let plan = supervisor.plan else { return }
        backupRunning = true
        logBuffer.append("Starting project-declared backup.", component: "backup")
        Task { [weak self] in
            guard let self else { return }
            do {
                let component = EnmannerManifest.Component(
                    kind: .task,
                    command: backup.command,
                    workingDirectory: backup.workingDirectory,
                    environment: backup.environment
                )
                let configuration = try ProcessConfigurationBuilder.make(
                    componentName: plan.graph.applicationComponent,
                    component: component,
                    plan: plan,
                    projectURL: projectURL
                )
                let process = ProcessSupervisor(
                    logBuffer: logBuffer,
                    componentName: "backup"
                )
                backupSupervisor = process
                let exit = try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<ProcessSupervisor.Exit, Error>) in
                    process.onExit = { exit in
                        continuation.resume(returning: exit)
                    }
                    do {
                        try process.start(configuration)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                backupSupervisor = nil
                guard exit.status == 0 else {
                    throw EnmannerError.runtimeFailure(.init(
                        code: .backupFailed,
                        phase: .backup,
                        component: "backup",
                        message: "The project backup failed with status \(exit.status).",
                        exitStatus: exit.status,
                        command: [configuration.executableURL.path] + configuration.arguments,
                        workingDirectory: configuration.workingDirectoryURL.path,
                        recentLogs: logBuffer.recentEntries(
                            component: "backup",
                            componentOnly: true
                        )
                    ))
                }
                settings.lastSuccessfulBackup = Date()
                updateBackupMenuStatus()
                logBuffer.append("Project backup completed successfully.", component: "backup")
                let alert = NSAlert()
                alert.messageText = "Backup complete"
                alert.informativeText = "The project-declared backup command finished successfully."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                backupSupervisor = nil
                if !shuttingDown {
                    presentBackupFailure(error)
                }
            }
            backupRunning = false
        }
    }

    private func presentBackupFailure(_ error: Error) {
        guard let projectURL else { return }
        let failure = (error as? EnmannerError)?.runtimeFailure
        lastAgentDiagnostic = AgentDiagnostic.make(
            projectURL: projectURL,
            failure: failure,
            message: error.localizedDescription,
            selectedPorts: currentLaunch?.selectedPorts ?? [:],
            fallbackLogs: logBuffer.recentEntries(
                component: "backup",
                componentOnly: true
            )
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Backup failed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy for Coding Agent")
        if alert.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastAgentDiagnostic, forType: .string)
        }
    }

    @objc private func showServerLog(_ sender: Any?) {
        if logWindowController == nil {
            let appName = manifest?.name ?? "Enmanner"
            let componentNames: [String]
            if let manifest,
               let graph = try? RuntimeGraph.make(from: manifest) {
                componentNames = graph.components.compactMap { name, component in
                    component.kind == .service ? name : nil
                }
            } else {
                componentNames = []
            }
            let controller = LogWindowController(
                appName: appName,
                componentNames: componentNames
            )
            controller.onFilterChange = { [weak self, weak controller] key in
                guard let self else { return }
                controller?.updateLogs(self.logs(for: key))
            }
            controller.onRestartComponent = { [weak self] component in
                self?.restartComponent(component)
            }
            controller.updateLogs(logs(for: "all"))
            logWindowController = controller
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        logWindowController?.showWindow(sender)
    }

    private func logs(for filterKey: String) -> String {
        switch filterKey {
        case "all":
            return logBuffer.snapshot()
        case "enmanner":
            return logBuffer.snapshot(component: nil)
        default:
            return logBuffer.snapshot(component: filterKey)
        }
    }

    private func restartComponent(_ component: String) {
        guard !isRecovering, let projectURL,
              let plan = supervisor.plan,
              plan.graph.components[component]?.kind == .service else {
            return
        }
        let affected = supervisor.recoveryComponents(for: [component])
        isRecovering = true
        if let applicationComponent = applicationComponentName(),
           affected.contains(applicationComponent) {
            windowController?.showReconnecting()
        }
        logBuffer.append(
            "Manual restart requested for \(component); affected components: " +
                affected.sorted().joined(separator: ", ") + "."
        )
        readinessTask = Task { [weak self] in
            guard let self else { return }
            do {
                let recovery = try await supervisor.recover(
                    components: [component],
                    projectURL: projectURL
                )
                guard !Task.isCancelled else { return }
                currentLaunch = recovery.launch
                applicationURL = recovery.launch.applicationURL
                isRecovering = false
                logBuffer.append("Manual component restart completed.")
                if let applicationComponent = applicationComponentName(),
                   recovery.affectedComponents.contains(applicationComponent) {
                    windowController?.showBrowserRunning(
                        at: recovery.launch.applicationURL
                    )
                    windowController?.hideWindow()
                }
            } catch {
                guard !Task.isCancelled else { return }
                showFailure(error: error)
            }
        }
    }

    @objc private func showAppHelp(_ sender: Any?) {
        let appName = manifest?.name ?? "Enmanner"
        let alert = NSAlert()
        alert.messageText = "\(appName) Help"
        alert.informativeText =
            "\(appName) runs a project-local application server. Close its window to keep it running without a window, or choose Quit to stop the server."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openApplicationInBrowser(_:)):
            return applicationURL != nil
        case #selector(revealProject(_:)):
            return projectURL != nil
        case #selector(backUpNow(_:)):
            return manifest?.backup != nil && supervisor.plan != nil && !backupRunning
        default:
            return true
        }
    }

    private func configureMainMenu(appName: String) {
        let mainMenu = NSMenu()

        let applicationMenu = NSMenu(title: appName)
        applicationMenu.addItem(
            item(
                "About \(appName)",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:))
            )
        )
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(
            item(
                "Settings…",
                action: #selector(showSettings(_:)),
                key: ",",
                target: self
            )
        )
        applicationMenu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        applicationMenu.addItem(servicesItem)
        NSApplication.shared.servicesMenu = servicesMenu
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(
            item("Hide \(appName)", action: #selector(NSApplication.hide(_:)), key: "h")
        )
        applicationMenu.addItem(
            item(
                "Hide Others",
                action: #selector(NSApplication.hideOtherApplications(_:)),
                key: "h",
                modifiers: [.command, .option]
            )
        )
        applicationMenu.addItem(
            item("Show All", action: #selector(NSApplication.unhideAllApplications(_:)))
        )
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(
            item(
                "Quit \(appName)",
                action: #selector(NSApplication.terminate(_:)),
                key: "q"
            )
        )
        addMenu(applicationMenu, titled: appName, to: mainMenu)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            item(
                "Open in Browser",
                action: #selector(openApplicationInBrowser(_:)),
                key: "o",
                modifiers: [.command, .shift],
                target: self
            )
        )
        if manifest?.backup != nil {
            fileMenu.addItem(
                item(
                    "Back Up Now",
                    action: #selector(backUpNow(_:)),
                    target: self
                )
            )
            let statusItem = NSMenuItem(
                title: "Last Backup: Never",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            backupStatusMenuItem = statusItem
            fileMenu.addItem(statusItem)
            updateBackupMenuStatus()
        }
        fileMenu.addItem(
            item(
                "Show Project in Finder",
                action: #selector(revealProject(_:)),
                target: self
            )
        )
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            item("Close Window", action: #selector(NSWindow.performClose(_:)), key: "w")
        )
        addMenu(fileMenu, titled: "File", to: mainMenu)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(item("Undo", action: Selector(("undo:")), key: "z"))
        editMenu.addItem(
            item(
                "Redo",
                action: Selector(("redo:")),
                key: "z",
                modifiers: [.command, .shift]
            )
        )
        editMenu.addItem(.separator())
        editMenu.addItem(item("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(item("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(item("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(
            item(
                "Paste and Match Style",
                action: #selector(NSTextView.pasteAsPlainText(_:)),
                key: "v",
                modifiers: [.command, .option, .shift]
            )
        )
        editMenu.addItem(item("Delete", action: #selector(NSText.delete(_:))))
        editMenu.addItem(item("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        addMenu(editMenu, titled: "Edit", to: mainMenu)

        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            item(
                "Enter Full Screen",
                action: #selector(NSWindow.toggleFullScreen(_:)),
                key: "f",
                modifiers: [.command, .control]
            )
        )
        addMenu(viewMenu, titled: "View", to: mainMenu)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            item("Minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m")
        )
        windowMenu.addItem(item("Zoom", action: #selector(NSWindow.performZoom(_:))))
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            item(
                "Runtime Logs",
                action: #selector(showServerLog(_:)),
                key: "l",
                modifiers: [.command, .shift],
                target: self
            )
        )
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            item("Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)))
        )
        addMenu(windowMenu, titled: "Window", to: mainMenu)
        NSApplication.shared.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(
            item(
                "\(appName) Help",
                action: #selector(showAppHelp(_:)),
                key: "?",
                target: self
            )
        )
        addMenu(helpMenu, titled: "Help", to: mainMenu)
        NSApplication.shared.helpMenu = helpMenu

        NSApplication.shared.mainMenu = mainMenu
    }

    private func updateBackupMenuStatus() {
        guard let backupStatusMenuItem else { return }
        guard let date = settings.lastSuccessfulBackup else {
            backupStatusMenuItem.title = "Last Backup: Never"
            return
        }
        backupStatusMenuItem.title = "Last Backup: " + date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private func addMenu(_ menu: NSMenu, titled title: String, to mainMenu: NSMenu) {
        let rootItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        rootItem.submenu = menu
        mainMenu.addItem(rootItem)
    }

    private func item(
        _ title: String,
        action: Selector?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.keyEquivalentModifierMask = modifiers
        menuItem.target = target
        return menuItem
    }
}
