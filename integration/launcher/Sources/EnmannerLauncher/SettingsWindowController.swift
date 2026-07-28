import AppKit
import EnmannerCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let mode: EnmannerManifest.Window.Mode
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

    var onChange: (() -> Void)?

    init(settings: AppSettings, mode: EnmannerManifest.Window.Mode) {
        self.settings = settings
        self.mode = mode

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
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

        let titleLabel = NSTextField(labelWithString: "General")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let zoomLabel = NSTextField(labelWithString: "Default page zoom:")
        zoomLabel.alignment = .right
        zoomPopup.addItems(withTitles: ["75%", "90%", "100%", "110%", "125%", "150%"])
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
        contentView.addSubview(stack)

        externalLinksCheckbox.isEnabled = mode == .embedded
        zoomPopup.isEnabled = mode == .embedded

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            zoomLabel.widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func refresh() {
        externalLinksCheckbox.state = settings.opensExternalLinksInBrowser ? .on : .off
        recentOutputCheckbox.state = settings.includesRecentOutputInErrors ? .on : .off

        let percentage = Int((settings.pageZoom * 100).rounded())
        if let item = zoomPopup.itemTitles.firstIndex(of: "\(percentage)%") {
            zoomPopup.selectItem(at: item)
        } else {
            zoomPopup.selectItem(withTitle: "100%")
        }
    }

    @objc private func settingChanged() {
        settings.opensExternalLinksInBrowser = externalLinksCheckbox.state == .on
        settings.includesRecentOutputInErrors = recentOutputCheckbox.state == .on
        let percentage = Double(zoomPopup.titleOfSelectedItem?.dropLast() ?? "") ?? 100
        settings.pageZoom = percentage / 100
        onChange?()
    }
}
