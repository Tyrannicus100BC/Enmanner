import AppKit
import WebKit
import EnmannerCore

@MainActor
final class MainWindowController: NSWindowController, WKNavigationDelegate {
    private let settings: AppSettings
    private let rootView = NSView()
    private let webView: WKWebView?
    private let statePanel = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let activityIndicator = NSProgressIndicator()
    private let retryButton = NSButton(title: "Try Again", target: nil, action: nil)
    private let logsButton = NSButton(title: "View Logs", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy Logs", target: nil, action: nil)
    private let revealButton = NSButton(title: "Reveal Project", target: nil, action: nil)
    private let openButton = NSButton(title: "Open in Browser", target: nil, action: nil)
    private let logsScrollView = NSScrollView()
    private let logsTextView = NSTextView()
    private var logsHeightConstraint: NSLayoutConstraint!
    private var currentLogs = ""
    private var applicationURL: URL?

    var onRetry: (() -> Void)?
    var onRevealProject: (() -> Void)?

    init(manifest: EnmannerManifest, settings: AppSettings) {
        self.settings = settings
        if manifest.window.mode == .embedded {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            webView = WKWebView(frame: .zero, configuration: configuration)
        } else {
            webView = nil
        }

        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if manifest.window.resizable {
            style.insert(.resizable)
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: manifest.window.width,
                height: manifest.window.height
            ),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = manifest.name
        window.minSize = NSSize(width: 520, height: 420)
        window.center()
        window.setFrameAutosaveName("EnmannerMainWindow")
        super.init(window: window)

        configureViews()
        applySettings()
        showStarting()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showStarting() {
        webView?.isHidden = true
        openButton.isHidden = true
        configureState(
            title: "Starting your app…",
            message: "Enmanner is preparing the local application server.",
            spinning: true,
            retry: false
        )
    }

    func showReconnecting() {
        webView?.isHidden = true
        openButton.isHidden = true
        configureState(
            title: "Reconnecting…",
            message: "The application server restarted. Enmanner will bring the app back when it is ready.",
            spinning: true,
            retry: false
        )
    }

    func showFailure(
        message: String,
        command: [String],
        exitStatus: Int32? = nil,
        includesRecentOutput: Bool = true
    ) {
        webView?.isHidden = true
        openButton.isHidden = true
        var detail = message
        if !command.isEmpty {
            detail += "\n\nCommand: " + command.joined(separator: " ")
        }
        if let exitStatus {
            detail += "\nExit status: \(exitStatus)"
        }
        if includesRecentOutput, !currentLogs.isEmpty {
            let recent = currentLogs.split(separator: "\n").suffix(6).joined(separator: "\n")
            detail += "\n\nRecent output:\n\(recent)"
        }
        configureState(
            title: "Enmanner could not start the application server.",
            message: detail,
            spinning: false,
            retry: true
        )
    }

    func showEmbeddedApplication(at url: URL) {
        applicationURL = url
        activityIndicator.stopAnimation(nil)
        guard let webView else { return }
        statePanel.isHidden = true
        openButton.isHidden = true
        webView.isHidden = false
        applySettings()
        webView.load(URLRequest(url: url))
    }

    func showBrowserRunning(at url: URL) {
        applicationURL = url
        webView?.isHidden = true
        statePanel.isHidden = false
        openButton.isHidden = false
        configureState(
            title: "Your app is running",
            message: "Enmanner is keeping the local application server available in your default browser.",
            spinning: false,
            retry: false
        )
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func updateLogs(_ text: String) {
        currentLogs = text
        logsTextView.string = text
        if !text.isEmpty {
            logsTextView.scrollToEndOfDocument(nil)
        }
    }

    func applySettings() {
        webView?.pageZoom = settings.pageZoom
    }

    func reloadApplication() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func resetZoom() {
        settings.pageZoom = 1
        applySettings()
    }

    func zoomIn() {
        settings.pageZoom = min(settings.pageZoom + 0.1, 2)
        applySettings()
    }

    func zoomOut() {
        settings.pageZoom = max(settings.pageZoom - 0.1, 0.5)
        applySettings()
    }

    var canGoBack: Bool {
        webView?.canGoBack ?? false
    }

    var canGoForward: Bool {
        webView?.canGoForward ?? false
    }

    var hasEmbeddedBrowser: Bool {
        webView != nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let destination = navigationAction.request.url,
              let applicationURL else {
            decisionHandler(.allow)
            return
        }

        let isUserLink = navigationAction.navigationType == .linkActivated
        let isExternal = destination.host != applicationURL.host
        let shouldOpenExternally = navigationAction.targetFrame == nil ||
            (isExternal && settings.opensExternalLinksInBrowser)
        if isUserLink && shouldOpenExternally {
            NSWorkspace.shared.open(destination)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    private func configureViews() {
        guard let window else { return }
        window.contentView = rootView
        webView?.navigationDelegate = self

        var views = [
            statePanel, titleLabel, messageLabel, activityIndicator,
            retryButton, logsButton, copyButton, revealButton, openButton,
            logsScrollView, logsTextView
        ]
        if let webView {
            views.append(webView)
        }
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        statePanel.material = .hudWindow
        statePanel.blendingMode = .withinWindow
        statePanel.state = .active
        statePanel.wantsLayer = true
        statePanel.layer?.cornerRadius = 16

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 14
        messageLabel.lineBreakMode = .byWordWrapping

        activityIndicator.style = .spinning
        activityIndicator.controlSize = .regular

        retryButton.target = self
        retryButton.action = #selector(retry)
        retryButton.keyEquivalent = "\r"
        logsButton.target = self
        logsButton.action = #selector(toggleLogs)
        copyButton.target = self
        copyButton.action = #selector(copyLogs)
        revealButton.target = self
        revealButton.action = #selector(revealProject)
        openButton.target = self
        openButton.action = #selector(openInBrowser)

        let buttonStack = NSStackView(
            views: [retryButton, openButton, logsButton, copyButton, revealButton]
        )
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY

        let stateStack = NSStackView(
            views: [activityIndicator, titleLabel, messageLabel, buttonStack]
        )
        stateStack.translatesAutoresizingMaskIntoConstraints = false
        stateStack.orientation = .vertical
        stateStack.spacing = 14
        stateStack.alignment = .centerX
        statePanel.addSubview(stateStack)

        logsTextView.isEditable = false
        logsTextView.isSelectable = true
        logsTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logsTextView.textColor = .textColor
        logsTextView.backgroundColor = .textBackgroundColor
        logsTextView.textContainerInset = NSSize(width: 12, height: 12)
        logsScrollView.documentView = logsTextView
        logsScrollView.hasVerticalScroller = true
        logsScrollView.borderType = .bezelBorder

        if let webView {
            rootView.addSubview(webView)
        }
        rootView.addSubview(statePanel)
        rootView.addSubview(logsScrollView)
        logsHeightConstraint = logsScrollView.heightAnchor.constraint(equalToConstant: 0)

        var constraints: [NSLayoutConstraint] = [
            statePanel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            statePanel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor, constant: -20),
            statePanel.widthAnchor.constraint(greaterThanOrEqualToConstant: 440),
            statePanel.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, constant: -48),

            stateStack.leadingAnchor.constraint(equalTo: statePanel.leadingAnchor, constant: 28),
            stateStack.trailingAnchor.constraint(equalTo: statePanel.trailingAnchor, constant: -28),
            stateStack.topAnchor.constraint(equalTo: statePanel.topAnchor, constant: 26),
            stateStack.bottomAnchor.constraint(equalTo: statePanel.bottomAnchor, constant: -26),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 600),

            logsScrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            logsScrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            logsScrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            logsHeightConstraint
        ]
        if let webView {
            constraints += [
                webView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
                webView.topAnchor.constraint(equalTo: rootView.topAnchor),
                webView.bottomAnchor.constraint(equalTo: logsScrollView.topAnchor)
            ]
        }
        NSLayoutConstraint.activate(constraints)
        logsScrollView.isHidden = true
    }

    private func configureState(
        title: String,
        message: String,
        spinning: Bool,
        retry: Bool
    ) {
        statePanel.isHidden = false
        titleLabel.stringValue = title
        messageLabel.stringValue = message
        retryButton.isHidden = !retry
        if spinning {
            activityIndicator.isHidden = false
            activityIndicator.startAnimation(nil)
        } else {
            activityIndicator.stopAnimation(nil)
            activityIndicator.isHidden = true
        }
    }

    @objc private func retry() {
        onRetry?()
    }

    @objc private func revealProject() {
        onRevealProject?()
    }

    @objc private func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentLogs, forType: .string)
    }

    @objc private func openInBrowser() {
        guard let applicationURL else { return }
        NSWorkspace.shared.open(applicationURL)
    }

    @objc private func toggleLogs() {
        let showing = logsHeightConstraint.constant > 0
        logsHeightConstraint.constant = showing ? 0 : 230
        logsScrollView.isHidden = showing
        logsButton.title = showing ? "View Logs" : "Hide Logs"
        rootView.layoutSubtreeIfNeeded()
    }
}
