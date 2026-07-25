#!/usr/bin/env python3
"""Cross-platform installer for Live Wallpaper."""

import os, sys, platform, shutil, subprocess, urllib.request, zipfile, json
from pathlib import Path

IS_WINDOWS = sys.platform == "win32"
IS_LINUX = sys.platform.startswith("linux")
IS_MACOS = sys.platform == "darwin"

GITHUB_URL = "https://github.com/Xznder1984/WP-Downloader"

def banner():
    print(r"""
 _                    _                    _ _____                    
| |                  | |                  | |  __ \                   
| |     ___  __ _  __| | ___ _ __    ___  | | |  | | ___  _ __   ___  
| |    / _ \/ _` |/ _` |/ _ \ '__|  / _ \ | | |  | |/ _ \| '_ \ / _ \ 
| |___|  __/ (_| | (_| |  __/ |    |  __/ | | |__| | (_) | | | |  __/ 
\_____/ \___|\__,_|\__,_|\___|_|     \___| |_____/ \___/|_| |_|\___|  

    """)

def run(cmd, capture=True, input_data=None):
    try:
        if input_data:
            return subprocess.run(cmd, shell=True, capture_output=True, input=input_data.encode())
        if capture:
            return subprocess.run(cmd, shell=True, capture_output=True, text=True)
        else:
            return subprocess.run(cmd, shell=True)
    except Exception as e:
        return subprocess.CompletedProcess(cmd, 1, "", str(e))

def check_internet():
    print("🌐 Checking internet...", end=" ", flush=True)
    try:
        urllib.request.urlopen("https://www.google.com", timeout=5)
        print("Connected")
        return True
    except Exception:
        print("No internet!")
        print("⚠️  Internet is required for installation.")
        return False

def check_python():
    print(f"🐍 Python {sys.version.split()[0]}... ", end=" ", flush=True)
    if sys.version_info >= (3, 10):
        print("OK")
        return True
    print("Need 3.10+")
    return False

def install_system_deps():
    print("📦 Installing system dependencies...")
    if IS_MACOS:
        if shutil.which("brew"):
            for pkg in ["yt-dlp", "mpv", "spotdl", "ffmpeg"]:
                print(f"  → brew install {pkg} (skip if exists)")
                subprocess.run(["brew", "install", pkg], capture_output=True)
        else:
            print("  Installing Homebrew...")
            run('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"', capture=False)
            for pkg in ["yt-dlp", "mpv", "spotdl", "ffmpeg"]:
                subprocess.run(["brew", "install", pkg], capture_output=True)
    elif IS_LINUX:
        print("  → sudo apt update")
        run("sudo apt update", capture=False)
        print("  → sudo apt install -y yt-dlp ffmpeg python3-tk mpv python3-pip")
        run("sudo apt install -y yt-dlp ffmpeg python3-tk mpv python3-pip", capture=False)
    elif IS_WINDOWS:
        print("  → winget install yt-dlp")
        run("winget install -e --id YT-DLP.YT-DLP", capture=False)
        print("  → winget install mpv")
        run("winget install -e --id mpv.mpv", capture=False)
    print("✅ System deps done")

def install_pip_deps():
    print("📦 Installing pip dependencies...")
    flag = "" if IS_WINDOWS else "--break-system-packages"
    run(f"{sys.executable} -m pip install {flag} --upgrade pip", capture=False)
    for pkg in ["yt-dlp", "spotdl", "psutil", "requests"]:
        print(f"  → pip install {pkg}")
        run(f"{sys.executable} -m pip install {flag} {pkg}", capture=False)
    print("✅ Pip deps done")

def build_engine():
    print("🔨 Building engine...")
    base = Path(__file__).parent
    if IS_MACOS:
        src = base / "Sources" / "main.swift"
        if src.exists():
            print("  → swiftc -O -o Build/livewallpaper Sources/*.swift")
            out = base / "Build"
            out.mkdir(exist_ok=True)
            r = run(f"swiftc -O -o {out / 'livewallpaper'} Sources/*.swift", capture=False)
            if r.returncode == 0:
                print("  ✅ macOS engine built")
            else:
                print("  ⚠️  Build failed — daemon start won't work")
        else:
            print("  ⚠️  No Swift sources found")
    else:
        print("  ✅ No build needed (Python engine)")

def copy_files():
    print("📂 Copying wp CLI...")
    wp_src = Path(__file__).parent / "Scripts" / "wp"
    wp_dst = Path.home() / ".local" / "bin"
    wp_dst.mkdir(parents=True, exist_ok=True)
    dst = wp_dst / "wp"
    shutil.copy2(str(wp_src), str(dst))
    os.chmod(str(dst), 0o755)
    print(f"  → {dst}")
    if IS_MACOS:
        daemon_src = Path(__file__).parent / "Build" / "livewallpaper"
        if daemon_src.exists():
            daemon_dst = wp_dst / "livewallpaper"
            shutil.copy2(str(daemon_src), str(daemon_dst))
            os.chmod(str(daemon_dst), 0o755)
            print(f"  → {daemon_dst}")
        print("\n✅ Installed! Restart your terminal.")
    else:
        print(f"\n✅ Installed! Add {wp_dst} to your PATH if needed:")
        print(f"  export PATH=\"{wp_dst}:$PATH\"")

def uninstall():
    print("🗑️  Uninstalling...")
    wp = Path.home() / ".local" / "bin" / "wp"
    if wp.exists():
        wp.unlink()
        print(f"  Removed {wp}")
    if IS_MACOS:
        cfg = Path.home() / ".config" / "livewallpaper"
        if cfg.exists():
            shutil.rmtree(cfg)
            print(f"  Removed {cfg}")
    print("✅ Uninstalled")

def upgrade():
    print("⬆️  Upgrading (config preserved)...\n")
    install_pip_deps()
    build_engine()
    copy_files()
    print("\n✅ Upgraded! Config in ~/.config/livewallpaper/ unchanged.")
    print("   Restart your terminal or run: wp restart")

def main():
    if "--uninstall" in sys.argv:
        uninstall()
        return

    if "--upgrade" in sys.argv:
        upgrade()
        return

    if not check_internet():
        sys.exit(1)
    if not check_python():
        sys.exit(1)
    install_system_deps()
    install_pip_deps()
    build_engine()
    copy_files()

    print("\n" + "="*60)
    print("✅ Installation complete!")
    print("="*60)
    print(f"\n👉 Open a new terminal and run:")
    print(f"   wp              # launch TUI")
    print(f"   wp set URL      # set wallpaper directly")
    print(f"   wp doctor       # diagnose issues")
    print(f"\n👉 Donation: {GITHUB_URL}")
    print(f"\n👉 Star the repo: {GITHUB_URL}")

if __name__ == "__main__":
    main()
