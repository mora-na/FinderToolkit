import Cocoa

class NewFileWindowController: NSWindowController, NSWindowDelegate {

    // 文件类型预设
    private let fileTemplates: [(name: String, ext: String)] = [
        ("纯文本文件",      "txt"),
        ("Markdown",       "md"),
        ("Shell 脚本",     "sh"),
        ("Python 脚本",    "py"),
        ("JavaScript",     "js"),
        ("TypeScript",     "ts"),
        ("JSON 文件",      "json"),
        ("YAML 文件",      "yaml"),
        ("HTML 文件",      "html"),
        ("CSS 文件",       "css"),
        ("Swift 文件",     "swift"),
        ("自定义格式...",   "custom"),
    ]

    private var targetDirectory: URL!
    private var nameField: NSTextField!
    private var typePopup: NSPopUpButton!
    private var retainedKey: UnsafeRawPointer?

    // MARK: - 静态入口

    static func show(in directory: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        let controller = NewFileWindowController(directory: directory)
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        // 用 objc_setAssociatedObject 保持强引用，防止 ARC 释放
        let key = UnsafeRawPointer(Unmanaged.passUnretained(controller).toOpaque())
        controller.retainedKey = key
        if let application = NSApp {
            objc_setAssociatedObject(
                application,
                key,
                controller,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    // MARK: - 初始化

    convenience init(directory: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "新建文件"
        window.center()
        self.init(window: window)
        self.targetDirectory = directory
        window.delegate = self
        setupUI()
    }

    // MARK: - UI 构建

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // 目录显示标签
        let dirLabel = NSTextField(labelWithString: "位置：\(targetDirectory.path)")
        dirLabel.font = NSFont.systemFont(ofSize: 11)
        dirLabel.textColor = .secondaryLabelColor
        dirLabel.lineBreakMode = .byTruncatingMiddle
        dirLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dirLabel)

        // 文件类型行
        let typeLabel = makeLabel("文件类型：")
        contentView.addSubview(typeLabel)

        typePopup = NSPopUpButton()
        typePopup.translatesAutoresizingMaskIntoConstraints = false
        for template in fileTemplates {
            typePopup.addItem(withTitle: "\(template.name)  .\(template.ext)")
        }
        typePopup.target = self
        typePopup.action = #selector(typeChanged(_:))
        contentView.addSubview(typePopup)

        // 文件名行
        let nameLabel = makeLabel("文件名称：")
        contentView.addSubview(nameLabel)

        nameField = NSTextField()
        nameField.placeholderString = "输入文件名（含扩展名）"
        nameField.stringValue = "新建文件.txt"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameField)

        // 按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)

        let createButton = NSButton(title: "创建", target: self, action: #selector(create))
        createButton.keyEquivalent = "\r"
        createButton.bezelStyle = .rounded
        createButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(createButton)

        NSLayoutConstraint.activate([
            dirLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            dirLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dirLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            typeLabel.topAnchor.constraint(equalTo: dirLabel.bottomAnchor, constant: 16),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            typeLabel.widthAnchor.constraint(equalToConstant: 72),

            typePopup.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            typePopup.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            typePopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            nameLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.widthAnchor.constraint(equalToConstant: 72),

            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            cancelButton.trailingAnchor.constraint(equalTo: createButton.leadingAnchor, constant: -8),

            createButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            createButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            createButton.widthAnchor.constraint(equalToConstant: 80),
        ])
    }

    private func makeLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Actions

    @objc private func typeChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard fileTemplates.indices.contains(index) else { return }
        let template = fileTemplates[index]

        if template.ext == "custom" {
            let currentName = (nameField.stringValue as NSString).deletingPathExtension
            nameField.stringValue = currentName
            nameField.selectText(nil)
        } else {
            let currentName = (nameField.stringValue as NSString).deletingPathExtension
            let baseName = currentName.isEmpty ? "新建文件" : currentName
            nameField.stringValue = "\(baseName).\(template.ext)"
        }
    }

    @objc private func create() {
        let fileName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fileName.isEmpty else {
            showError("文件名不能为空")
            return
        }

        guard fileName.count <= 255 else {
            showError("文件名不能超过 255 个字符")
            return
        }

        // 检查非法字符
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        if fileName.unicodeScalars.contains(where: { invalidChars.contains($0) }) {
            showError("文件名包含非法字符：/ \\ : * ? \" < > |")
            return
        }

        let fileURL = targetDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let alert = NSAlert()
            alert.messageText = "文件已存在"
            alert.informativeText = "\"\(fileName)\" 已存在，是否覆盖？"
            alert.addButton(withTitle: "覆盖")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            closeWindow()
            // 在 Finder 中选中新建的文件
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            showError("创建失败：\(error.localizedDescription)")
        }
    }

    @objc private func cancel() {
        closeWindow()
    }

    private func closeWindow() {
        window?.close()
    }

    private func releaseRetain() {
        if let retainedKey, let application = NSApp {
            objc_setAssociatedObject(application, retainedKey, nil, .OBJC_ASSOCIATION_RETAIN)
        }
        retainedKey = nil
    }

    func windowWillClose(_ notification: Notification) {
        releaseRetain()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
