#!/usr/bin/env bash
set -euo pipefail

# curl -fsSL https://raw.githubusercontent.com/Xznder1984/WP-Downloader/main/install.sh | bash

REPO_URL="https://github.com/Xznder1984/WP-Downloader"
INSTALL_DIR="$HOME/.local/share/livewallpaper"

echo ""
echo "  _                    _                    _ _____                    "
echo " | |                  | |                  | |  __ \                   "
echo " | |     ___  __ _  __| | ___ _ __    ___  | | |  | | ___  _ __   ___ "
echo " | |    / _ \\/ _\` |/ _\` |/ _ \\\`__|  / _ \ | | |  | |/ _ \\\`_ \ / _ \\"
echo " | |___|  __/ (_| | (_| |  __/ |    |  __/ | | |__| | (_) | | | |  __/"
echo " \_____/ \___|\__,_|\__,_|\___|_|     \___| |_____/ \___/|_| |_|\___|"
echo ""
echo "    Native live wallpaper for macOS, Windows & Linux"
echo ""

mkdir -p "$INSTALL_DIR"
echo "📦 Downloading..."
cd "$INSTALL_DIR"
curl -fsSL "$REPO_URL/archive/main.zip" -o wp.zip
unzip -qo wp.zip
rm -f wp.zip
mv WP-Downloader-main/* . 2>/dev/null || true
rm -rf WP-Downloader-main

python3 install.py

echo ""
echo "Done! Restart your terminal and run: wp"
