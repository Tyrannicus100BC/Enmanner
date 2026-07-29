import AppKit
import EnmannerCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let mode: EnmannerManifest.Window.Mode
    private let projectURL: URL
    private let userConfiguration: EnmannerManifest.UserConfiguration?
    private let externalLinksCheckbox = NSButton(
        checkboxWithTitle: "Open links to other websites in the default browser",
        target: nil,
        action: nil
    )
    private let recentOutputCheckbox = NSButton(
        checkboxWithTitle: "Include recent server output in error messages",
        target: nil,
        action: nil
    )
    private let zoomPopup = NSPopUpButton()
    private let projectStatusLabel = NSTextField(
        wrappingLabelWithString: ""
    )
    private var fieldControls: [String: NSControl] = [:]
    private var secretFieldControls: [String: RevealableSecureField] = [:]
    private var fieldsByBrowseButton: [
        ObjectIdentifier: EnmannerManifest.UserConfiguration.Field
    ] = [:]
    private var saveAndRestartButton: NSButton?

    var onChange: (() -> Void)?
    var onSaveAndRestart: (() -> Void)?

    init(
        settings: AppSettings,
        mode: EnmannerManifest.Window.Mode,
        projectURL: URL,
        userConfiguration: EnmannerManifest.UserConfiguration?
    ) {
        self.settings = settings
        self.mode = mode
        self.projectURL = projectURL
        self.userConfiguration = userConfiguration

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: userConfiguration == nil ? 560 : 760,
                height: userConfiguration == nil ? 320 : 640
            ),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 560, height: 420)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("EnmannerSettingsWindowV2")
        window.center()
        super.init(window: window)

        configureViews()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    func showProjectMessage(_ message: String) {
        projectStatusLabel.textColor = .systemOrange
        projectStatusLabel.stringValue = message
    }

    private func configureViews() {
        guard let window else { return }

        let contentView = NSView()
        window.contentView = contentView

        if let userConfiguration {
            if mode == .browser {
                let projectView = makeProjectView(
                    configuration: userConfiguration,
                    includesDiagnostics: true
                )
                projectView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(projectView)
                NSLayoutConstraint.activate([
                    projectView.leadingAnchor.constraint(
                        equalTo: contentView.leadingAnchor
                    ),
                    projectView.trailingAnchor.constraint(
                        equalTo: contentView.trailingAnchor
                    ),
                    projectView.topAnchor.constraint(
                        equalTo: contentView.topAnchor
                    ),
                    projectView.bottomAnchor.constraint(
                        equalTo: contentView.bottomAnchor
                    )
                ])
                return
            }

            let tabView = NSTabView()
            tabView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(tabView)

            let projectItem = NSTabViewItem(identifier: "project")
            projectItem.label = "Project"
            projectItem.view = makeProjectView(
                configuration: userConfiguration,
                includesDiagnostics: false
            )
            tabView.addTabViewItem(projectItem)

            let appItem = NSTabViewItem(identifier: "app")
            appItem.label = "App"
            appItem.view = makeGeneralView()
            tabView.addTabViewItem(appItem)

            NSLayoutConstraint.activate([
                tabView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 16
                ),
                tabView.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -16
                ),
                tabView.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 16
                ),
                tabView.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -16
                )
            ])
            return
        }

        let generalView = makeGeneralView()
        generalView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(generalView)
        NSLayoutConstraint.activate([
            generalView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            generalView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            generalView.topAnchor.constraint(
                equalTo: contentView.topAnchor
            ),
            generalView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            )
        ])
    }

    private func makeGeneralView() -> NSView {
        let view = NSView()
        let titleLabel = NSTextField(labelWithString: "App Settings")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let zoomLabel = NSTextField(labelWithString: "Default page zoom:")
        zoomLabel.alignment = .right
        zoomPopup.addItems(
            withTitles: ["75%", "90%", "100%", "110%", "125%", "150%"]
        )
        zoomPopup.target = self
        zoomPopup.action = #selector(settingChanged)

        externalLinksCheckbox.target = self
        externalLinksCheckbox.action = #selector(settingChanged)
        recentOutputCheckbox.target = self
        recentOutputCheckbox.action = #selector(settingChanged)

        let browserNote = NSTextField(
            wrappingLabelWithString: mode == .embedded
                ? "Browser settings apply to the embedded app window."
                : "Browser display settings apply only when this app uses an embedded window."
        )
        browserNote.textColor = .secondaryLabelColor
        browserNote.font = .systemFont(ofSize: 11)

        let zoomRow = NSStackView(views: [zoomLabel, zoomPopup])
        zoomRow.orientation = .horizontal
        zoomRow.alignment = .centerY
        zoomRow.spacing = 8

        var arrangedViews: [NSView] = [titleLabel]
        if mode == .embedded {
            arrangedViews.append(externalLinksCheckbox)
            arrangedViews.append(zoomRow)
            arrangedViews.append(browserNote)
        }
        arrangedViews.append(recentOutputCheckbox)

        let stack = NSStackView(views: arrangedViews)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 28
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -20
            ),
            stack.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 28
            ),
            zoomLabel.widthAnchor.constraint(equalToConstant: 150)
        ])
        return view
    }

    private func makeProjectView(
        configuration: EnmannerManifest.UserConfiguration,
        includesDiagnostics: Bool
    ) -> NSView {
        let view = NSView()
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let titleLabel = NSTextField(
            labelWithString: "Project Settings"
        )
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let fileLabel = NSTextField(
            wrappingLabelWithString:
                "Stored locally in \(configuration.file)."
        )
        fileLabel.textColor = .secondaryLabelColor
        fileLabel.font = .systemFont(ofSize: 12)

        var arrangedViews: [NSView] = [titleLabel, fileLabel]
        for field in configuration.fields {
            arrangedViews.append(makeFieldView(field))
        }

        if includesDiagnostics {
            recentOutputCheckbox.target = self
            recentOutputCheckbox.action = #selector(settingChanged)
            let separator = NSBox()
            separator.boxType = .separator
            arrangedViews.append(separator)
            arrangedViews.append(recentOutputCheckbox)
        }

        projectStatusLabel.textColor = .secondaryLabelColor
        projectStatusLabel.font = .systemFont(ofSize: 11)
        arrangedViews.append(projectStatusLabel)

        let stack = NSStackView(views: arrangedViews)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        documentView.addSubview(stack)

        let saveButton = NSButton(
            title: "Save & Restart",
            target: self,
            action: #selector(saveProjectConfiguration)
        )
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"
        saveAndRestartButton = saveButton

        view.addSubview(scrollView)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 28
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -28
            ),
            scrollView.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 24
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: saveButton.topAnchor,
                constant: -12
            ),
            saveButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -28
            ),
            saveButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -20
            ),

            documentView.leadingAnchor.constraint(
                equalTo: scrollView.contentView.leadingAnchor
            ),
            documentView.trailingAnchor.constraint(
                equalTo: scrollView.contentView.trailingAnchor
            ),
            documentView.topAnchor.constraint(
                equalTo: scrollView.contentView.topAnchor
            ),
            documentView.widthAnchor.constraint(
                equalTo: scrollView.contentView.widthAnchor
            ),

            stack.leadingAnchor.constraint(
                equalTo: documentView.leadingAnchor,
                constant: 0
            ),
            stack.trailingAnchor.constraint(
                equalTo: documentView.trailingAnchor,
                constant: -16
            ),
            stack.topAnchor.constraint(
                equalTo: documentView.topAnchor,
                constant: 4
            ),
            stack.bottomAnchor.constraint(
                equalTo: documentView.bottomAnchor,
                constant: -12
            ),
            fileLabel.widthAnchor.constraint(
                lessThanOrEqualTo: stack.widthAnchor
            ),
            projectStatusLabel.widthAnchor.constraint(
                lessThanOrEqualTo: stack.widthAnchor
            )
        ])
        return view
    }

    private func makeFieldView(
        _ field: EnmannerManifest.UserConfiguration.Field
    ) -> NSView {
        if field.type == .boolean {
            let checkbox = NSButton(
                checkboxWithTitle:
                    field.label + (field.required ? " *" : ""),
                target: nil,
                action: nil
            )
            fieldControls[field.key] = checkbox
            return fieldRow(
                label: field.label + (field.required ? " *" : ""),
                description: field.description,
                control: checkbox,
                hidesControlLabel: true
            )
        }

        if field.type == .secret {
            let secretField = RevealableSecureField()
            secretField.placeholderString = field.required ? "Required" : ""
            secretFieldControls[field.key] = secretField
            return fieldRow(
                label: field.label + (field.required ? " *" : ""),
                description: field.description,
                control: secretField
            )
        }

        let textField = NSTextField()
        textField.placeholderString = field.required ? "Required" : ""
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        fieldControls[field.key] = textField

        var valueViews: [NSView] = [textField]
        if field.type == .file || field.type == .directory {
            let browseButton = NSButton(
                title: "Choose…",
                target: self,
                action: #selector(choosePath(_:))
            )
            fieldsByBrowseButton[ObjectIdentifier(browseButton)] = field
            valueViews.append(browseButton)
        }
        let valueRow = NSStackView(views: valueViews)
        valueRow.orientation = .horizontal
        valueRow.alignment = .centerY
        valueRow.spacing = 8
        textField.widthAnchor.constraint(
            greaterThanOrEqualToConstant: 240
        ).isActive = true
        return fieldRow(
            label: field.label + (field.required ? " *" : ""),
            description: field.description,
            control: valueRow
        )
    }

    private func fieldRow(
        label: String,
        description: String?,
        control: NSView,
        hidesControlLabel: Bool = false
    ) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)

        var informationViews: [NSView] = [labelView]
        if let description {
            let descriptionLabel = NSTextField(
                wrappingLabelWithString: description
            )
            descriptionLabel.textColor = .secondaryLabelColor
            descriptionLabel.font = .systemFont(ofSize: 11)
            informationViews.append(descriptionLabel)
        }

        let informationStack = NSStackView(views: informationViews)
        informationStack.orientation = .vertical
        informationStack.alignment = .leading
        informationStack.spacing = 4
        informationStack.translatesAutoresizingMaskIntoConstraints = false

        if hidesControlLabel, let checkbox = control as? NSButton {
            checkbox.title = ""
            checkbox.toolTip = label
        }

        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [informationStack, control])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 20
        row.distribution = .fill

        NSLayoutConstraint.activate([
            informationStack.widthAnchor.constraint(equalToConstant: 210),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
        return row
    }

    private func refresh() {
        externalLinksCheckbox.state =
            settings.opensExternalLinksInBrowser ? .on : .off
        recentOutputCheckbox.state =
            settings.includesRecentOutputInErrors ? .on : .off

        let percentage = Int((settings.pageZoom * 100).rounded())
        if let item = zoomPopup.itemTitles.firstIndex(of: "\(percentage)%") {
            zoomPopup.selectItem(at: item)
        } else {
            zoomPopup.selectItem(withTitle: "100%")
        }
        loadProjectConfiguration()
    }

    private func loadProjectConfiguration() {
        guard let userConfiguration else { return }
        do {
            let values = try DotEnvConfigurationStore(
                projectURL: projectURL,
                configuration: userConfiguration
            ).load()
            for field in userConfiguration.fields {
                setControlValue(
                    values[field.key, default: ""],
                    for: field
                )
            }
            projectStatusLabel.textColor = .secondaryLabelColor
            projectStatusLabel.stringValue =
                "Changes are written only when you choose Save & Restart."
            saveAndRestartButton?.isEnabled = true
        } catch {
            projectStatusLabel.textColor = .systemRed
            projectStatusLabel.stringValue = error.localizedDescription
            saveAndRestartButton?.isEnabled = false
        }
    }

    private func setControlValue(
        _ value: String,
        for field: EnmannerManifest.UserConfiguration.Field
    ) {
        if let checkbox = fieldControls[field.key] as? NSButton {
            checkbox.state = Self.booleanValue(value) ? .on : .off
        } else if let secretField = secretFieldControls[field.key] {
            secretField.stringValue = value
        } else if let textField = fieldControls[field.key] as? NSTextField {
            textField.stringValue = value
        }
    }

    private func controlValue(
        for field: EnmannerManifest.UserConfiguration.Field
    ) -> String {
        if let checkbox = fieldControls[field.key] as? NSButton {
            return checkbox.state == .on ? "true" : "false"
        }
        if let secretField = secretFieldControls[field.key] {
            return secretField.stringValue
        }
        return (fieldControls[field.key] as? NSTextField)?.stringValue ?? ""
    }

    private static func booleanValue(_ value: String) -> Bool {
        ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private func presentSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Project configuration was not saved."
        alert.informativeText = error.localizedDescription
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    @objc private func settingChanged() {
        settings.opensExternalLinksInBrowser =
            externalLinksCheckbox.state == .on
        settings.includesRecentOutputInErrors =
            recentOutputCheckbox.state == .on
        let percentage =
            Double(zoomPopup.titleOfSelectedItem?.dropLast() ?? "") ?? 100
        settings.pageZoom = percentage / 100
        onChange?()
    }

    @objc private func choosePath(_ sender: NSButton) {
        guard let field = fieldsByBrowseButton[ObjectIdentifier(sender)],
              let textField = fieldControls[field.key] as? NSTextField else {
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = field.type == .file
        panel.canChooseDirectories = field.type == .directory
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = field.type == .directory
        panel.directoryURL = URL(
            fileURLWithPath: textField.stringValue.isEmpty
                ? projectURL.path
                : textField.stringValue
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        textField.stringValue = url.path
    }

    @objc private func saveProjectConfiguration() {
        guard let userConfiguration else { return }
        let values = Dictionary(
            uniqueKeysWithValues: userConfiguration.fields.map {
                ($0.key, controlValue(for: $0))
            }
        )
        do {
            try DotEnvConfigurationStore(
                projectURL: projectURL,
                configuration: userConfiguration
            ).save(values)
            projectStatusLabel.textColor = .systemGreen
            projectStatusLabel.stringValue =
                "Saved \(userConfiguration.file). Restarting the server…"
            onSaveAndRestart?()
        } catch {
            presentSaveError(error)
        }
    }
}

@MainActor
private final class RevealableSecureField: NSView {
    private let secureField = NSSecureTextField()
    private let revealedField = NSTextField()
    private let revealButton = NSButton()
    private var isRevealed = false

    var stringValue: String {
        get {
            isRevealed
                ? revealedField.stringValue
                : secureField.stringValue
        }
        set {
            secureField.stringValue = newValue
            revealedField.stringValue = newValue
        }
    }

    var placeholderString: String? {
        get { secureField.placeholderString }
        set {
            secureField.placeholderString = newValue
            revealedField.placeholderString = newValue
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        secureField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        revealedField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        revealedField.isHidden = true

        revealButton.image = NSImage(
            systemSymbolName: "eye",
            accessibilityDescription: "Show value"
        )
        revealButton.imagePosition = .imageOnly
        revealButton.isBordered = false
        revealButton.contentTintColor = .secondaryLabelColor
        revealButton.toolTip = "Show value"
        revealButton.target = self
        revealButton.action = #selector(toggleVisibility)
        revealButton.setAccessibilityLabel("Show value")

        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        secureField.translatesAutoresizingMaskIntoConstraints = false
        revealedField.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(secureField)
        fieldContainer.addSubview(revealedField)

        let stack = NSStackView(views: [fieldContainer, revealButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        addSubview(stack)

        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(
                equalTo: fieldContainer.leadingAnchor
            ),
            secureField.trailingAnchor.constraint(
                equalTo: fieldContainer.trailingAnchor
            ),
            secureField.topAnchor.constraint(
                equalTo: fieldContainer.topAnchor
            ),
            secureField.bottomAnchor.constraint(
                equalTo: fieldContainer.bottomAnchor
            ),
            revealedField.leadingAnchor.constraint(
                equalTo: fieldContainer.leadingAnchor
            ),
            revealedField.trailingAnchor.constraint(
                equalTo: fieldContainer.trailingAnchor
            ),
            revealedField.topAnchor.constraint(
                equalTo: fieldContainer.topAnchor
            ),
            revealedField.bottomAnchor.constraint(
                equalTo: fieldContainer.bottomAnchor
            ),
            fieldContainer.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 240
            ),
            revealButton.widthAnchor.constraint(equalToConstant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleVisibility() {
        if isRevealed {
            secureField.stringValue = revealedField.stringValue
        } else {
            revealedField.stringValue = secureField.stringValue
        }
        isRevealed.toggle()
        secureField.isHidden = isRevealed
        revealedField.isHidden = !isRevealed

        let action = isRevealed ? "Hide value" : "Show value"
        let symbol = isRevealed ? "eye.slash" : "eye"
        revealButton.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: action
        )
        revealButton.toolTip = action
        revealButton.setAccessibilityLabel(action)
        window?.makeFirstResponder(
            isRevealed ? revealedField : secureField
        )
    }
}
