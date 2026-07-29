import AppKit

@MainActor
final class LogWindowController: NSWindowController {
    private let textView = NSTextView()
    private let entryCountLabel = NSTextField(labelWithString: "")
    private var currentLogs = ""

    init(appName: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(appName) Server Log"
        window.minSize = NSSize(width: 520, height: 320)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("EnmannerServerLogWindow")
        super.init(window: window)

        configureViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    func updateLogs(_ text: String) {
        currentLogs = text
        textView.string = text

        let entryCount = text.isEmpty ? 0 : text.split(separator: "\n").count
        entryCountLabel.stringValue =
            "\(entryCount) of the most recent 500 entries"

        if !text.isEmpty {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func configureViews() {
        guard let window else { return }

        let contentView = NSView()
        window.contentView = contentView

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let contentSize = scrollView.contentSize
        textView.frame = NSRect(origin: .zero, size: contentSize)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        entryCountLabel.translatesAutoresizingMaskIntoConstraints = false
        entryCountLabel.textColor = .secondaryLabelColor
        entryCountLabel.font = .systemFont(ofSize: 11)

        let copyButton = NSButton(
            title: "Copy All",
            target: self,
            action: #selector(copyAll)
        )
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(scrollView)
        contentView.addSubview(entryCountLabel)
        contentView.addSubview(copyButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            ),
            scrollView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 16
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: entryCountLabel.topAnchor,
                constant: -12
            ),

            entryCountLabel.leadingAnchor.constraint(
                equalTo: scrollView.leadingAnchor
            ),
            entryCountLabel.centerYAnchor.constraint(
                equalTo: copyButton.centerYAnchor
            ),
            entryCountLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -16
            ),

            copyButton.trailingAnchor.constraint(
                equalTo: scrollView.trailingAnchor
            )
        ])

        updateLogs("")
    }

    @objc private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentLogs, forType: .string)
    }
}
