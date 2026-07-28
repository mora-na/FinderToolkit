import Cocoa

final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private enum Column {
        static let fileType = NSUserInterfaceItemIdentifier("fileType")
    }

    private final class StatusRowView: NSStackView {
        private let dot = NSView()
        private let label: NSTextField

        init(title: String, color: NSColor) {
            label = NSTextField(labelWithString: title)
            super.init(frame: .zero)

            orientation = .horizontal
            alignment = .centerY
            spacing = 8

            dot.wantsLayer = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 9).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 9).isActive = true
            dot.layer?.cornerRadius = 4.5

            label.font = .systemFont(ofSize: 13)
            addArrangedSubview(dot)
            addArrangedSubview(label)
            update(title: title, color: color)
        }

        required init?(coder: NSCoder) {
            fatalError("StatusRowView does not support NSCoder")
        }

        func update(title: String, color: NSColor) {
            label.stringValue = title
            dot.layer?.backgroundColor = color.cgColor
        }
    }

    private var terminalCheckboxes: [NSButton] = []
    private var fileTypeTable: NSTableView!
    private var fileTypeInput: NSTextField!
    private var statusLabel: NSTextField!
    private var hashCheckboxes: [NSButton] = []
    private var developerToolCheckboxes: [NSButton] = []
    private var extensionInstalledStatus: StatusRowView!
    private var extensionAuthorizationStatus: StatusRowView!
    private var settingsFileStatus: StatusRowView!
    private var statusRefreshTimer: Timer?
    private var statusRefreshInFlight = false
    private var statusRefreshSequence = 0

    private var pendingTerminalTools = Settings.enabledTerminalTools
    private var pendingFileTypes = Settings.newFileTypes
    private var pendingHashAlgorithms = Settings.enabledHashAlgorithms
    private var pendingDeveloperTools = Settings.enabledDeveloperTools

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 740),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FinderToolkit 设置"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 710)
        self.init(window: window)
        window.contentView = buildContentView()
    }

    deinit {
        statusLog("settings controller deinit")
        statusRefreshTimer?.invalidate()
    }

    override func showWindow(_ sender: Any?) {
        window?.delegate = self
        super.showWindow(sender)
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        statusLog(
            "settings window shown appPath=\(Bundle.main.bundleURL.path) "
                + "bundleID=\(Bundle.main.bundleIdentifier ?? "unknown") "
                + "version=\(appVersion) build=\(buildVersion)"
        )
        startStatusRefreshTimer()
        refreshStatuses()
    }

    func windowWillClose(_ notification: Notification) {
        statusLog("settings window closing; invalidate status timer")
        statusRefreshTimer?.invalidate()
        statusRefreshTimer = nil
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let header = buildHeader()
        let grid = buildModuleGrid()
        let footer = buildFooter()

        [header, grid, footer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),

            grid.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            grid.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            grid.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            footer.heightAnchor.constraint(equalToConstant: 34)
        ])

        return root
    }

    private func buildHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14

        let title = NSTextField(labelWithString: "Finder 菜单默认行为")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "保存后 Finder 扩展下次打开菜单时读取同一份原生设置文件。")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
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
            grid.column(at: index).width = 408
        }
        grid.row(at: 0).height = 270
        grid.row(at: 1).height = 300

        return grid
    }

    private func buildGeneralModule() -> NSView {
        let stack = moduleStack(
            title: "终端与开发工具",
            subtitle: "选择的终端和开发工具会显示在 Finder 菜单中。"
        )

        stack.addArrangedSubview(toolSectionTitle("终端工具"))
        let enabledTerminals = Set(pendingTerminalTools)
        terminalCheckboxes = Settings.allTerminalTools.enumerated().map { index, tool in
            let checkbox = NSButton(
                checkboxWithTitle: tool.displayName,
                target: self,
                action: #selector(terminalChanged(_:))
            )
            checkbox.tag = index
            checkbox.state = enabledTerminals.contains(tool.identifier) ? .on : .off
            checkbox.widthAnchor.constraint(equalToConstant: 116).isActive = true
            return checkbox
        }

        for rowStart in stride(from: 0, to: terminalCheckboxes.count, by: 3) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            for checkbox in terminalCheckboxes[rowStart..<min(rowStart + 3, terminalCheckboxes.count)] {
                row.addArrangedSubview(checkbox)
            }
            stack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(toolSectionTitle("开发工具"))
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
        let stack = moduleStack(title: "哈希算法", subtitle: "只在菜单结果中输出勾选的算法。")
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
        let stack = moduleStack(title: "新建文件类型", subtitle: "列表顺序就是 Finder 子菜单顺序。")

        fileTypeTable = NSTableView()
        fileTypeTable.headerView = nil
        fileTypeTable.rowHeight = 26
        fileTypeTable.dataSource = self
        fileTypeTable.delegate = self
        fileTypeTable.allowsEmptySelection = true
        fileTypeTable.usesAlternatingRowBackgroundColors = true

        let column = NSTableColumn(identifier: Column.fileType)
        column.title = "扩展名"
        column.isEditable = true
        fileTypeTable.addTableColumn(column)

        let tableScroll = NSScrollView()
        tableScroll.documentView = fileTypeTable
        tableScroll.hasVerticalScroller = true
        tableScroll.borderType = .bezelBorder
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.heightAnchor.constraint(equalToConstant: 138).isActive = true
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
        addButton.bezelStyle = .rounded
        inputRow.addArrangedSubview(addButton)
        stack.addArrangedSubview(inputRow)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let removeButton = NSButton(title: "删除选中", target: self, action: #selector(removeSelectedFileType))
        removeButton.bezelStyle = .rounded
        let defaultButton = NSButton(title: "恢复类型默认", target: self, action: #selector(resetFileTypes))
        defaultButton.bezelStyle = .rounded

        buttonRow.addArrangedSubview(removeButton)
        buttonRow.addArrangedSubview(defaultButton)
        stack.addArrangedSubview(buttonRow)

        return moduleBox(stack)
    }

    private func buildExtensionModule() -> NSView {
        let stack = moduleStack(title: "扩展与同步", subtitle: "用于确认扩展和共享设置文件是否存在。")

        extensionInstalledStatus = statusRow(title: "正在检测 Finder 扩展...", color: .systemOrange)
        stack.addArrangedSubview(extensionInstalledStatus)

        extensionAuthorizationStatus = statusRow(title: "正在检测扩展授权...", color: .systemOrange)
        stack.addArrangedSubview(extensionAuthorizationStatus)

        settingsFileStatus = statusRow(title: "正在检查共享设置...", color: .systemOrange)
        stack.addArrangedSubview(settingsFileStatus)

        let pathLabel = NSTextField(labelWithString: displayPath(for: ToolkitSettingsStore.userSettingsURL))
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(pathLabel)

        let openSettingsButton = NSButton(title: "打开系统扩展设置", target: self, action: #selector(openSystemSettings))
        openSettingsButton.bezelStyle = .rounded
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
        resetButton.bezelStyle = .rounded
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.font = .systemFont(ofSize: 13, weight: .semibold)

        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(resetButton)
        stack.addArrangedSubview(saveButton)
        return stack
    }

    private func moduleStack(title: String, subtitle: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func moduleBox(_ content: NSStackView) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.85)
        box.cornerRadius = 8
        box.fillColor = NSColor.controlBackgroundColor
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.topAnchor.constraint(equalTo: box.topAnchor),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }

    private func toolSectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
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

    private func statusRow(title: String, color: NSColor) -> StatusRowView {
        StatusRowView(title: title, color: color)
    }

    private func startStatusRefreshTimer() {
        guard statusRefreshTimer == nil else {
            statusLog("status refresh timer already active")
            return
        }
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshStatuses()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusRefreshTimer = timer
        statusLog("status refresh timer started interval=3s runLoopMode=common")
    }

    private func refreshStatuses() {
        statusRefreshSequence += 1
        let refreshID = statusRefreshSequence
        guard !statusRefreshInFlight,
              extensionInstalledStatus != nil,
              extensionAuthorizationStatus != nil,
              settingsFileStatus != nil else {
            statusLog(
                "status refresh skipped id=\(refreshID) inFlight=\(statusRefreshInFlight) "
                    + "viewsReady=\(extensionInstalledStatus != nil && extensionAuthorizationStatus != nil && settingsFileStatus != nil)"
            )
            return
        }
        statusRefreshInFlight = true

        let extensionURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/PlugIns/FinderToolkitExtension.appex")
        let settingsURL = ToolkitSettingsStore.userSettingsURL
        statusLog(
            "status refresh begin id=\(refreshID) appPath=\(Bundle.main.bundleURL.path) "
                + "extensionPath=\(extensionURL.path) extensionExists=\(FileManager.default.fileExists(atPath: extensionURL.path)) "
                + "settingsPath=\(settingsURL.path) settingsExists=\(FileManager.default.fileExists(atPath: settingsURL.path))"
        )
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let hasExtension = FileManager.default.fileExists(atPath: extensionURL.path)
            let authorization = self?.readExtensionAuthorizationStatus()
                ?? ("无法检测扩展授权状态", NSColor.systemOrange)
            let settingsExists = FileManager.default.fileExists(atPath: settingsURL.path)
            self?.statusLog(
                "status refresh read complete id=\(refreshID) extensionExists=\(hasExtension) "
                    + "authorizationTitle=\(authorization.0) settingsExists=\(settingsExists)"
            )

            DispatchQueue.main.async {
                guard let self else { return }
                self.statusRefreshInFlight = false
                self.extensionInstalledStatus.update(
                    title: hasExtension ? "Finder 扩展已安装" : "Finder 扩展未找到",
                    color: hasExtension ? .systemGreen : .systemRed
                )
                self.extensionAuthorizationStatus.update(
                    title: authorization.0,
                    color: authorization.1
                )
                self.settingsFileStatus.update(
                    title: settingsExists ? "设置文件已创建" : "保存后创建设置文件",
                    color: settingsExists ? .systemGreen : .systemOrange
                )
                self.statusLog("status refresh UI updated id=\(refreshID) authorizationTitle=\(authorization.0)")
            }
        }
    }

    private func readExtensionAuthorizationStatus() -> (title: String, color: NSColor) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        let bundleIdentifier = "com.pandkided.FinderToolkit.Extension"
        let arguments = ["-m", "-A", "-i", bundleIdentifier]
        process.arguments = arguments

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        statusLog(
            "pluginkit start executable=\(process.executableURL?.path ?? "unknown") "
                + "args=\(arguments.joined(separator: " ")) bundleID=\(bundleIdentifier)"
        )

        do {
            try process.run()
        } catch {
            statusLog("pluginkit run failed error=\(error.localizedDescription)")
            return ("无法检测扩展授权状态", .systemOrange)
        }

        if completion.wait(timeout: .now() + 3) == .timedOut {
            statusLog("pluginkit timeout pid=\(process.processIdentifier); terminating process")
            process.terminate()
            return ("扩展授权状态检测超时", .systemOrange)
        }

        let stdoutData = standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let combinedOutput = [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let lines = combinedOutput.components(separatedBy: .newlines)
        let matchingLines = lines
            .filter { $0.contains(bundleIdentifier) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let enabledLine = matchingLines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("+")
                && trimmed.contains(bundleIdentifier)
        }
        let disabledLine = matchingLines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("-")
                && trimmed.contains(bundleIdentifier)
        }
        statusLog(
            "pluginkit finish pid=\(process.processIdentifier) exit=\(process.terminationStatus) "
                + "reason=\(process.terminationReason) stdout=\(logText(stdout)) stderr=\(logText(stderr)) "
                + "matchingLines=\(matchingLines)"
        )

        if let enabledLine {
            statusLog("pluginkit decision=enabled matchedLine=\(enabledLine)")
            return ("Finder 扩展已授权启用", .systemGreen)
        }
        if let disabledLine {
            statusLog("pluginkit decision=disabled matchedLine=\(disabledLine)")
            return ("Finder 扩展未启用", .systemRed)
        }

        let runningExtensionApplications = NSWorkspace.shared.runningApplications.filter { application in
            application.bundleIdentifier == bundleIdentifier
                || application.bundleURL?.lastPathComponent == "FinderToolkitExtension.appex"
        }
        statusLog("pluginkit fallback runningExtensionApplications=\(runningExtensionApplications.count)")
        if !runningExtensionApplications.isEmpty {
            statusLog("pluginkit decision=enabled fallback=running-extension")
            return ("Finder 扩展已授权启用", .systemGreen)
        }

        if combinedOutput.contains(bundleIdentifier) {
            statusLog("pluginkit decision=registered fallback=bundle-id-match")
            return ("Finder 扩展已注册，授权状态由系统返回为启用", .systemGreen)
        }

        if combinedOutput.contains("(no matches)") {
            statusLog("pluginkit decision=not-registered reason=no-matches-marker")
        } else if combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusLog("pluginkit decision=not-registered reason=empty-output")
        } else {
            statusLog("pluginkit decision=not-registered reason=no-bundle-id-match")
        }
        return ("Finder 扩展未注册或未授权", .systemRed)
    }

    private func statusLog(_ message: String) {
        NSLog("FinderToolkit[status] %@", message)
    }

    private func logText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return String(normalized.prefix(2000))
    }

    private func displayPath(for url: URL) -> String {
        let components = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 3, components[0] == "Users" else {
            return url.path
        }
        return "~/" + components.dropFirst(2).joined(separator: "/")
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
        textField.backgroundColor = .clear
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

    @objc private func terminalChanged(_ sender: NSButton) {
        guard Settings.allTerminalTools.indices.contains(sender.tag) else { return }
        let identifier = Settings.allTerminalTools[sender.tag].identifier
        if sender.state == .on {
            if !pendingTerminalTools.contains(identifier) {
                pendingTerminalTools.append(identifier)
            }
        } else {
            pendingTerminalTools.removeAll { $0 == identifier }
        }
        pendingTerminalTools = Settings.normalizedTerminalTools(pendingTerminalTools)
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
        pendingTerminalTools = Settings.defaultTerminalTools
        pendingFileTypes = Settings.defaultNewFileTypes
        pendingHashAlgorithms = Settings.defaultHashAlgorithms
        pendingDeveloperTools = Settings.defaultDeveloperTools
        for (index, checkbox) in terminalCheckboxes.enumerated() {
            checkbox.state = Settings.defaultTerminalTools.contains(
                Settings.allTerminalTools[index].identifier
            ) ? .on : .off
        }
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
        pendingTerminalTools = Settings.normalizedTerminalTools(pendingTerminalTools)
        pendingDeveloperTools = Settings.normalizedDeveloperTools(pendingDeveloperTools)
        let saved = Settings.save(
            enabledTerminalTools: pendingTerminalTools,
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
        refreshStatuses()
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
