import Foundation
import AppKit

class CommandHandler {
    weak var appDelegate: AppDelegate?

    func handle(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1)
        guard let action = parts.first else {
            return encodeError("Empty command")
        }

        let rest = parts.count > 1 ? String(parts[1]) : ""

        switch String(action) {
        case "status":
            return handleStatus()
        case "set":
            return handleSet(path: rest)
        case "stop":
            return handleStop()
        case "play":
            return handlePlay()
        case "pause":
            return handlePause()
        case "reload":
            return handleReload()
        case "audio":
            return handleAudio(args: rest)
        case "volume":
            return handleVolume(args: rest)
        case "download-dir":
            return handleDownloadDir(args: rest)
        case "ping":
            return "{\"status\":\"ok\"}"
        default:
            return encodeError("Unknown command: \(action)")
        }
    }

    private func handleStatus() -> String {
        let config = ConfigManager.shared.load()
        let pidPath = NSHomeDirectory() + "/.config/livewallpaper/daemon.pid"
        let pid = try? String(contentsOfFile: pidPath).trimmingCharacters(
            in: .whitespacesAndNewlines)

        var isRunning = false
        if let pidStr = pid, let pidNum = Int32(pidStr) {
            isRunning = kill(pidNum, 0) == 0
        }

        let status: [String: Any] = [
            "running": isRunning,
            "pid": pid ?? "unknown",
            "enabled": config.enabled,
            "current_video": config.currentVideo ?? "none",
            "audio_enabled": config.audioEnabled,
            "volume": config.volume,
            "fill_mode": config.fillMode,
            "display_mode": config.displayMode,
            "download_dir": config.downloadDir,
            "screens": NSScreen.screens.count,
        ]

        return encodeJSON(status)
    }

    private func handleSet(path: String) -> String {
        guard !path.isEmpty else {
            return encodeError("No video path provided")
        }

        let resolved: String
        if path.hasPrefix("/") {
            resolved = path
        } else {
            resolved = NSHomeDirectory() + "/.config/livewallpaper/cache/" + path
        }

        guard FileManager.default.fileExists(atPath: resolved) else {
            return encodeError("File not found: \(resolved)")
        }

        appDelegate?.stopAll()
        appDelegate?.startWallpaper(videoPath: path)

        return "{\"status\":\"ok\",\"message\":\"Wallpaper set to \(path)\"}"
    }

    private func handleStop() -> String {
        appDelegate?.stopAll()

        var config = ConfigManager.shared.load()
        config.enabled = false
        ConfigManager.shared.save(config)

        return "{\"status\":\"ok\",\"message\":\"Wallpaper stopped\"}"
    }

    private func handlePlay() -> String {
        appDelegate?.handlePlay()
        return "{\"status\":\"ok\",\"message\":\"Playback resumed\"}"
    }

    private func handlePause() -> String {
        appDelegate?.handlePause()
        return "{\"status\":\"ok\",\"message\":\"Playback paused\"}"
    }

    private func handleReload() -> String {
        appDelegate?.handleReload()
        return "{\"status\":\"ok\",\"message\":\"Config reloaded\"}"
    }

    private func handleAudio(args: String) -> String {
        let tokens = args.split(separator: " ").map { String($0) }
        guard let sub = tokens.first else {
            let config = ConfigManager.shared.load()
            let state = config.audioEnabled ? "on" : "off"
            return "{\"status\":\"ok\",\"audio_enabled\":\(config.audioEnabled),\"state\":\"\(state)\",\"volume\":\(config.volume)}"
        }

        var config = ConfigManager.shared.load()

        switch sub {
        case "on":
            config.audioEnabled = true
            ConfigManager.shared.save(config)
            appDelegate?.updateAudio(enabled: true, volume: config.volume)
            return "{\"status\":\"ok\",\"message\":\"Audio enabled at \(Int(config.volume * 100))%\"}"

        case "off":
            config.audioEnabled = false
            ConfigManager.shared.save(config)
            appDelegate?.updateAudio(enabled: false, volume: config.volume)
            return "{\"status\":\"ok\",\"message\":\"Audio disabled\"}"

        default:
            if let val = Double(sub), val >= 0, val <= 100 {
                let vol = val / 100.0
                config.audioEnabled = true
                config.volume = vol
                ConfigManager.shared.save(config)
                appDelegate?.updateAudio(enabled: true, volume: vol)
                return "{\"status\":\"ok\",\"message\":\"Volume set to \(Int(val))%\"}"
            }
            return encodeError("Usage: audio <on|off|0-100>")
        }
    }

    private func handleVolume(args: String) -> String {
        guard let val = Double(args), val >= 0, val <= 100 else {
            return encodeError("Usage: volume <0-100>")
        }

        var config = ConfigManager.shared.load()
        let vol = val / 100.0
        config.volume = vol
        ConfigManager.shared.save(config)
        appDelegate?.updateAudio(enabled: config.audioEnabled, volume: vol)
        return "{\"status\":\"ok\",\"message\":\"Volume set to \(Int(val))%\"}"
    }

    private func handleDownloadDir(args: String) -> String {
        let trimmed = args.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            let config = ConfigManager.shared.load()
            return "{\"status\":\"ok\",\"download_dir\":\"\(config.downloadDir)\"}"
        }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let dir = url.path

        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) || !isDir.boolValue {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            } catch {
                return encodeError("Cannot create directory: \(error.localizedDescription)")
            }
        }

        var config = ConfigManager.shared.load()
        config.downloadDir = dir
        ConfigManager.shared.save(config)

        return "{\"status\":\"ok\",\"message\":\"Download directory set to \(dir)\"}"
    }

    private func encodeError(_ message: String) -> String {
        "{\"error\":\"\(message)\"}"
    }

    private func encodeJSON(_ obj: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: obj, options: [.prettyPrinted]),
            let str = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"JSON encode failed\"}"
        }
        return str
    }
}
