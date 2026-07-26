import Foundation
import Darwin

struct DeveloperTool: Hashable {
    let identifier: String
    let displayName: String
    let menuTitle: String
    let bundleIdentifiers: [String]

    static let all: [DeveloperTool] = [
        DeveloperTool(
            identifier: "vscode",
            displayName: "VS Code",
            menuTitle: "在 VS Code 中打开",
            bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.visualstudio.code"]
        ),
        DeveloperTool(
            identifier: "cursor",
            displayName: "Cursor",
            menuTitle: "在 Cursor 中打开",
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"]
        ),
        DeveloperTool(
            identifier: "idea",
            displayName: "IntelliJ IDEA",
            menuTitle: "在 IntelliJ IDEA 中打开",
            bundleIdentifiers: ["com.jetbrains.intellij", "com.jetbrains.intellij.ce", "com.jetbrains.intellij-EAP"]
        ),
        DeveloperTool(
            identifier: "pycharm",
            displayName: "PyCharm",
            menuTitle: "在 PyCharm 中打开",
            bundleIdentifiers: ["com.jetbrains.pycharm", "com.jetbrains.pycharm.ce"]
        ),
        DeveloperTool(
            identifier: "webstorm",
            displayName: "WebStorm",
            menuTitle: "在 WebStorm 中打开",
            bundleIdentifiers: ["com.jetbrains.WebStorm"]
        ),
        DeveloperTool(
            identifier: "android-studio",
            displayName: "Android Studio",
            menuTitle: "在 Android Studio 中打开",
            bundleIdentifiers: ["com.google.android.studio"]
        ),
        DeveloperTool(
            identifier: "xcode",
            displayName: "Xcode",
            menuTitle: "在 Xcode 中打开",
            bundleIdentifiers: ["com.apple.dt.Xcode"]
        )
    ]

    static func tool(withIdentifier identifier: String) -> DeveloperTool? {
        all.first { $0.identifier == identifier }
    }
}

struct TerminalTool: Hashable {
    let identifier: String
    let displayName: String
    let menuTitle: String
    let bundleIdentifiers: [String]

    static let all: [TerminalTool] = [
        TerminalTool(identifier: "terminal", displayName: "Terminal", menuTitle: "在此打开Terminal", bundleIdentifiers: ["com.apple.Terminal"]),
        TerminalTool(identifier: "iterm2", displayName: "iTerm2", menuTitle: "在此打开iTerm2", bundleIdentifiers: ["com.googlecode.iterm2"]),
        TerminalTool(identifier: "ghostty", displayName: "Ghostty", menuTitle: "在此打开Ghostty", bundleIdentifiers: ["com.mitchellh.ghostty"]),
        TerminalTool(identifier: "warp", displayName: "Warp", menuTitle: "在此打开Warp", bundleIdentifiers: ["dev.warp.Warp-Stable"]),
        TerminalTool(identifier: "wezterm", displayName: "WezTerm", menuTitle: "在此打开WezTerm", bundleIdentifiers: ["org.wezfurlong.wezterm"]),
        TerminalTool(identifier: "alacritty", displayName: "Alacritty", menuTitle: "在此打开Alacritty", bundleIdentifiers: ["org.alacritty"])
    ]

    static func tool(withIdentifier identifier: String) -> TerminalTool? {
        all.first { $0.identifier == identifier }
    }
}

final class HashCancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
    }
}

struct ToolkitSettingsPayload: Codable {
    var terminalApp: String
    var terminalApps: [String]
    var newFileTypes: [String]
    var hashAlgorithms: [String]
    var developerTools: [String]
    var updatedAt: Date

    static let defaultNewFileTypes = ["txt", "docx", "xlsx", "pptx", "md", "csv"]
    static let allHashAlgorithms = ["CRC32", "CRC32C", "MD5", "SHA1", "SHA224", "SHA256", "SHA384", "SHA512", "SM3"]
    static let defaultHashAlgorithms = ["MD5", "SHA1", "SHA256"]
    static let defaultDeveloperTools = ["vscode"]
    static let defaultTerminalApps = ["terminal"]

    private enum CodingKeys: String, CodingKey {
        case terminalApp
        case terminalApps
        case newFileTypes
        case hashAlgorithms
        case developerTools
        case updatedAt
    }

    init(
        terminalApp: String,
        terminalApps: [String] = ToolkitSettingsPayload.defaultTerminalApps,
        newFileTypes: [String],
        hashAlgorithms: [String],
        developerTools: [String],
        updatedAt: Date
    ) {
        self.terminalApp = terminalApp
        self.terminalApps = terminalApps
        self.newFileTypes = newFileTypes
        self.hashAlgorithms = hashAlgorithms
        self.developerTools = developerTools
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp) ?? "terminal"
        terminalApps = try container.decodeIfPresent([String].self, forKey: .terminalApps)
            ?? [terminalApp]
        newFileTypes = try container.decodeIfPresent([String].self, forKey: .newFileTypes)
            ?? Self.defaultNewFileTypes
        hashAlgorithms = try container.decodeIfPresent([String].self, forKey: .hashAlgorithms)
            ?? Self.defaultHashAlgorithms
        developerTools = try container.decodeIfPresent([String].self, forKey: .developerTools)
            ?? Self.defaultDeveloperTools
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? Date(timeIntervalSince1970: 0)
    }

    static var defaults: ToolkitSettingsPayload {
        ToolkitSettingsPayload(
            terminalApp: "terminal",
            terminalApps: defaultTerminalApps,
            newFileTypes: defaultNewFileTypes,
            hashAlgorithms: defaultHashAlgorithms,
            developerTools: defaultDeveloperTools,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    var normalized: ToolkitSettingsPayload {
        ToolkitSettingsPayload(
            terminalApp: Self.normalizedTerminalApps(terminalApps).first ?? "terminal",
            terminalApps: Self.normalizedTerminalApps(terminalApps),
            newFileTypes: Self.normalizedFileTypes(newFileTypes),
            hashAlgorithms: Self.normalizedHashAlgorithms(hashAlgorithms),
            developerTools: Self.normalizedDeveloperTools(developerTools),
            updatedAt: updatedAt
        )
    }

    static func normalizedFileTypes(_ values: [String]) -> [String] {
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

        let bounded = Array(unique.prefix(64))
        return bounded.isEmpty ? defaultNewFileTypes : bounded
    }

    static func normalizedHashAlgorithms(_ values: [String]) -> [String] {
        let allowed = Set(allHashAlgorithms)
        let unique = values.reduce(into: [String]()) { result, value in
            if allowed.contains(value), !result.contains(value) {
                result.append(value)
            }
        }
        return unique.isEmpty ? defaultHashAlgorithms : unique
    }

    static func normalizedDeveloperTools(_ values: [String]) -> [String] {
        let enabled = Set(values)
        return DeveloperTool.all
            .map(\.identifier)
            .filter { enabled.contains($0) }
    }

    static func normalizedTerminalApps(_ values: [String]) -> [String] {
        let enabled = Set(values)
        return TerminalTool.all
            .map(\.identifier)
            .filter { enabled.contains($0) }
    }
}

enum ToolkitSettingsStore {
    private enum StoreError: LocalizedError {
        case noWritableDestination

        var errorDescription: String? {
            "没有可写入的设置目录"
        }
    }

    static let appGroupIdentifier = "group.com.pandkided.FinderToolkit"
    private static let fileName = "settings.json"
    private static let maximumSettingsFileSize = 1_048_576

    static var userSettingsURL: URL {
        URL(fileURLWithPath: realUserHomeDirectory())
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("FinderToolkit", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static var appGroupSettingsURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    static func load() -> ToolkitSettingsPayload {
        let urls = [userSettingsURL, appGroupSettingsURL].compactMap { $0 }
        var candidates: [ToolkitSettingsPayload] = []
        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (values.fileSize ?? 0) <= maximumSettingsFileSize else {
                    NSLog("FinderToolkit settings load skipped oversized file %@", url.path)
                    continue
                }
                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder().decode(ToolkitSettingsPayload.self, from: data).normalized
                candidates.append(payload)
            } catch {
                NSLog("FinderToolkit settings load skipped %@: %@", url.path, error.localizedDescription)
            }
        }
        return candidates.max { $0.updatedAt < $1.updatedAt } ?? .defaults
    }

    static func save(_ payload: ToolkitSettingsPayload) throws {
        let normalized = payload.normalized
        let data = try JSONEncoder().encode(normalized)
        var firstError: Error?
        var savedCount = 0

        for url in [userSettingsURL, appGroupSettingsURL].compactMap({ $0 }) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: [.atomic])
                savedCount += 1
            } catch {
                NSLog("FinderToolkit settings save failed %@: %@", url.path, error.localizedDescription)
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if savedCount == 0 {
            throw firstError ?? StoreError.noWritableDestination
        }
    }

    private static func realUserHomeDirectory() -> String {
        if let passwd = getpwuid(getuid()),
           let home = passwd.pointee.pw_dir {
            return String(cString: home)
        }
        return NSHomeDirectory()
    }
}

struct HashResult {
    let crc32: String
    let crc32c: String
    let md5: String
    let sha1: String
    let sha224: String
    let sha256: String
    let sha384: String
    let sha512: String
    let sm3: String
}

enum HashError: Error, LocalizedError {
    case fileNotFound
    case readFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "文件不存在"
        case .readFailed:   return "文件读取失败"
        case .cancelled:    return "已取消"
        }
    }
}

let defaultHashAlgorithms = ToolkitSettingsPayload.defaultHashAlgorithms
