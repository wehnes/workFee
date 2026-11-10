import Foundation

public final class SettingsStore {
    public let url: URL
    private var preserveOriginal = false

    public init(directory: URL) {
        url = directory.appendingPathComponent("settings.json")
    }

    public func load() -> (Preferences, String?) {
        guard FileManager.default.fileExists(atPath: url.path) else { return (Preferences(), nil) }
        do {
            let settings = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url))
            if let error = settings.validationError {
                throw NSError(domain: "WorkFee.Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            return (settings, nil)
        } catch {
            preserveOriginal = true
            return (Preferences(), "配置读取失败，当前使用默认设置。原文件将在重新保存时备份。\n\(error.localizedDescription)")
        }
    }

    public func save(_ settings: Preferences) throws {
        if let error = settings.validationError {
            throw NSError(domain: "WorkFee.Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        if preserveOriginal && FileManager.default.fileExists(atPath: url.path) {
            let backup = directory.appendingPathComponent("settings-unreadable-\(UUID().uuidString).json.bak")
            try FileManager.default.copyItem(at: url, to: backup)
            preserveOriginal = false
        }
        try data.write(to: url, options: .atomic)
    }
}
