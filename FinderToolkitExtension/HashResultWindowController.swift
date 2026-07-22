import Cocoa

final class HashResultWindowController: NSWindowController {

    private let titleLabel = NSTextField(labelWithString: "哈希计算")
    private let statusLabel = NSTextField(labelWithString: "")
    private let algorithmStack = NSStackView()
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let progressIndicator = NSProgressIndicator()
    private let copyButton = NSButton(title: "复制全部", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private let primaryButton = NSButton(title: "开始计算", target: nil, action: nil)

    private var resultText = ""
    private var algorithmCheckboxes: [NSButton] = []
    private var contentWidthConstraints: [NSLayoutConstraint] = []
    private var retainedKey: UnsafeRawPointer?

    var onStart: (([String]) -> Void)?
    var onCancel: (() -> Void)?
    var onClose: (() -> Void)?
    let cancellationToken = HashCancellationToken()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "哈希计算"
        window.minSize = NSSize(width: 320, height: 300)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupUI()
        window.center()
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        showWindow(nil)
        window?.level = .normal
        window?.makeKey()
        window?.makeKeyAndOrderFront(nil)

        let key = Unmanaged.passUnretained(self).toOpaque()
        retainedKey = UnsafeRawPointer(key)
        if let application = NSApp {
            objc_setAssociatedObject(application, key, self, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func configurePreparation(message: String, algorithms: [String]) {
        titleLabel.stringValue = "准备计算哈希"
        statusLabel.stringValue = message
        textView.string = ""
        progressIndicator.isHidden = true
        scrollView.isHidden = true
        copyButton.isHidden = true
        algorithmStack.isHidden = false
        primaryButton.isHidden = false
        primaryButton.title = "开始计算"
        cancelButton.title = "取消"
        cancelButton.isEnabled = true

        algorithmCheckboxes.forEach { $0.removeFromSuperview() }
        algorithmCheckboxes = ToolkitSettingsPayload.allHashAlgorithms.map { algorithm in
            let checkbox = NSButton(checkboxWithTitle: algorithm, target: nil, action: nil)
            checkbox.state = algorithms.contains(algorithm) ? .on : .off
            checkbox.widthAnchor.constraint(equalToConstant: 112).isActive = true
            return checkbox
        }

        algorithmCheckboxes.forEach {
            algorithmStack.addArrangedSubview($0)
        }
        resizeWindow(width: 320, height: 330)
    }

    func showProgress(message: String) {
        cancellationToken.reset()
        titleLabel.stringValue = "正在计算哈希"
        statusLabel.stringValue = message
        textView.string = "正在读取文件..."
        algorithmStack.isHidden = true
        scrollView.isHidden = false
        progressIndicator.isHidden = false
        progressIndicator.doubleValue = 0
        copyButton.isHidden = true
        primaryButton.isHidden = true
        cancelButton.title = "取消"
        cancelButton.isEnabled = true
        resizeWindow(width: 360, height: 260)
        present()
    }

    func updateProgress(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressIndicator.doubleValue = min(1, max(0, progress))
        }
    }

    func showResult(_ result: String) {
        resultText = result
        titleLabel.stringValue = "哈希校验结果"
        statusLabel.stringValue = "计算完成"
        textView.string = result
        algorithmStack.isHidden = true
        scrollView.isHidden = false
        progressIndicator.isHidden = true
        copyButton.isHidden = false
        primaryButton.isHidden = true
        cancelButton.title = "关闭"
        cancelButton.isEnabled = true
        resizeWindow(width: 640, height: 420)
        present()
    }

    func showFailure(_ message: String) {
        resultText = message
        titleLabel.stringValue = "哈希计算失败"
        statusLabel.stringValue = "未完成"
        textView.string = message
        algorithmStack.isHidden = true
        scrollView.isHidden = false
        progressIndicator.isHidden = true
        copyButton.isHidden = false
        primaryButton.isHidden = true
        cancelButton.title = "关闭"
        cancelButton.isEnabled = true
        resizeWindow(width: 520, height: 360)
        present()
    }

    private func setupUI() {
        guard let window else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle

        algorithmStack.orientation = .vertical
        algorithmStack.alignment = .leading
        algorithmStack.spacing = 8
        algorithmStack.isHidden = true

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 14)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        copyButton.target = self
        copyButton.action = #selector(copyAll)
        copyButton.bezelStyle = .rounded
        copyButton.isHidden = true

        cancelButton.target = self
        cancelButton.action = #selector(cancelOrClose)
        cancelButton.bezelStyle = .rounded

        primaryButton.target = self
        primaryButton.action = #selector(startCalculation)
        primaryButton.bezelStyle = .rounded
        primaryButton.keyEquivalent = "\r"
        primaryButton.isHidden = true

        buttonRow.addArrangedSubview(copyButton)
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(primaryButton)

        [titleLabel, statusLabel, algorithmStack, scrollView, progressIndicator, buttonRow].forEach {
            root.addArrangedSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        contentWidthConstraints = [scrollView, progressIndicator, buttonRow].map {
            $0.widthAnchor.constraint(equalTo: root.widthAnchor)
        }
        NSLayoutConstraint.activate(contentWidthConstraints)

        let contentView = NSView()
        contentView.addSubview(root)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    @objc private func startCalculation() {
        let algorithms = algorithmCheckboxes
            .filter { $0.state == .on }
            .map(\.title)
        onStart?(algorithms.isEmpty ? defaultHashAlgorithms : algorithms)
    }

    @objc private func cancelOrClose() {
        if !progressIndicator.isHidden {
            cancellationToken.cancel()
            cancelButton.isEnabled = false
            cancelButton.title = "取消中..."
            onCancel?()
        } else {
            closeWindow()
        }
    }

    @objc private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
        let original = copyButton.title
        copyButton.title = "已复制"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.title = original
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private func releaseRetain() {
        if let retainedKey, let application = NSApp {
            objc_setAssociatedObject(application, retainedKey, nil, .OBJC_ASSOCIATION_RETAIN)
            self.retainedKey = nil
        }
    }

    private func resizeWindow(width: CGFloat, height: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        frame.origin.y += frame.height - height
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true, animate: false)
        window.center()
    }
}

extension HashResultWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        releaseRetain()
        onClose?()
    }
}
