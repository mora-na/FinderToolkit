import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    private var handledURL = false
    private var settingsWindowController: SettingsWindowController?
    private var hashWindowController: HashResultWindowController?
    private var shouldTerminateAfterHashWindowCloses = false
    private let largeHashThreshold: Int64 = 1024 * 1024 * 1024

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // 延迟显示设置窗口，等待 URL 事件处理
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.handledURL else { return }
            self.showSettings()
        }
    }

    private func showSettings() {
        shouldTerminateAfterHashWindowCloses = false
        let controller = SettingsWindowController()
        settingsWindowController = controller
        controller.showWindow(nil)
        controller.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "退出 FinderToolkit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return !handledURL
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
        shouldTerminateAfterHashWindowCloses = true
        // 关闭可能已显示的设置窗口
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        NSApp.setActivationPolicy(.accessory)
        for url in urls {
            handleURL(url)
        }
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        handledURL = true
        shouldTerminateAfterHashWindowCloses = true
        // 关闭可能已显示的设置窗口
        DispatchQueue.main.async { [weak self] in
            self?.settingsWindowController?.window?.close()
            self?.settingsWindowController = nil
        }
        NSApp.setActivationPolicy(.accessory)
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            showCopyableDialog(title: "FinderToolkit", message: "无法解析请求。")
            return
        }

        handleURL(url)
    }

    private func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            showCopyableDialog(title: "FinderToolkit", message: "无法解析请求：\(url.absoluteString)")
            return
        }

        switch components.host {
        case "hash":
            handleHash(components)
        default:
            showCopyableDialog(title: "FinderToolkit", message: "未知操作：\(components.host ?? "")")
        }
    }

    private func handleHash(_ components: URLComponents) {
        let filePaths = (components.queryItems ?? [])
            .filter { $0.name == "file" }
            .compactMap(\.value)

        guard !filePaths.isEmpty else {
            showCopyableDialog(title: "计算hash", message: "请选择文件（不支持文件夹）。")
            return
        }

        let fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
        let totalSize = fileURLs.reduce(Int64(0)) { $0 + fileSizeInBytes($1) }
        let defaultAlgorithms = Settings.enabledHashAlgorithms
        let needsConfirmation = totalSize >= largeHashThreshold

        let controller = HashResultWindowController()
        controller.onClose = { [weak self] in
            guard let self else { return }
            self.hashWindowController = nil
            if self.shouldTerminateAfterHashWindowCloses {
                NSApp.terminate(nil)
            }
        }
        hashWindowController = controller

        let startCalculation: ([String]) -> Void = { [weak self, weak controller] algorithms in
            guard let self, let controller else { return }
            self.startHashCalculation(
                fileURLs: fileURLs,
                algorithms: algorithms,
                totalSize: totalSize,
                showsProgress: needsConfirmation,
                controller: controller
            )
        }

        if needsConfirmation {
            controller.onStart = startCalculation
            controller.onCancel = { [weak self] in
                self?.hashWindowController?.window?.close()
            }
            controller.configurePreparation(
                message: "\(fileURLs.count) 个文件，合计 \(formatByteCount(totalSize))",
                algorithms: defaultAlgorithms
            )
            controller.present()
        } else {
            controller.onCancel = { [weak controller] in
                controller?.cancelFlag.pointee = true
            }
            startCalculation(defaultAlgorithms)
        }
    }

    private func startHashCalculation(
        fileURLs: [URL],
        algorithms: [String],
        totalSize: Int64,
        showsProgress: Bool,
        controller: HashResultWindowController
    ) {
        controller.cancelFlag.pointee = false
        controller.onStart = nil
        controller.onCancel = { [weak controller] in
            controller?.cancelFlag.pointee = true
        }
        if showsProgress {
            controller.showProgress(message: "\(fileURLs.count) 个文件，合计 \(formatByteCount(totalSize))")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            var completedBytes: Int64 = 0

            for url in fileURLs {
                if controller.cancelFlag.pointee {
                    lines.append("计算已取消")
                    break
                }

                let currentSize = self.fileSizeInBytes(url)
                lines.append(url.lastPathComponent)
                lines.append("路径：\(url.path)")
                lines.append(String(repeating: "-", count: 72))

                switch HashCalculator.calculate(
                    for: url,
                    algorithms: algorithms,
                    progressHandler: { progress in
                        guard showsProgress else { return }
                        let currentBytes = Int64(Double(currentSize) * progress)
                        let totalProgress = totalSize > 0
                            ? Double(completedBytes + currentBytes) / Double(totalSize)
                            : 1
                        controller.updateProgress(totalProgress)
                    },
                    isCancelled: controller.cancelFlag
                ) {
                case .success(let result):
                    if algorithms.contains("CRC32") { lines.append("CRC32  : \(result.crc32)") }
                    if algorithms.contains("CRC32C") { lines.append("CRC32C : \(result.crc32c)") }
                    if algorithms.contains("MD5") { lines.append("MD5    : \(result.md5)") }
                    if algorithms.contains("SHA1") { lines.append("SHA1   : \(result.sha1)") }
                    if algorithms.contains("SHA224") { lines.append("SHA224 : \(result.sha224)") }
                    if algorithms.contains("SHA256") { lines.append("SHA256 : \(result.sha256)") }
                    if algorithms.contains("SHA384") { lines.append("SHA384 : \(result.sha384)") }
                    if algorithms.contains("SHA512") { lines.append("SHA512 : \(result.sha512)") }
                case .failure(let error):
                    lines.append("计算失败：\(error.localizedDescription)")
                }

                completedBytes += currentSize
                lines.append("")
            }

            let result = lines.joined(separator: "\n")
            DispatchQueue.main.async {
                if controller.cancelFlag.pointee {
                    controller.showFailure(result.isEmpty ? "计算已取消" : result)
                } else {
                    controller.showResult(result)
                }
            }
        }
    }

    private func fileSizeInBytes(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func showCopyableDialog(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.alertStyle = .informational
        alert.addButton(withTitle: "复制")
        alert.addButton(withTitle: "关闭")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 420))
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
            width: scrollView.bounds.width,
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
