import AppKit
import AVFoundation
import Foundation

class WallpaperEngine {
    let screen: NSScreen
    let videoPath: String
    var window: NSWindow?
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var isPlaying = false

    private var audioEnabled: Bool
    private var volume: Double

    init(screen: NSScreen, videoPath: String, audioEnabled: Bool = false, volume: Double = 0.5) {
        self.screen = screen
        self.videoPath = videoPath
        self.audioEnabled = audioEnabled
        self.volume = volume
    }

    func start() {
        guard let videoURL = resolveVideoURL() else {
            Logger.shared.log("Failed to resolve video path: \(videoPath)")
            return
        }

        createWindow()
        setupPlayer(url: videoURL)
        isPlaying = true
        Logger.shared.log(
            "Engine started on screen \(screen.localizedName): audio=\(audioEnabled) vol=\(volume)"
        )
    }

    func stop() {
        isPlaying = false
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        window?.orderOut(nil)
        window = nil
        player = nil
        playerLayer = nil
    }

    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
    }

    func setAudio(_ enabled: Bool, volume: Double) {
        self.audioEnabled = enabled
        self.volume = volume
        let vol = enabled ? Float(volume) : 0.0
        player?.volume = vol
        Logger.shared.log("Audio updated: enabled=\(enabled) volume=\(volume)")
    }

    func setVolume(_ volume: Double) {
        self.volume = volume
        if audioEnabled {
            player?.volume = Float(volume)
        }
    }

    private func resolveVideoURL() -> URL? {
        if videoPath.hasPrefix("/") {
            let url = URL(fileURLWithPath: videoPath)
            return FileManager.default.fileExists(atPath: videoPath) ? url : nil
        }

        let cacheDir = NSHomeDirectory() + "/.config/livewallpaper/cache"
        let cached = (cacheDir as NSString).appendingPathComponent(videoPath)
        if FileManager.default.fileExists(atPath: cached) {
            return URL(fileURLWithPath: cached)
        }

        return URL(fileURLWithPath: videoPath)
    }

    private func createWindow() {
        let frame = screen.frame

        window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        guard let window = window else { return }

        window.level = NSWindow.Level(rawValue: -2147483623)
        window.backgroundColor = .black
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false

        let contentView = NSView(frame: frame)
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
    }

    private func setupPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        player = AVPlayer(playerItem: playerItem)
        player?.preventsDisplaySleepDuringVideoPlayback = false
        player?.allowsExternalPlayback = false
        player?.volume = audioEnabled ? Float(volume) : 0.0
        player?.currentItem?.preferredForwardBufferDuration = 5.0

        guard let player = player, let contentView = window?.contentView else { return }

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = contentView.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.contentsGravity = .resizeAspect
        playerLayer?.needsDisplayOnBoundsChange = true

        if let layer = contentView.layer {
            layer.addSublayer(playerLayer!)
        } else {
            contentView.wantsLayer = true
            contentView.layer?.addSublayer(playerLayer!)
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("AVPlayerItemDidPlayToEndNotification"),
            object: player.currentItem,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }

        player.play()
    }
}
