# WP — Live Wallpaper

[![Donate](https://img.shields.io/badge/Donate-Sociabuzz-orange?style=for-the-badge&logo=buymeacoffee&logoColor=white)](https://sociabuzz.com/zerobyte/tribe)

Play videos as your desktop background. macOS, Windows, Linux.

YouTube, Spotify, or any video file. Runs behind your icons, uses barely any resources.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Xznder1984/WP-Downloader/main/install.sh | bash
```

Or clone and install manually:

```bash
git clone https://github.com/Xznder1984/WP-Downloader.git
cd WP-Downloader
python3 install.py
```

**Requirements:** Python 3.10+, yt-dlp, ffmpeg, mpv (Linux/Windows). The installer handles most of this.

## Usage

```bash
wp                          # open the TUI
wp youtube <url>            # download + set YouTube video
wp spotify <query>          # download from Spotify
wp url <url>                # download from any site (Vimeo, TikTok, Reddit...)
wp set                      # pick a local file
wp stop                     # stop the wallpaper
wp play / wp pause          # control playback
wp audio on/off             # toggle audio
wp audio 50                 # set volume
wp autostart on/off         # start wallpaper on login
wp autopause on/off         # pause when watching videos
wp backup / wp backup diff  # save/compare config backups
wp status                   # show what's running
wp cache                    # list downloaded files
wp cache clear              # free up space
wp download-dir ~/Videos    # change where files go
wp theme list               # show available themes
wp doctor                   # check if everything's installed
wp update                   # check for updates
```

## How it works

```
wp (CLI)  ──socket──▶  livewallpaper (daemon)  ──▶  video plays on desktop
```

The daemon is a background process. `wp` talks to it over a Unix socket (macOS/Linux) or TCP (Windows). On macOS it's a native Swift app using AVPlayer. On Linux/Windows it uses mpv.

## Config

All settings live in `~/.config/livewallpaper/config.json` (macOS/Linux) or `%LOCALAPPDATA%/LiveWallpaper/config.json` (Windows).

```json
{
  "enabled": true,
  "currentVideo": "my_video.mp4",
  "audioEnabled": true,
  "volume": 0.7,
  "fillMode": "aspectFill",
  "displayMode": "all",
  "downloadDir": "/Users/you/Videos/Wallpapers",
  "autoUpdate": true
}
```

Edit this file directly or use `wp` commands. Your config survives updates since it's outside the repo.

### Customizing the engine

The engine files are in `Sources/`. If you want to change how videos are rendered, how windows behave, or add new features — edit them directly.

- `Sources/WallpaperEngine.swift` — macOS video playback + window positioning
- `Sources/CommandHandler.swift` — all IPC commands
- `Sources/Config.swift` — config schema
- `Sources/engine_linux.py` — Linux engine (mpv)
- `Sources/engine_win.py` — Windows engine (mpv + ctypes)

After editing Swift files, rebuild: `make` (macOS) or `swiftc -O -o Build/livewallpaper Sources/*.swift`

Python engines don't need building. Just restart the daemon: `wp restart`

## Theming

Customize `wp`'s colors and appearance:

```bash
wp theme list          # show available themes
wp theme set dracula   # apply a theme
wp theme show nord     # preview a theme's colors
wp theme create myname # create a custom theme
wp theme edit          # open current theme in $EDITOR
wp theme validate      # check theme file for errors (auto-fixes issues)
wp theme reset         # back to default
```

Built-in themes: `default`, `dracula`, `nord`, `monokai`, `solarized`, `gruvbox`, `catppuccin`, `tokyo-night`.

Custom themes live in `~/.config/livewallpaper/themes/` and use the same JSON format. Run `wp theme validate` after editing — it catches invalid ANSI codes, clamps out-of-range values, removes unknown keys, and fills in missing fields.

## Updating

```bash
wp update        # check if new version available
wp update auto   # pull from GitHub and reinstall
wp config auto-update off   # disable auto-update check
wp config auto-update on    # re-enable it
```

Your config in `~/.config/` is never touched by updates. Videos, settings, download directory — all preserved.

## License

MIT
