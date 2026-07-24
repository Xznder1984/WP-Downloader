#!/usr/bin/env python3
"""Live Wallpaper Engine — Linux (mpv-based)"""

import os, sys, json, socket, signal, subprocess, time
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "livewallpaper"
SOCKET_PATH = CONFIG_DIR / "daemon.sock"
PID_FILE = CONFIG_DIR / "daemon.pid"
LOG_FILE = CONFIG_DIR / "daemon.log"

def log(msg):
    ts = time.strftime("%Y-%m-%dT%H:%M:%S")
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass

def load_config():
    p = CONFIG_DIR / "config.json"
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception:
            pass
    return {"enabled": False, "currentVideo": None, "audioEnabled": False,
            "volume": 0.5, "fillMode": "aspectFill", "displayMode": "all",
            "downloadDir": str(CONFIG_DIR / "cache")}

def resolve_video(path):
    if os.path.isabs(path) and os.path.exists(path):
        return path
    cached = CONFIG_DIR / "cache" / path
    if cached.exists():
        return str(cached)
    return path

class WallpaperDaemon:
    def __init__(self):
        self.process = None
        self.running = True
        self.config = load_config()
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        Path(self.config.get("downloadDir", str(CONFIG_DIR / "cache"))).mkdir(parents=True, exist_ok=True)

    def start_video(self, video_path):
        self.stop_video()
        resolved = resolve_video(video_path)
        if not os.path.exists(resolved):
            log(f"Video not found: {resolved}")
            return False

        self.config = load_config()
        vol = int(self.config.get("volume", 0.5) * 100) if self.config.get("audioEnabled") else 0

        cmd = ["mpv", "--no-terminal", "--no-osc", "--no-osd-bar",
               "--no-input-default-bindings", "--loop=inf",
               "--profile=opengl-hq", "--hwdec=auto-safe",
               f"--volume={vol}", resolved]

        try:
            self.process = subprocess.Popen(
                cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                preexec_fn=os.setpgrp
            )
            log(f"Started mpv PID {self.process.pid}: {resolved}")
            return True
        except FileNotFoundError:
            log("mpv not found — install: sudo apt install mpv")
            return False
        except Exception as e:
            log(f"Failed: {e}")
            return False

    def stop_video(self):
        if self.process:
            try:
                self.process.terminate()
                self.process.wait(timeout=5)
            except Exception:
                try:
                    self.process.kill()
                except Exception:
                    pass
            self.process = None

    def handle_command(self, cmd_str):
        parts = cmd_str.split(" ", 1)
        action = parts[0] if parts else ""
        rest = parts[1] if len(parts) > 1 else ""

        if action == "set":
            if not rest:
                return '{"error":"No path"}'
            if self.start_video(rest):
                self.config["enabled"] = True
                self.config["currentVideo"] = rest
                self._save_config()
                return f'{{"status":"ok","message":"Wallpaper set"}}'
            return '{"error":"Failed to start video"}'

        elif action == "stop":
            self.stop_video()
            self.config["enabled"] = False
            self._save_config()
            return '{"status":"ok","message":"Stopped"}'

        elif action == "play":
            if self.process and self.process.poll() is None:
                self.process.send_signal(signal.SIGCONT)
            return '{"status":"ok","message":"Resumed"}'

        elif action == "pause":
            if self.process and self.process.poll() is None:
                self.process.send_signal(signal.SIGSTOP)
            return '{"status":"ok","message":"Paused"}'

        elif action == "reload":
            self.config = load_config()
            if self.config.get("enabled") and self.config.get("currentVideo"):
                self.start_video(self.config["currentVideo"])
            return '{"status":"ok","message":"Reloaded"}'

        elif action == "audio":
            tokens = rest.split()
            if not tokens:
                s = "on" if self.config.get("audioEnabled") else "off"
                return json.dumps({"status":"ok","state":s,"volume":self.config.get("volume",0.5)})
            sub = tokens[0]
            if sub in ("on","off"):
                self.config["audioEnabled"] = sub == "on"
            else:
                try:
                    v = float(sub)
                    if 0 <= v <= 100:
                        self.config["audioEnabled"] = True
                        self.config["volume"] = v / 100.0
                except ValueError:
                    pass
            self._save_config()
            return '{"status":"ok","message":"Audio updated"}'

        elif action == "volume":
            try:
                v = float(rest)
                self.config["volume"] = max(0, min(100, v)) / 100.0
                self._save_config()
                return '{"status":"ok","message":"Volume updated"}'
            except ValueError:
                return '{"error":"Invalid volume"}'

        elif action == "download-dir":
            if rest:
                p = Path(rest).expanduser().resolve()
                p.mkdir(parents=True, exist_ok=True)
                self.config["downloadDir"] = str(p)
                self._save_config()
                return json.dumps({"status":"ok","download_dir":str(p)})
            return json.dumps({"status":"ok","download_dir":self.config.get("downloadDir","")})

        elif action == "status":
            is_running = self.process is not None and self.process.poll() is None
            pid = str(self.process.pid) if is_running else "unknown"
            return json.dumps({
                "running": is_running, "pid": pid,
                "enabled": self.config.get("enabled", False),
                "current_video": self.config.get("currentVideo") or "none",
                "audio_enabled": self.config.get("audioEnabled", False),
                "volume": self.config.get("volume", 0.5),
                "fill_mode": self.config.get("fillMode", "aspectFill"),
                "display_mode": self.config.get("displayMode", "all"),
                "download_dir": self.config.get("downloadDir", ""),
                "screens": 1
            })

        elif action == "ping":
            return '{"status":"ok"}'

        return '{"error":"Unknown command"}'

    def _save_config(self):
        try:
            (CONFIG_DIR / "config.json").write_text(
                json.dumps(self.config, indent=2))
        except Exception:
            pass

    def run(self):
        signal.signal(signal.SIGTERM, lambda s, f: self.shutdown())
        signal.signal(signal.SIGINT, lambda s, f: self.shutdown())

        try:
            PID_FILE.write_text(str(os.getpid()))
        except Exception:
            pass

        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(str(SOCKET_PATH))
        server.listen(5)
        server.settimeout(1.0)

        os.chmod(str(SOCKET_PATH), 0o600)
        log(f"Daemon started PID {os.getpid()}")

        if self.config.get("enabled") and self.config.get("currentVideo"):
            self.start_video(self.config["currentVideo"])

        while self.running:
            try:
                conn, _ = server.accept()
                data = conn.recv(4096)
                if data:
                    request = json.loads(data.decode("utf-8"))
                    command = request.get("command", "")
                    response = self.handle_command(command)
                    conn.sendall(response.encode("utf-8"))
                conn.close()
            except socket.timeout:
                if self.process and self.process.poll() is not None:
                    log("mpv exited, restarting...")
                    if self.config.get("enabled") and self.config.get("currentVideo"):
                        time.sleep(1)
                        self.start_video(self.config["currentVideo"])
            except Exception as e:
                log(f"Socket error: {e}")

        self.stop_video()
        server.close()
        try:
            SOCKET_PATH.unlink()
            PID_FILE.unlink()
        except Exception:
            pass
        log("Daemon stopped")

    def shutdown(self):
        self.running = False

if __name__ == "__main__":
    daemon = WallpaperDaemon()
    daemon.run()
