import AppKit
import EnmannerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let logBuffer = LogBuffer()
    private let readinessChecker = ReadinessChecker()
    private let settings = AppSettings()
    private lazy var supervisor = ProcessSupervisor(logBuffer: logBuffer)
    private var windowController: MainWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var manifest: EnmannerManifest?
    private var projectURL: URL?
    private var applicationURL: URL?
    private var readinessTask: Task<Void, Never>?
    private var chosenPort: UInt16?
    private var reachedReadyState = false
    private var isRecovering = false
    private var recoveryAttempts = 0
    private var shuttingDown = false
    private var browserReopenNeedsForegroundOnly = true
    private var activationSequence = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        // Activation lets macOS resolve access to projects in protected folders
        // such as Desktop before Enmanner reads the manifest. Browser mode still
        // remains windowless because no window controller is created here.
        NSApplication.shared.activate(ignoringOtherApps: true)
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
            if manifest?.window.mode.launchesWindowless == false {
                showLauncherWindow()
            }
            startServer(recovering: false)
        } catch {
            presentPreparationFailure(error)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(manifest?.window.mode.keepsRunningAfterLastWindowClosed ?? false)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !flag, let mode = manifest?.window.mode else { return true }
        if mode == .embedded {
            showLauncherWindow()
            return false
        }

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
        configureMainMenu(appName: manifest.name)
        supervisor.onExit = { [weak self] exit in
            DispatchQueue.main.async {
                self?.serverDidExit(exit)
            }
        }
        logBuffer.append("Resolved project at \(projectURL.path).")
    }

    private func startServer(recovering: Bool) {
        guard let manifest, let projectURL else { return }
        readinessTask?.cancel()
        isRecovering = recovering
        if recovering {
            windowController?.showReconnecting()
        } else {
            windowController?.showStarting()
        }

        do {
            let isFirstAllocation = chosenPort == nil
            let port = try chosenPort ?? PortAllocator.allocateLoopbackPort(
                preferredPort: manifest.server.preferredPort
            )
            chosenPort = port
            if isFirstAllocation,
               let preferredPort = manifest.server.preferredPort,
               preferredPort != port {
                logBuffer.append(
                    "Preferred port \(preferredPort) is unavailable; using \(port)."
                )
            }
            let variables = [
                "ENMANNER_PORT": String(port),
                "ENMANNER_PROJECT_DIR": projectURL.path
            ]
            let urlString = try EnvironmentInterpolator.expand(
                manifest.server.readiness.url,
                variables: variables
            )
            guard let url = URL(string: urlString) else {
                throw EnmannerError.invalidManifest(["server.readiness.url is invalid."])
            }
            applicationURL = url
            let configuration = try ProcessConfigurationBuilder.make(
                manifest: manifest,
                projectURL: projectURL,
                port: port
            )
            try supervisor.start(configuration)
            logBuffer.append("Waiting for readiness at \(url.absoluteString).")
            waitForReadiness(
                url: url,
                readiness: manifest.server.readiness
            )
        } catch {
            showFailure(error: error)
        }
    }

    private func waitForReadiness(
        url: URL,
        readiness: EnmannerManifest.Readiness
    ) {
        readinessTask = Task { [weak self] in
            guard let self else { return }
            let ready = await readinessChecker.waitUntilReady(
                url: url,
                timeout: readiness.timeoutSeconds,
                acceptableStatusCodes: readiness.acceptableStatusCodes,
                contentTypeContains: readiness.contentTypeContains,
                bodyContains: readiness.bodyContains
            )
            guard !Task.isCancelled else { return }
            if ready {
                reachedReadyState = true
                isRecovering = false
                recoveryAttempts = 0
                logBuffer.append("Application server is ready.")
                switch manifest?.window.mode {
                case .embedded:
                    windowController?.showEmbeddedApplication(at: url)
                case .browser:
                    windowController?.showBrowserRunning(at: url)
                    windowController?.hideWindow()
                    NSWorkspace.shared.open(url)
                case nil:
                    break
                }
            } else if supervisor.isRunning {
                logBuffer.append(
                    "Readiness timed out after \(Int(readiness.timeoutSeconds)) seconds."
                )
                supervisor.stop()
                showFailure(
                    error: EnmannerError.processLaunchFailed(
                        "The server did not become ready within " +
                        "\(Int(readiness.timeoutSeconds)) seconds."
                    )
                )
            }
        }
    }

    private func serverDidExit(_ exit: ProcessSupervisor.Exit) {
        guard !shuttingDown, !exit.expected else { return }
        readinessTask?.cancel()

        if reachedReadyState && recoveryAttempts < 5 {
            recoveryAttempts += 1
            isRecovering = true
            let delay = min(pow(2.0, Double(recoveryAttempts - 1)) * 0.6, 5)
            logBuffer.append(
                "Server stopped unexpectedly; recovery attempt \(recoveryAttempts) starts in \(String(format: "%.1f", delay)) seconds."
            )
            windowController?.showReconnecting()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.shuttingDown else { return }
                self.startServer(recovering: true)
            }
        } else {
            showFailure(
                error: EnmannerError.processLaunchFailed(
                    "The server process exited before it became ready."
                ),
                exitStatus: exit.status
            )
        }
    }

    private func retry() {
        logBuffer.append("Retry requested.")
        readinessTask?.cancel()
        supervisor.stop()
        reachedReadyState = false
        isRecovering = false
        recoveryAttempts = 0
        chosenPort = nil
        startServer(recovering: false)
    }

    private func showFailure(error: Error, exitStatus: Int32? = nil) {
        logBuffer.append(error.localizedDescription)
        reachedReadyState = false
        isRecovering = false
        NSApplication.shared.activate(ignoringOtherApps: true)
        let controller = ensureWindowController()
        controller?.showFailure(
            message: error.localizedDescription,
            command: manifest?.server.command ?? [],
            exitStatus: exitStatus,
            includesRecentOutput: settings.includesRecentOutputInErrors
        )
        controller?.showWindow(nil)
    }

    private func presentPreparationFailure(_ error: Error) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let fallbackManifest = EnmannerManifest(
            version: 2,
            name: "Enmanner",
            identifier: "local.enmanner.launcher",
            server: .init(
                command: [],
                readiness: .init(url: "http://127.0.0.1/")
            )
        )
        configureMainMenu(appName: fallbackManifest.name)
        let controller = MainWindowController(
            manifest: fallbackManifest,
            settings: settings
        )
        controller.onRevealProject = { [bundleURL = Bundle.main.bundleURL] in
            let project = ProjectPaths.projectURL(forAppBundleURL: bundleURL)
            NSWorkspace.shared.activateFileViewerSelecting([project])
        }
        windowController = controller
        logBuffer.append(error.localizedDescription)
        controller.updateLogs(logBuffer.snapshot())
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
        if manifest?.window.mode == .browser {
            if isRecovering {
                controller.showReconnecting()
            } else if reachedReadyState, let applicationURL {
                controller.showBrowserRunning(at: applicationURL)
            } else {
                controller.showStarting()
            }
        }
        controller.showWindow(nil)
    }

    private func ensureWindowController() -> MainWindowController? {
        if let windowController {
            return windowController
        }
        guard let manifest, let projectURL else { return nil }

        let controller = MainWindowController(manifest: manifest, settings: settings)
        controller.onRetry = { [weak self] in
            self?.retry()
        }
        controller.onRevealProject = {
            NSWorkspace.shared.activateFileViewerSelecting([projectURL])
        }
        controller.updateLogs(logBuffer.snapshot())
        logBuffer.onChange = { [weak controller] snapshot in
            DispatchQueue.main.async {
                controller?.updateLogs(snapshot)
            }
        }
        windowController = controller
        return controller
    }

    @objc private func showSettings(_ sender: Any?) {
        guard let mode = manifest?.window.mode else { return }
        if settingsWindowController == nil {
            let controller = SettingsWindowController(settings: settings, mode: mode)
            controller.onChange = { [weak self] in
                self?.windowController?.applySettings()
            }
            settingsWindowController = controller
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(sender)
    }

    @objc private func openApplicationInBrowser(_ sender: Any?) {
        guard let applicationURL else { return }
        NSWorkspace.shared.open(applicationURL)
    }

    @objc private func revealProject(_ sender: Any?) {
        guard let projectURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([projectURL])
    }

    @objc private func reloadApplication(_ sender: Any?) {
        windowController?.reloadApplication()
    }

    @objc private func stopLoading(_ sender: Any?) {
        windowController?.stopLoading()
    }

    @objc private func goBack(_ sender: Any?) {
        windowController?.goBack()
    }

    @objc private func goForward(_ sender: Any?) {
        windowController?.goForward()
    }

    @objc private func resetZoom(_ sender: Any?) {
        windowController?.resetZoom()
    }

    @objc private func zoomIn(_ sender: Any?) {
        windowController?.zoomIn()
    }

    @objc private func zoomOut(_ sender: Any?) {
        windowController?.zoomOut()
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
        case #selector(reloadApplication(_:)),
             #selector(stopLoading(_:)),
             #selector(resetZoom(_:)),
             #selector(zoomIn(_:)),
             #selector(zoomOut(_:)):
            return windowController?.hasEmbeddedBrowser ?? false
        case #selector(goBack(_:)):
            return windowController?.canGoBack ?? false
        case #selector(goForward(_:)):
            return windowController?.canGoForward ?? false
        case #selector(revealProject(_:)):
            return projectURL != nil
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
                "Back",
                action: #selector(goBack(_:)),
                key: "[",
                target: self
            )
        )
        viewMenu.addItem(
            item(
                "Forward",
                action: #selector(goForward(_:)),
                key: "]",
                target: self
            )
        )
        viewMenu.addItem(
            item(
                "Reload Page",
                action: #selector(reloadApplication(_:)),
                key: "r",
                target: self
            )
        )
        viewMenu.addItem(
            item("Stop", action: #selector(stopLoading(_:)), key: ".", target: self)
        )
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            item("Actual Size", action: #selector(resetZoom(_:)), key: "0", target: self)
        )
        viewMenu.addItem(
            item("Zoom In", action: #selector(zoomIn(_:)), key: "+", target: self)
        )
        viewMenu.addItem(
            item("Zoom Out", action: #selector(zoomOut(_:)), key: "-", target: self)
        )
        viewMenu.addItem(.separator())
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
