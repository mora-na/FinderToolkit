import Foundation
import Darwin

struct ToolkitSettingsPayload: Codable {
    var terminalApp: String
    var newFileTypes: [String]
    var hashAlgorithms: [String]
    var updatedAt: Date

    static let defaultNewFileTypes = ["txt", "docx", "xlsx", "pptx", "md", "csv"]
    static let allHashAlgorithms = ["CRC32", "CRC32C", "MD5", "SHA1", "SHA224", "SHA256", "SHA384", "SHA512"]

    static var defaults: ToolkitSettingsPayload {
        ToolkitSettingsPayload(
            terminalApp: "terminal",
            newFileTypes: defaultNewFileTypes,
            hashAlgorithms: allHashAlgorithms,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    var normalized: ToolkitSettingsPayload {
        ToolkitSettingsPayload(
            terminalApp: terminalApp == "iterm2" ? "iterm2" : "terminal",
            newFileTypes: Self.normalizedFileTypes(newFileTypes),
            hashAlgorithms: Self.normalizedHashAlgorithms(hashAlgorithms),
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
            .filter { !$0.isEmpty && !$0.contains("/") && !$0.contains(":") }

        let unique = normalized.reduce(into: [String]()) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }

        return unique.isEmpty ? defaultNewFileTypes : unique
    }

    static func normalizedHashAlgorithms(_ values: [String]) -> [String] {
        let allowed = Set(allHashAlgorithms)
        let unique = values.reduce(into: [String]()) { result, value in
            if allowed.contains(value), !result.contains(value) {
                result.append(value)
            }
        }
        return unique.isEmpty ? allHashAlgorithms : unique
    }
}

enum ToolkitSettingsStore {
    static let appGroupIdentifier = "group.com.pandkided.FinderToolkit"
    private static let fileName = "settings.json"

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
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(ToolkitSettingsPayload.self, from: data).normalized
            } catch {
                NSLog("FinderToolkit settings load skipped %@: %@", url.path, error.localizedDescription)
            }
        }
        return .defaults
    }

    static func save(_ payload: ToolkitSettingsPayload) throws {
        let normalized = payload.normalized
        let data = try JSONEncoder().encode(normalized)
        var firstError: Error?

        for url in [userSettingsURL, appGroupSettingsURL].compactMap({ $0 }) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("FinderToolkit settings save failed %@: %@", url.path, error.localizedDescription)
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if let firstError {
            throw firstError
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

let defaultHashAlgorithms = ["CRC32", "CRC32C", "MD5", "SHA1", "SHA224", "SHA256", "SHA384", "SHA512"]
