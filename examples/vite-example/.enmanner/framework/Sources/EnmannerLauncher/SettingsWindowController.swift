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
                width: userConfiguration == nil ? 520 : 640,
                height: userConfiguration == nil ? 300 : 620
            ),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 520, height: 300)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("EnmannerSettingsWindow")
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

    private func configureViews() {
        guard let window else { return }

        let contentView = NSView()
        window.contentView = contentView

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = makeGeneralView()
        tabView.addTabViewItem(generalItem)

        if let userConfiguration {
            let projectItem = NSTabViewItem(identifier: "project")
            projectItem.label = "Project"
            projectItem.view = makeProjectView(configuration: userConfiguration)
            tabView.addTabViewItem(projectItem)
        }

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
    }

    private func makeGeneralView() -> NSView {
        let view = NSView()
        let titleLabel = NSTextField(labelWithString: "General")
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

        let stack = NSStackView(
            views: [
                titleLabel,
                externalLinksCheckbox,
                zoomRow,
                recentOutputCheckbox,
                browserNote
            ]
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        view.addSubview(stack)

        externalLinksCheckbox.isEnabled = mode == .embedded
        zoomPopup.isEnabled = mode == .embedded

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -20
            ),
            stack.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 20
            ),
            zoomLabel.widthAnchor.constraint(equalToConstant: 150)
        ])
        return view
    }

    private func makeProjectView(
        configuration: EnmannerManifest.UserConfiguration
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
            labelWithString: "Project Configuration"
        )
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let fileLabel = NSTextField(
            wrappingLabelWithString:
                "These values are stored in \(configuration.file). " +
                "Secret fields are masked here but remain dotenv values " +
                "for the project and its tests."
        )
        fileLabel.textColor = .secondaryLabelColor
        fileLabel.font = .systemFont(ofSize: 11)

        var arrangedViews: [NSView] = [titleLabel, fileLabel]
        for field in configuration.fields {
            arrangedViews.append(makeFieldView(field))
        }

        projectStatusLabel.textColor = .secondaryLabelColor
        projectStatusLabel.font = .systemFont(ofSize: 11)
        arrangedViews.append(projectStatusLabel)

        let stack = NSStackView(views: arrangedViews)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
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
                constant: 16
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            scrollView.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 16
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: saveButton.topAnchor,
                constant: -12
            ),
            saveButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            saveButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -16
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
                constant: 4
            ),
            stack.trailingAnchor.constraint(
                equalTo: documentView.trailingAnchor,
                constant: -12
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
            if let description = field.description {
                return describedView(control: checkbox, description: description)
            }
            return checkbox
        }

        let label = NSTextField(
            labelWithString: field.label + (field.required ? " *" : "")
        )
        label.font = .systemFont(ofSize: 13, weight: .medium)

        let textField: NSTextField
        if field.type == .secret {
            textField = NSSecureTextField()
        } else {
            textField = NSTextField()
        }
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
        valueRow.widthAnchor.constraint(
            greaterThanOrEqualToConstant: 420
        ).isActive = true

        var views: [NSView] = [label, valueRow]
        if let description = field.description {
            let descriptionLabel = NSTextField(
                wrappingLabelWithString: description
            )
            descriptionLabel.textColor = .secondaryLabelColor
            descriptionLabel.font = .systemFont(ofSize: 11)
            descriptionLabel.widthAnchor.constraint(
                lessThanOrEqualToConstant: 520
            ).isActive = true
            views.append(descriptionLabel)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func describedView(
        control: NSView,
        description: String
    ) -> NSView {
        let descriptionLabel = NSTextField(
            wrappingLabelWithString: description
        )
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.font = .systemFont(ofSize: 11)
        descriptionLabel.widthAnchor.constraint(
            lessThanOrEqualToConstant: 520
        ).isActive = true
        let stack = NSStackView(views: [control, descriptionLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
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
