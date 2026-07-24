import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var wallpaperEngines: [WallpaperEngine] = []
    var ipcServer: IPCServer?
    var commandHandler: CommandHandler?
    var configPath: String!
    var pidFilePath: String!
    var logFilePath: String!
    var socketPath: String!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configDir = NSHomeDirectory() + "/.config/livewallpaper"
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        configPath = configDir + "/config.json"
        pidFilePath = configDir + "/daemon.pid"
        logFilePath = configDir + "/daemon.log"
        socketPath = configDir + "/daemon.sock"

        try? "\(ProcessInfo.processInfo.processIdentifier)".write(
            toFile: pidFilePath, atomically: true, encoding: .utf8
        )

        Logger.shared.setup(logPath: logFilePath)
        Logger.shared.log("Daemon starting (PID \(ProcessInfo.processInfo.processIdentifier))")

        ConfigManager.shared.configPath = configPath
        ConfigManager.shared.ensureConfig()

        setupSignals()

        commandHandler = CommandHandler()
        commandHandler?.appDelegate = self

        ipcServer = IPCServer(socketPath: socketPath)
        ipcServer?.delegate = self
        ipcServer?.start()

        let config = ConfigManager.shared.load()

        if config.enabled, let videoPath = config.currentVideo, !videoPath.isEmpty {
            startWallpaper(videoPath: videoPath)
        } else {
            Logger.shared.log("No video configured, waiting for commands")
        }
    }

    func setupSignals() {
        signal(SIGTERM) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .daemonStop, object: nil)
            }
        }
        signal(SIGINT) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .daemonStop, object: nil)
            }
        }
        signal(SIGHUP) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .daemonReload, object: nil)
            }
        }
        signal(SIGUSR1) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .daemonPlay, object: nil)
            }
        }
        signal(SIGUSR2) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .daemonPause, object: nil)
            }
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleStop), name: .daemonStop, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleReload), name: .daemonReload, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePlay), name: .daemonPlay, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePause), name: .daemonPause, object: nil
        )
    }

    @objc func handleStop() {
        Logger.shared.log("Daemon stopping")
        stopAll()
        cleanup()
        NSApp.terminate(nil)
    }

    @objc func handleReload() {
        Logger.shared.log("Reloading config")
        stopAll()
        let config = ConfigManager.shared.load()
        if config.enabled, let videoPath = config.currentVideo, !videoPath.isEmpty {
            startWallpaper(videoPath: videoPath)
        }
    }

    @objc func handlePlay() {
        Logger.shared.log("Resuming playback")
        for engine in wallpaperEngines {
            engine.play()
        }
    }

    @objc func handlePause() {
        Logger.shared.log("Pausing playback")
        for engine in wallpaperEngines {
            engine.pause()
        }
    }

    func updateAudio(enabled: Bool, volume: Double) {
        Logger.shared.log("Updating audio: enabled=\(enabled) volume=\(volume)")
        for engine in wallpaperEngines {
            engine.setAudio(enabled, volume: volume)
        }
    }

    func startWallpaper(videoPath: String) {
        Logger.shared.log("Starting wallpaper: \(videoPath)")

        let config = ConfigManager.shared.load()

        for screen in NSScreen.screens {
            let engine = WallpaperEngine(
                screen: screen,
                videoPath: videoPath,
                audioEnabled: config.audioEnabled,
                volume: config.volume
            )
            engine.start()
            wallpaperEngines.append(engine)
        }

        var cfg = ConfigManager.shared.load()
        cfg.enabled = true
        cfg.currentVideo = videoPath
        ConfigManager.shared.save(cfg)
    }

    func stopAll() {
        for engine in wallpaperEngines {
            engine.stop()
        }
        wallpaperEngines.removeAll()
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stopAll()
        cleanup()
        return .terminateNow
    }
}

extension Notification.Name {
    static let daemonStop = Notification.Name("daemonStop")
    static let daemonReload = Notification.Name("daemonReload")
    static let daemonPlay = Notification.Name("daemonPlay")
    static let daemonPause = Notification.Name("daemonPause")
}

extension AppDelegate: IPCServerDelegate {
    func handleCommand(_ command: String) -> String {
        return commandHandler?.handle(command) ?? "{\"error\":\"No handler\"}"
    }
}
