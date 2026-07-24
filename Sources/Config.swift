import Foundation

struct WallpaperConfig: Codable {
    var enabled: Bool
    var currentVideo: String?
    var audioEnabled: Bool
    var volume: Double
    var fillMode: String
    var displayMode: String
    var downloadDir: String
    var autoUpdate: Bool

    static let defaultConfig = WallpaperConfig(
        enabled: false,
        currentVideo: nil,
        audioEnabled: false,
        volume: 0.5,
        fillMode: "aspectFill",
        displayMode: "all",
        downloadDir: NSHomeDirectory() + "/.config/livewallpaper/cache",
        autoUpdate: true
    )
}

class ConfigManager {
    static let shared = ConfigManager()
    var configPath: String = ""

    func ensureConfig() {
        guard !configPath.isEmpty else { return }
        if !FileManager.default.fileExists(atPath: configPath) {
            save(WallpaperConfig.defaultConfig)
        } else {
            migrateConfig()
        }
    }

    private func migrateConfig() {
        guard let data = FileManager.default.contents(atPath: configPath) else { return }
        guard var config = try? JSONDecoder().decode(WallpaperConfig.self, from: data) else { return }
        var changed = false
        if config.volume == 0.0 && !config.audioEnabled {
            config.volume = 0.5
            changed = true
        }
        if config.downloadDir.isEmpty {
            config.downloadDir = NSHomeDirectory() + "/.config/livewallpaper/cache"
            changed = true
        }
        if changed { save(config) }
    }

    func load() -> WallpaperConfig {
        guard let data = FileManager.default.contents(atPath: configPath),
            let config = try? JSONDecoder().decode(WallpaperConfig.self, from: data)
        else {
            return WallpaperConfig.defaultConfig
        }
        return config
    }

    func save(_ config: WallpaperConfig) {
        guard let data = try? JSONEncoder().encode(config),
            let pretty = try? JSONSerialization.data(
                withJSONObject: try JSONSerialization.jsonObject(with: data),
                options: [.prettyPrinted, .sortedKeys]
            )
        else {
            return
        }
        try? pretty.write(to: URL(fileURLWithPath: configPath))
    }
}
