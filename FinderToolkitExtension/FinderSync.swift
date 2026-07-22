import Cocoa
import FinderSync
import UserNotifications

@objc(FinderSync)
class FinderSync: FIFinderSync {
    private var developerToolTargetDirectory: URL?

    override init() {
        super.init()
        // 监听整个文件系统根目录
        // 这样在任何 Finder 窗口内右键都能触发菜单
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/")
        ]
    }

    // MARK: - 菜单注册（核心方法）

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "FinderToolkit")
        NSLog(
            "FinderToolkit menu settings terminal=%@ fileTypes=%@ hashAlgorithms=%@ developerTools=%@ settingsFile=%@",
            ExtensionSettings.useITerm2 ? "iterm2" : "terminal",
            ExtensionSettings.newFileTypes.joined(separator: ","),
            ExtensionSettings.enabledHashAlgorithms.joined(separator: ","),
            ExtensionSettings.enabledDeveloperTools.map(\.identifier).joined(separator: ","),
            ToolkitSettingsStore.userSettingsURL.path
        )

        switch menuKind {

        // 右键点击「选中的文件/文件夹」时
        case .contextualMenuForItems:
            addNewFileItem(to: menu)
            addCopyPathItem(to: menu)
            addHashItem(to: menu)
            addOpenTerminalItem(to: menu)
            addDeveloperToolItems(to: menu)

        // 右键点击「文件夹空白处」时
        case .contextualMenuForContainer:
            addNewFileItem(to: menu)
            addCopyPathItem(to: menu)
            addOpenTerminalItem(to: menu)
            addDeveloperToolItems(to: menu)

        // 侧边栏右键
        case .contextualMenuForSidebar:
            addCopyPathItem(to: menu)

        case .toolbarItemMenu:
            addCopyPathItem(to: menu)

        @unknown default:
            break
        }

        return menu
    }

    // MARK: - 菜单项构建

    private func addCopyPathItem(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "复制路径",
            action: #selector(copyPath(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    private func addHashItem(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "计算hash",
            action: #selector(calculateHash(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    private func addNewFileItem(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "新建文件",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: "新建文件")
        let types = ExtensionSettings.newFileTypes
        for (index, ext) in types.enumerated() {
            let child = NSMenuItem(
                title: ext,
                action: #selector(createNewFile(_:)),
                keyEquivalent: ""
            )
            child.target = self
            child.tag = index
            child.representedObject = ext
            submenu.addItem(child)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    private func addOpenTerminalItem(to menu: NSMenu) {
        let terminalName = ExtensionSettings.useITerm2 ? "iTerm2" : "Terminal"
        let item = NSMenuItem(
            title: "打开终端 (\(terminalName))",
            action: #selector(openTerminal(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    private func addDeveloperToolItems(to menu: NSMenu) {
        developerToolTargetDirectory = currentTargetDirectory()

        for tool in ExtensionSettings.enabledDeveloperTools {
            guard let action = developerToolAction(for: tool.identifier) else { continue }
            let item = NSMenuItem(
                title: tool.menuTitle,
                action: action,
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
        }
    }

    private func developerToolAction(for identifier: String) -> Selector? {
        switch identifier {
        case "vscode": return #selector(openVSCode(_:))
        case "cursor": return #selector(openCursor(_:))
        case "idea": return #selector(openIntelliJIDEA(_:))
        case "pycharm": return #selector(openPyCharm(_:))
        case "webstorm": return #selector(openWebStorm(_:))
        case "android-studio": return #selector(openAndroidStudio(_:))
        case "xcode": return #selector(openXcode(_:))
        default: return nil
        }
    }

    // MARK: - 功能一：复制路径

    @objc func copyPath(_ sender: AnyObject?) {
        let urls = FIFinderSyncController.default().selectedItemURLs() ?? []

        let paths: [String]
        if urls.isEmpty {
            // 空白处右键：复制当前目录路径
            if let containerURL = FIFinderSyncController.default().targetedURL() {
                paths = [containerURL.path]
            } else {
                return
            }
        } else {
            paths = urls.map { $0.path }
        }

        let result = paths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)

        let count = paths.count
        sendNotification(
            title: "路径已复制",
            body: count == 1 ? paths[0] : "已复制 \(count) 个路径"
        )
    }

    // MARK: - 功能二：新建文件

    @objc func createNewFile(_ sender: AnyObject?) {
        guard let menuItem = sender as? NSMenuItem,
              let ext = newFileExtension(from: menuItem),
              let targetDirectory = currentTargetDirectory() else {
            return
        }

        let fileURL = uniqueFileURL(
            in: targetDirectory,
            baseName: "新建文件",
            fileExtension: ext
        )

        do {
            try createEmptyFile(at: fileURL)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            sendNotification(title: "新建文件", body: fileURL.lastPathComponent)
            return
        } catch {
            createFileWithFinderAppleScript(
                at: fileURL,
                targetDirectory: targetDirectory,
                originalError: error
            )
        }
    }

    // MARK: - 功能三：计算哈希

    @objc func calculateHash(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(),
              !urls.isEmpty else { return }

        let fileURLs = urls.filter { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return !isDir.boolValue
        }

        guard !fileURLs.isEmpty else {
            showAlert(title: "提示", message: "请选择文件（不支持文件夹）")
            return
        }

        var components = URLComponents()
        components.scheme = "findertoolkit"
        components.host = "hash"
        components.queryItems = fileURLs.map { URLQueryItem(name: "file", value: $0.path) }

        guard let url = components.url else {
            showAlert(title: "计算hash", message: "无法创建主程序请求。")
            return
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - 功能四：打开终端

    @objc func openTerminal(_ sender: AnyObject?) {
        guard let targetDirectory = currentTargetDirectory() else { return }

        if ExtensionSettings.useITerm2 {
            openITerm2(at: targetDirectory)
        } else {
            openSystemTerminal(at: targetDirectory)
        }
    }

    private func openSystemTerminal(at directory: URL) {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { [weak self] _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.openTerminalWithAppleScript(at: directory, fallbackError: error)
                }
            }
        }
    }

    private func openITerm2(at directory: URL) {
        if let itermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.open(
                [directory],
                withApplicationAt: itermURL,
                configuration: configuration
            ) { [weak self] _, error in
                if let error {
                    DispatchQueue.main.async {
                        self?.openITerm2WithAppleScript(at: directory, fallbackError: error)
                    }
                }
            }
        } else {
            openITerm2WithAppleScript(at: directory, fallbackError: NSError(
                domain: "FinderToolkit",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "iTerm2 未安装"]
            ))
        }
    }

    private func openITerm2WithAppleScript(at directory: URL, fallbackError: Error) {
        let path = directory.path
        let script = """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "cd '\(appleScriptEscaped(path))'"
            end tell
        end tell
        """

        var scriptError: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&scriptError)
        }

        if let scriptError {
            let message = scriptError[NSAppleScript.errorMessage] as? String
                ?? fallbackError.localizedDescription
            showAlert(title: "打开 iTerm2 失败", message: message)
        }
    }

    // MARK: - 功能五：在开发工具中打开

    @objc private func openVSCode(_ sender: AnyObject?) { openDeveloperTool(identifier: "vscode") }
    @objc private func openCursor(_ sender: AnyObject?) { openDeveloperTool(identifier: "cursor") }
    @objc private func openIntelliJIDEA(_ sender: AnyObject?) { openDeveloperTool(identifier: "idea") }
    @objc private func openPyCharm(_ sender: AnyObject?) { openDeveloperTool(identifier: "pycharm") }
    @objc private func openWebStorm(_ sender: AnyObject?) { openDeveloperTool(identifier: "webstorm") }
    @objc private func openAndroidStudio(_ sender: AnyObject?) { openDeveloperTool(identifier: "android-studio") }
    @objc private func openXcode(_ sender: AnyObject?) { openDeveloperTool(identifier: "xcode") }

    private func openDeveloperTool(identifier: String) {
        guard let tool = DeveloperTool.tool(withIdentifier: identifier) else { return }
        guard let targetDirectory = resolvedDeveloperToolTargetDirectory() else {
            showAlert(title: "打开 \(tool.displayName) 失败", message: "无法确定 Finder 当前目录，请重新打开菜单后再试。")
            return
        }

        guard let appURL = tool.bundleIdentifiers
            .compactMap({ NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
            .first else {
            showAlert(title: "打开 \(tool.displayName) 失败", message: "未找到 \(tool.displayName)，请确认应用已安装。")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [targetDirectory],
            withApplicationAt: appURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.showAlert(
                    title: "打开 \(tool.displayName) 失败",
                    message: "\(targetDirectory.path)\n\(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - 工具方法

    private func currentTargetDirectory() -> URL? {
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []

        if let first = selectedURLs.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir) {
                return existingDirectory(isDir.boolValue ? first : first.deletingLastPathComponent())
            }
        }

        guard let targetedURL = FIFinderSyncController.default().targetedURL() else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetedURL.path, isDirectory: &isDirectory) else {
            return nil
        }
        return existingDirectory(isDirectory.boolValue ? targetedURL : targetedURL.deletingLastPathComponent())
    }

    private func resolvedDeveloperToolTargetDirectory() -> URL? {
        if let cached = developerToolTargetDirectory,
           let directory = existingDirectory(cached) {
            return directory
        }
        return currentTargetDirectory()
    }

    private func existingDirectory(_ url: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return url.standardizedFileURL
    }

    private func uniqueFileURL(
        in directory: URL,
        baseName: String,
        fileExtension: String
    ) -> URL {
        let firstURL = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        guard FileManager.default.fileExists(atPath: firstURL.path) else {
            return firstURL
        }

        var index = 2
        while true {
            let candidate = directory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func newFileExtension(from menuItem: NSMenuItem) -> String? {
        if let ext = menuItem.representedObject as? String {
            return ext
        }
        let types = ExtensionSettings.newFileTypes
        guard types.indices.contains(menuItem.tag) else {
            return nil
        }
        return types[menuItem.tag]
    }

    private func createEmptyFile(at url: URL) throws {
        let data = Data()
        if FileManager.default.createFile(atPath: url.path, contents: data) {
            return
        }

        try data.write(to: url, options: .atomic)
    }

    private func createFileWithFinderAppleScript(
        at fileURL: URL,
        targetDirectory: URL,
        originalError: Error
    ) {
        let script = """
        tell application "Finder"
            set targetFolder to POSIX file "\(appleScriptEscaped(targetDirectory.path))" as alias
            make new file at targetFolder with properties {name:"\(appleScriptEscaped(fileURL.lastPathComponent))"}
        end tell
        """

        var scriptError: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&scriptError)
        }

        if scriptError == nil, FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            sendNotification(title: "新建文件", body: fileURL.lastPathComponent)
            return
        }

        let message = scriptError?[NSAppleScript.errorMessage] as? String
            ?? originalError.localizedDescription
        showCopyableDialog(
            title: "新建文件失败",
            message: "无法在 \(targetDirectory.path) 下新建文件：\n\(message)"
        )
    }

    private func openTerminalWithAppleScript(at directory: URL, fallbackError: Error) {
        let command = "cd " + shellQuotedPath(directory.path)
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscaped(command))"
        end tell
        """

        var scriptError: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&scriptError)
        }

        if let scriptError {
            let message = scriptError[NSAppleScript.errorMessage] as? String
                ?? fallbackError.localizedDescription
            showAlert(title: "打开终端失败", message: message)
        }
    }

    private func shellQuotedPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }

    private func showCopyableDialog(title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = title
            alert.alertStyle = .informational
            alert.addButton(withTitle: "复制")
            alert.addButton(withTitle: "关闭")

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.borderType = .bezelBorder

            let textView = NSTextView(frame: scrollView.bounds)
            textView.isEditable = false
            textView.isSelectable = true
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.string = message
            textView.textContainerInset = NSSize(width: 8, height: 8)
            textView.autoresizingMask = [.width, .height]
            textView.isHorizontallyResizable = false
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainer?.widthTracksTextView = true

            scrollView.documentView = textView
            alert.accessoryView = scrollView

            if alert.runModal() == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
    }
}
