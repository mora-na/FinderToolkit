import Foundation

enum ExtensionSettings {

    private static let suiteDefaults = UserDefaults(suiteName: "group.com.pandkided.FinderToolkit")

    private enum Key {
        static let terminalApp = "terminal_app"
        static let newFileTypes = "new_file_types"
        static let hashAlgorithms = "hash_algorithms"
        static let developerTools = "developer_tools"
    }

    static var useITerm2: Bool {
        settings.terminalApp == "iterm2"
    }

    static let defaultNewFileTypes = ["txt", "docx", "xlsx", "pptx", "md", "csv"]

    static var newFileTypes: [String] {
        settings.newFileTypes
    }

    // MARK: - Hash Algorithms

    static let allHashAlgorithms = ToolkitSettingsPayload.allHashAlgorithms
    static let defaultHashAlgorithms = ToolkitSettingsPayload.defaultHashAlgorithms

    static var enabledHashAlgorithms: [String] {
        settings.hashAlgorithms
    }

    static var enabledDeveloperTools: [DeveloperTool] {
        settings.developerTools.compactMap(DeveloperTool.tool(withIdentifier:))
    }

    private static var settings: ToolkitSettingsPayload {
        let payload = ToolkitSettingsStore.load()
        if payload.updatedAt.timeIntervalSince1970 > 0 {
            return payload
        }

        return ToolkitSettingsPayload(
            terminalApp: suiteDefaults?.string(forKey: Key.terminalApp) ?? "terminal",
            newFileTypes: suiteDefaults?.stringArray(forKey: Key.newFileTypes) ?? defaultNewFileTypes,
            hashAlgorithms: suiteDefaults?.stringArray(forKey: Key.hashAlgorithms) ?? defaultHashAlgorithms,
            developerTools: suiteDefaults?.stringArray(forKey: Key.developerTools)
                ?? ToolkitSettingsPayload.defaultDeveloperTools,
            updatedAt: Date(timeIntervalSince1970: 0)
        ).normalized
    }
}
