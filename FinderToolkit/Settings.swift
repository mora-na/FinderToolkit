import Foundation

enum Settings {

    static let appGroupIdentifier = ToolkitSettingsStore.appGroupIdentifier
    private static let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier)
    private static let standardDefaults = UserDefaults.standard

    private enum Key {
        static let terminalApp = "terminal_app"
        static let newFileTypes = "new_file_types"
        static let hashAlgorithms = "hash_algorithms"
        static let settingsVersion = "settings_version"
        static let updatedAt = "settings_updated_at"
    }

    static var isSharedStoreAvailable: Bool {
        suiteDefaults != nil
    }

    // MARK: - Terminal

    enum TerminalApp: String {
        case terminal = "terminal"
        case iterm2 = "iterm2"

        var displayName: String {
            switch self {
            case .terminal: return "系统终端 (Terminal.app)"
            case .iterm2: return "iTerm2"
            }
        }
    }

    static var terminalApp: TerminalApp {
        get {
            let stored = ToolkitSettingsStore.load()
            guard let value = TerminalApp(rawValue: stored.terminalApp) else {
                return .terminal
            }
            return value
        }
        set {
            save(terminalApp: newValue, newFileTypes: newFileTypes, enabledHashAlgorithms: enabledHashAlgorithms)
        }
    }

    static var fallbackTerminalApp: TerminalApp {
        get {
            guard let raw = string(forKey: Key.terminalApp),
                  let value = TerminalApp(rawValue: raw) else {
                return .terminal
            }
            return value
        }
        set {
            set(newValue.rawValue, forKey: Key.terminalApp)
        }
    }

    // MARK: - New File Types

    static let defaultNewFileTypes = ["txt", "docx", "xlsx", "pptx", "md", "csv"]

    static var newFileTypes: [String] {
        get {
            ToolkitSettingsStore.load().newFileTypes
        }
        set {
            save(terminalApp: terminalApp, newFileTypes: newValue, enabledHashAlgorithms: enabledHashAlgorithms)
        }
    }

    // MARK: - Hash Algorithms

    static let allHashAlgorithms = defaultHashAlgorithms

    static var enabledHashAlgorithms: [String] {
        get {
            ToolkitSettingsStore.load().hashAlgorithms
        }
        set {
            save(terminalApp: terminalApp, newFileTypes: newFileTypes, enabledHashAlgorithms: newValue)
        }
    }

    static var updatedAt: Date? {
        let date = ToolkitSettingsStore.load().updatedAt
        return date.timeIntervalSince1970 > 0 ? date : object(forKey: Key.updatedAt) as? Date
    }

    static func save(
        terminalApp: TerminalApp,
        newFileTypes: [String],
        enabledHashAlgorithms: [String]
    ) {
        let payload = ToolkitSettingsPayload(
            terminalApp: terminalApp.rawValue,
            newFileTypes: normalizedFileTypes(newFileTypes),
            hashAlgorithms: normalizedHashAlgorithms(enabledHashAlgorithms),
            updatedAt: Date()
        )
        do {
            try ToolkitSettingsStore.save(payload)
        } catch {
            NSLog("FinderToolkit could not persist shared settings file: %@", error.localizedDescription)
        }

        set(terminalApp.rawValue, forKey: Key.terminalApp)
        set(payload.newFileTypes, forKey: Key.newFileTypes)
        set(payload.hashAlgorithms, forKey: Key.hashAlgorithms)
        set(1, forKey: Key.settingsVersion)
        set(payload.updatedAt, forKey: Key.updatedAt)
        synchronize()
    }

    // MARK: - Helpers

    static func resetAll() {
        [Key.terminalApp, Key.newFileTypes, Key.hashAlgorithms, Key.settingsVersion, Key.updatedAt].forEach {
            suiteDefaults?.removeObject(forKey: $0)
            standardDefaults.removeObject(forKey: $0)
        }
        try? FileManager.default.removeItem(at: ToolkitSettingsStore.userSettingsURL)
        if let appGroupURL = ToolkitSettingsStore.appGroupSettingsURL {
            try? FileManager.default.removeItem(at: appGroupURL)
        }
        synchronize()
    }

    static func normalizedFileTypes(_ values: [String]) -> [String] {
        ToolkitSettingsPayload.normalizedFileTypes(values)
    }

    static func normalizedHashAlgorithms(_ values: [String]) -> [String] {
        ToolkitSettingsPayload.normalizedHashAlgorithms(values)
    }

    private static func string(forKey key: String) -> String? {
        suiteDefaults?.string(forKey: key) ?? standardDefaults.string(forKey: key)
    }

    private static func stringArray(forKey key: String) -> [String]? {
        suiteDefaults?.stringArray(forKey: key) ?? standardDefaults.stringArray(forKey: key)
    }

    private static func object(forKey key: String) -> Any? {
        suiteDefaults?.object(forKey: key) ?? standardDefaults.object(forKey: key)
    }

    private static func set(_ value: Any, forKey key: String) {
        suiteDefaults?.set(value, forKey: key)
        standardDefaults.set(value, forKey: key)
    }

    private static func synchronize() {
        suiteDefaults?.synchronize()
        standardDefaults.synchronize()
    }
}
