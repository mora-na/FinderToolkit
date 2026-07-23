import Cocoa

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private enum Column {
        static let fileType = NSUserInterfaceItemIdentifier("fileType")
    }

    private var terminalPopup: NSPopUpButton!
    private var fileTypeTable: NSTableView!
    private var fileTypeInput: NSTextField!
    private var statusLabel: NSTextField!
    private var hashCheckboxes: [NSButton] = []
    private var developerToolCheckboxes: [NSButton] = []

    private var pendingTerminalApp = Settings.terminalApp
    private var pendingFileTypes = Settings.newFileTypes
    private var pendingHashAlgorithms = Settings.enabledHashAlgorithms
    private var pendingDeveloperTools = Settings.enabledDeveloperTools

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "FinderToolkit 设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 900, height: 690)
        self.init(window: window)
        window.contentView = buildContentView()
    }

    private func buildContentView() -> NSView {
        let root: NSView
        let layoutRoot = NSView()
        layoutRoot.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 26.0, *) {
            layoutRoot.wantsLayer = true
            layoutRoot.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.14)
                .cgColor
            let glass = NSGlassEffectView()
            glass.contentView = layoutRoot
            glass.cornerRadius = 0
            glass.style = .clear
            glass.tintColor = nil
            NSLayoutConstraint.activate([
                layoutRoot.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
                layoutRoot.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
                layoutRoot.topAnchor.constraint(equalTo: glass.topAnchor),
                layoutRoot.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
            ])
            root = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .underWindowBackground
            material.blendingMode = .behindWindow
            material.state = .active
            material.addSubview(layoutRoot)
            NSLayoutConstraint.activate([
                layoutRoot.leadingAnchor.constraint(equalTo: material.leadingAnchor),
                layoutRoot.trailingAnchor.constraint(equalTo: material.trailingAnchor),
                layoutRoot.topAnchor.constraint(equalTo: material.topAnchor),
                layoutRoot.bottomAnchor.constraint(equalTo: material.bottomAnchor)
            ])
            root = material
        }

        let header = buildHeader()
        let grid = buildModuleGrid()
        let footer = buildFooter()

        [header, grid, footer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            layoutRoot.addSubview($0)
        }

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: layoutRoot.leadingAnchor, constant: 28),
            header.trailingAnchor.constraint(equalTo: layoutRoot.trailingAnchor, constant: -28),
            header.topAnchor.constraint(equalTo: layoutRoot.topAnchor, constant: 48),

            grid.leadingAnchor.constraint(equalTo: layoutRoot.leadingAnchor, constant: 28),
            grid.trailingAnchor.constraint(equalTo: layoutRoot.trailingAnchor, constant: -28),
            grid.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            grid.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -14),

            footer.leadingAnchor.constraint(equalTo: layoutRoot.leadingAnchor, constant: 28),
            footer.trailingAnchor.constraint(equalTo: layoutRoot.trailingAnchor, constant: -28),
            footer.bottomAnchor.constraint(equalTo: layoutRoot.bottomAnchor, constant: -20),
            footer.heightAnchor.constraint(equalToConstant: 46)
        ])

        return root
    }

    private func buildHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 42),
            icon.heightAnchor.constraint(equalToConstant: 42)
        ])

        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let title = NSTextField(labelWithString: "FinderToolkit")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "Finder 菜单与扩展设置")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(labels)
        stack.addArrangedSubview(spacer)
        return stack
    }

    private func buildModuleGrid() -> NSView {
        let grid = NSGridView(views: [
            [buildGeneralModule(), buildHashModule()],
            [buildFileTypesModule(), buildExtensionModule()]
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 14
        grid.xPlacement = .fill
        grid.yPlacement = .fill

        for index in 0..<2 {
            grid.column(at: index).xPlacement = .fill
            grid.column(at: index).width = 425
        }
        grid.row(at: 0).height = 226
        grid.row(at: 1).height = 306

        if #available(macOS 26.0, *) {
            let container = NSGlassEffectContainerView()
            container.contentView = grid
            container.spacing = 0
            grid.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                grid.topAnchor.constraint(equalTo: container.topAnchor),
                grid.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return container
        }
        return grid
    }

    private func buildGeneralModule() -> NSView {
        let stack = moduleStack(
            iconName: "terminal",
            title: "终端与开发工具",
            subtitle: "勾选的应用会出现在 Finder 菜单中。"
        )

        let terminalRow = formRow(label: "打开终端")
        terminalPopup = NSPopUpButton()
        terminalPopup.addItem(withTitle: Settings.TerminalApp.terminal.displayName)
        terminalPopup.item(at: 0)?.representedObject = Settings.TerminalApp.terminal
        terminalPopup.addItem(withTitle: Settings.TerminalApp.iterm2.displayName)
        terminalPopup.item(at: 1)?.representedObject = Settings.TerminalApp.iterm2
        terminalPopup.selectItem(at: pendingTerminalApp == .iterm2 ? 1 : 0)
        terminalPopup.target = self
        terminalPopup.action = #selector(terminalChanged(_:))
        terminalPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 210).isActive = true
        terminalRow.addArrangedSubview(terminalPopup)

        stack.addArrangedSubview(terminalRow)

        let enabledTools = Set(pendingDeveloperTools)
        developerToolCheckboxes = Settings.allDeveloperTools.enumerated().map { index, tool in
            let checkbox = NSButton(
                checkboxWithTitle: tool.displayName,
                target: self,
                action: #selector(developerToolChanged(_:))
            )
            checkbox.tag = index
            checkbox.state = enabledTools.contains(tool.identifier) ? .on : .off
            checkbox.widthAnchor.constraint(equalToConstant: 116).isActive = true
            return checkbox
        }

        for rowStart in stride(from: 0, to: developerToolCheckboxes.count, by: 3) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            for checkbox in developerToolCheckboxes[rowStart..<min(rowStart + 3, developerToolCheckboxes.count)] {
                row.addArrangedSubview(checkbox)
            }
            stack.addArrangedSubview(row)
        }
        return moduleBox(stack)
    }

    private func buildHashModule() -> NSView {
        let stack = moduleStack(
            iconName: "number",
            title: "哈希算法",
            subtitle: "结果窗口只输出勾选的算法。"
        )
        let enabled = Set(pendingHashAlgorithms)
        hashCheckboxes = Settings.allHashAlgorithms.enumerated().map { index, algorithm in
            let checkbox = NSButton(checkboxWithTitle: algorithm, target: self, action: #selector(hashChanged(_:)))
            checkbox.tag = index
            checkbox.state = enabled.contains(algorithm) ? .on : .off
            checkbox.widthAnchor.constraint(equalToConstant: 92).isActive = true
            return checkbox
        }

        for rowStart in stride(from: 0, to: hashCheckboxes.count, by: 3) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            for checkbox in hashCheckboxes[rowStart..<min(rowStart + 3, hashCheckboxes.count)] {
                row.addArrangedSubview(checkbox)
            }
            stack.addArrangedSubview(row)
        }

        return moduleBox(stack)
    }

    private func buildFileTypesModule() -> NSView {
        let stack = moduleStack(
            iconName: "doc.badge.plus",
            title: "新建文件类型",
            subtitle: "列表顺序就是 Finder 子菜单顺序。"
        )

        fileTypeTable = NSTableView()
        fileTypeTable.headerView = nil
        fileTypeTable.rowHeight = 26
        fileTypeTable.dataSource = self
        fileTypeTable.delegate = self
        fileTypeTable.allowsEmptySelection = true
        fileTypeTable.usesAlternatingRowBackgroundColors = false
        fileTypeTable.gridStyleMask = []
        fileTypeTable.intercellSpacing = NSSize(width: 0, height: 0)
        fileTypeTable.backgroundColor = .clear

        let column = NSTableColumn(identifier: Column.fileType)
        column.title = "扩展名"
        column.isEditable = true
        fileTypeTable.addTableColumn(column)

        let tableScroll = NSScrollView()
        tableScroll.documentView = fileTypeTable
        tableScroll.hasVerticalScroller = true
        tableScroll.borderType = .noBorder
        tableScroll.drawsBackground = false
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.heightAnchor.constraint(equalToConstant: 142).isActive = true
        stack.addArrangedSubview(tableScroll)

        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8

        fileTypeInput = NSTextField()
        fileTypeInput.placeholderString = "输入一个或多个扩展名，例如 swift, json, log"
        fileTypeInput.delegate = self
        fileTypeInput.font = .systemFont(ofSize: 13)
        fileTypeInput.heightAnchor.constraint(equalToConstant: 30).isActive = true
        fileTypeInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inputRow.addArrangedSubview(fileTypeInput)

        let addButton = NSButton(title: "添加", target: self, action: #selector(addFileTypes))
        configureActionButton(addButton, symbolName: "plus")
        inputRow.addArrangedSubview(addButton)
        stack.addArrangedSubview(inputRow)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let removeButton = NSButton(title: "删除选中", target: self, action: #selector(removeSelectedFileType))
        configureActionButton(removeButton, symbolName: "minus")
        let defaultButton = NSButton(title: "恢复类型默认", target: self, action: #selector(resetFileTypes))
        configureActionButton(defaultButton, symbolName: "arrow.counterclockwise")

        buttonRow.addArrangedSubview(removeButton)
        buttonRow.addArrangedSubview(defaultButton)
        stack.addArrangedSubview(buttonRow)

        return moduleBox(stack)
    }

    private func buildExtensionModule() -> NSView {
        let stack = moduleStack(
            iconName: "puzzlepiece.extension",
            title: "扩展与同步",
            subtitle: "检查 Finder 扩展与共享设置状态。"
        )

        let extPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/PlugIns/FinderToolkitExtension.appex")
        let hasExtension = FileManager.default.fileExists(atPath: extPath.path)
        stack.addArrangedSubview(statusRow(
            title: hasExtension ? "Finder 扩展已安装" : "Finder 扩展未找到",
            color: hasExtension ? .systemGreen : .systemRed
        ))

        let authorization = extensionAuthorizationStatus()
        stack.addArrangedSubview(statusRow(
            title: authorization.title,
            color: authorization.color
        ))

        let settingsExists = FileManager.default.fileExists(atPath: ToolkitSettingsStore.userSettingsURL.path)
        stack.addArrangedSubview(statusRow(
            title: settingsExists ? "设置文件已创建" : "保存后创建设置文件",
            color: settingsExists ? .systemGreen : .systemOrange
        ))

        let pathLabel = NSTextField(labelWithString: displayPath(for: ToolkitSettingsStore.userSettingsURL))
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(pathLabel)

        let openSettingsButton = NSButton(title: "打开系统扩展设置", target: self, action: #selector(openSystemSettings))
        configureActionButton(openSettingsButton, symbolName: "gearshape")
        stack.addArrangedSubview(openSettingsButton)

        return moduleBox(stack)
    }

    private func buildFooter() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        statusLabel = NSTextField(labelWithString: lastSavedText())
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let resetButton = NSButton(title: "全部恢复默认", target: self, action: #selector(resetSettings))
        configureActionButton(resetButton, symbolName: "arrow.counterclockwise")
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(saveSettings))
        configureActionButton(saveButton, symbolName: "checkmark", emphasized: true)
        saveButton.keyEquivalent = "\r"
        saveButton.font = .systemFont(ofSize: 13, weight: .semibold)

        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(resetButton)
        stack.addArrangedSubview(saveButton)
        return stack
    }

    private func moduleStack(iconName: String, title: String, subtitle: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 11
        stack.edgeInsets = NSEdgeInsets(top: 17, left: 17, bottom: 17, right: 17)

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 9

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        labels.addArrangedSubview(titleLabel)
        labels.addArrangedSubview(subtitleLabel)
        header.addArrangedSubview(icon)
        header.addArrangedSubview(labels)
        stack.addArrangedSubview(header)
        return stack
    }

    private func moduleBox(_ content: NSStackView) -> NSView {
        let box: NSView
        if #available(macOS 26.0, *) {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.70)
                .cgColor
            content.layer?.cornerRadius = 8
            content.layer?.masksToBounds = true
            let glass = NSGlassEffectView()
            glass.contentView = content
            glass.cornerRadius = 8
            glass.style = .clear
            glass.tintColor = nil
            box = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .contentBackground
            material.blendingMode = .withinWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = 8
            material.layer?.borderWidth = 1
            material.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
            material.addSubview(content)
            box = material
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.topAnchor.constraint(equalTo: box.topAnchor),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }

    private func configureActionButton(_ button: NSButton, symbolName: String, emphasized: Bool = false) {
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: button.title)
        button.imagePosition = .imageLeading
        if #available(macOS 26.0, *) {
            button.bezelStyle = .glass
            if emphasized {
                button.bezelColor = .controlAccentColor
            }
        } else {
            button.bezelStyle = .rounded
        }
    }

    private func formRow(label: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13)
        labelView.textColor = .secondaryLabelColor
        labelView.widthAnchor.constraint(equalToConstant: 78).isActive = true
        row.addArrangedSubview(labelView)
        return row
    }

    private func statusRow(title: String, color: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4.5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 9).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)

        row.addArrangedSubview(dot)
        row.addArrangedSubview(label)
        return row
    }

    private func extensionAuthorizationStatus() -> (title: String, color: NSColor) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        let bundleIdentifier = "com.pandkided.FinderToolkit.Extension"
        process.arguments = ["-m", "-A", "-i", bundleIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            return ("无法检测扩展授权状态", .systemOrange)
        }

        if completion.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            return ("扩展授权状态检测超时", .systemOrange)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if output.contains("(no matches)") || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ("Finder 扩展未注册或未授权", .systemRed)
        }
        let lines = output.components(separatedBy: .newlines)
        if lines.contains(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("+")
                && trimmed.contains(bundleIdentifier)
        }) {
            return ("Finder 扩展已授权启用", .systemGreen)
        }
        if lines.contains(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("-")
                && trimmed.contains(bundleIdentifier)
        }) {
            return ("Finder 扩展未启用", .systemRed)
        }
        if output.contains(bundleIdentifier) {
            return ("Finder 扩展已注册，授权状态由系统返回为启用", .systemGreen)
        }
        if isExtensionProcessRunning(bundleIdentifier: bundleIdentifier) {
            return ("Finder 扩展已授权启用", .systemGreen)
        }
        return ("Finder 扩展未启用或未授权", .systemRed)
    }

    private func displayPath(for url: URL) -> String {
        let components = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 3, components[0] == "Users" else {
            return url.path
        }
        return "~/" + components.dropFirst(2).joined(separator: "/")
    }

    private func isExtensionProcessRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == bundleIdentifier
                || app.bundleURL?.lastPathComponent == "FinderToolkitExtension.appex"
        }
    }

    private func lastSavedText() -> String {
        guard let date = Settings.updatedAt else {
            return "尚未保存过设置"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return "上次保存：\(formatter.string(from: date))"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        pendingFileTypes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard pendingFileTypes.indices.contains(row) else { return nil }
        let identifier = Column.fileType
        let textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
            ?? NSTextField()
        textField.identifier = identifier
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.textColor = .labelColor
        textField.isEditable = true
        textField.delegate = self
        textField.stringValue = pendingFileTypes[row]
        return textField
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let value = object as? String else { return }
        let normalized = normalizedFileTypeEntries([value])
        guard let first = normalized.first, pendingFileTypes.indices.contains(row) else { return }
        pendingFileTypes[row] = first
        pendingFileTypes = Settings.normalizedFileTypes(pendingFileTypes)
        fileTypeTable.reloadData()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, textField == fileTypeInput {
            return
        }
        if let textField = obj.object as? NSTextField {
            let row = fileTypeTable.row(for: textField)
            if pendingFileTypes.indices.contains(row) {
                let normalized = normalizedFileTypeEntries([textField.stringValue])
                if let first = normalized.first {
                    pendingFileTypes[row] = first
                }
            }
        }
        pendingFileTypes = Settings.normalizedFileTypes(pendingFileTypes)
        fileTypeTable.reloadData()
    }

    @objc private func terminalChanged(_ sender: NSPopUpButton) {
        if let app = sender.selectedItem?.representedObject as? Settings.TerminalApp {
            pendingTerminalApp = app
        }
    }

    @objc private func hashChanged(_ sender: NSButton) {
        guard Settings.allHashAlgorithms.indices.contains(sender.tag) else { return }
        let algorithm = Settings.allHashAlgorithms[sender.tag]
        if sender.state == .on {
            if !pendingHashAlgorithms.contains(algorithm) {
                pendingHashAlgorithms.append(algorithm)
            }
        } else {
            pendingHashAlgorithms.removeAll { $0 == algorithm }
        }
    }

    @objc private func developerToolChanged(_ sender: NSButton) {
        guard Settings.allDeveloperTools.indices.contains(sender.tag) else { return }
        let identifier = Settings.allDeveloperTools[sender.tag].identifier
        if sender.state == .on {
            if !pendingDeveloperTools.contains(identifier) {
                pendingDeveloperTools.append(identifier)
            }
        } else {
            pendingDeveloperTools.removeAll { $0 == identifier }
        }
        pendingDeveloperTools = Settings.normalizedDeveloperTools(pendingDeveloperTools)
    }

    @objc private func addFileTypes() {
        let additions = normalizedFileTypeEntries(
            fileTypeInput.stringValue.components(separatedBy: CharacterSet(charactersIn: ",，;； \n"))
        )
        guard !additions.isEmpty else { return }
        pendingFileTypes = Settings.normalizedFileTypes(pendingFileTypes + additions)
        fileTypeInput.stringValue = ""
        fileTypeTable.reloadData()
        if !pendingFileTypes.isEmpty {
            fileTypeTable.selectRowIndexes(IndexSet(integer: pendingFileTypes.count - 1), byExtendingSelection: false)
        }
    }

    @objc private func removeSelectedFileType() {
        let selected = fileTypeTable.selectedRowIndexes
        guard !selected.isEmpty else { return }
        pendingFileTypes = pendingFileTypes.enumerated()
            .filter { !selected.contains($0.offset) }
            .map(\.element)
        pendingFileTypes = Settings.normalizedFileTypes(pendingFileTypes)
        fileTypeTable.reloadData()
    }

    @objc private func resetFileTypes() {
        pendingFileTypes = Settings.defaultNewFileTypes
        fileTypeTable.reloadData()
    }

    @objc private func resetSettings() {
        pendingTerminalApp = .terminal
        pendingFileTypes = Settings.defaultNewFileTypes
        pendingHashAlgorithms = Settings.defaultHashAlgorithms
        pendingDeveloperTools = Settings.defaultDeveloperTools
        terminalPopup.selectItem(at: 0)
        for (index, checkbox) in hashCheckboxes.enumerated() {
            checkbox.state = Settings.defaultHashAlgorithms.contains(
                Settings.allHashAlgorithms[index]
            ) ? .on : .off
        }
        for (index, checkbox) in developerToolCheckboxes.enumerated() {
            checkbox.state = Settings.defaultDeveloperTools.contains(
                Settings.allDeveloperTools[index].identifier
            ) ? .on : .off
        }
        fileTypeTable.reloadData()
        statusLabel.stringValue = "已恢复为默认值，点击保存后生效"
        statusLabel.textColor = .secondaryLabelColor
    }

    @objc private func saveSettings() {
        pendingFileTypes = Settings.normalizedFileTypes(pendingFileTypes)
        pendingHashAlgorithms = Settings.normalizedHashAlgorithms(pendingHashAlgorithms)
        pendingDeveloperTools = Settings.normalizedDeveloperTools(pendingDeveloperTools)
        let saved = Settings.save(
            terminalApp: pendingTerminalApp,
            newFileTypes: pendingFileTypes,
            enabledHashAlgorithms: pendingHashAlgorithms,
            enabledDeveloperTools: pendingDeveloperTools
        )
        fileTypeTable.reloadData()
        if saved {
            statusLabel.stringValue = "已保存，Finder 扩展下次打开菜单时生效"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "保存失败，请检查设置目录权限后重试"
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    private func normalizedFileTypeEntries(_ values: [String]) -> [String] {
        let normalized = values
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .lowercased()
            }
            .filter { value in
                !value.isEmpty
                    && value.count <= 64
                    && !value.contains("/")
                    && !value.contains(":")
                    && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
            }

        let unique = normalized.reduce(into: [String]()) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }
        return Array(unique.prefix(64))
    }
}
