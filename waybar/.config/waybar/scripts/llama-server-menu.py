#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import time
import signal
import urllib.request

os.environ.setdefault("QT_QPA_PLATFORM", "wayland")

from PySide6.QtWidgets import QApplication, QMenu
from PySide6.QtCore import QPoint
from PySide6.QtGui import QAction

CONFIG_FILE = os.environ.get(
    "LLAMA_SERVER_CONFIG",
    os.path.expanduser("~/.config/waybar/scripts/llama-server-config.json"),
)

BG = "#0f0f0f"
FG = "#b37373"
FG_DIM = "#5a3a3a"
HL = "#2a1a1a"
SEP = "#3a2a2a"

IC_START = "\uf04b"
IC_STOP = "\uf04d"
IC_RESTART = "\uf021"
IC_LOGS = "\uf022"
IC_CONFIG = "\uf013"
IC_RUNNING = "\uf111"
IC_OFFLINE = "\uf011"


def load_config():
    with open(CONFIG_FILE) as f:
        return json.load(f)


def get_cursor_pos():
    try:
        r = subprocess.run(
            ["hyprctl", "cursorpos"], capture_output=True, text=True, timeout=1
        )
        x, y = r.stdout.strip().split(", ")
        return int(x), int(y)
    except Exception:
        return 100, 100


def is_server_running(config):
    try:
        host = config.get("host", "127.0.0.1")
        port = config.get("port", 8080)
        urllib.request.urlopen(f"http://{host}:{port}/health", timeout=1)
        return True
    except Exception:
        return False


def build_start_command(config):
    parts = [config["server_path"]]
    if config.get("model_path"):
        parts += ["-m", config["model_path"]]
    parts += ["--host", config.get("host", "127.0.0.1")]
    parts += ["--port", str(config.get("port", 8080))]
    parts += ["-c", str(config.get("n_ctx", 32768))]
    if config.get("n_threads"):
        parts += ["-t", str(config["n_threads"])]
    if config.get("n_batch"):
        parts += ["-b", str(config["n_batch"])]
    if config.get("n_gpu_layers", 0) > 0:
        parts += ["--n-gpu-layers", str(config["n_gpu_layers"])]
    if config.get("n_parallel", 1) > 1:
        parts += ["-np", str(config["n_parallel"])]
    if config.get("cont_batching", False):
        parts.append("--cont-batching")
    if config.get("flash_attn", True):
        parts.append("--flash-attn")
    if config.get("mlock", False):
        parts.append("--mlock")
    if config.get("no_mmap", False):
        parts.append("--no-mmap")
    if config.get("cache_type_key"):
        parts += ["-ctk", config["cache_type_key"]]
    if config.get("cache_type_value"):
        parts += ["-ctv", config["cache_type_value"]]
    if config.get("extra_args"):
        parts += config["extra_args"].split()
    return parts


def start_server(config):
    cmd = build_start_command(config)
    log_file = config.get("log_file", "/tmp/llama-server.log")
    pid_file = config.get("pid_file", "/tmp/llama-server.pid")
    with open(log_file, "w") as log, open(os.devnull, "w") as devnull:
        proc = subprocess.Popen(
            cmd,
            stdout=log,
            stderr=subprocess.STDOUT,
            stdin=devnull,
            start_new_session=True,
        )
    with open(pid_file, "w") as f:
        f.write(str(proc.pid))
    notify("llama-server", f"Started (PID {proc.pid})")


def stop_server(config):
    pid_file = config.get("pid_file", "/tmp/llama-server.pid")
    pid = None
    if os.path.exists(pid_file):
        with open(pid_file) as f:
            pid = f.read().strip()
        try:
            os.remove(pid_file)
        except OSError:
            pass
    if pid:
        try:
            os.kill(int(pid), signal.SIGTERM)
            notify("llama-server", "Stopped")
            return
        except ProcessLookupError:
            pass
        except Exception:
            pass
    subprocess.run(["pkill", "-SIGTERM", "-f", "llama-server"], capture_output=True)
    notify("llama-server", "Stopped")


def restart_server(config):
    stop_server(config)
    time.sleep(1)
    start_server(config)


def notify(title, body):
    try:
        subprocess.run(["notify-send", title, body], capture_output=True, timeout=2)
    except Exception:
        pass


def menu_stylesheet():
    return f"""
        QMenu {{
            background-color: {BG};
            color: {FG};
            font-family: 'JetBrainsMonoNerdFontMono';
            font-size: 12px;
            border: 1px solid {SEP};
            border-radius: 4px;
            padding: 6px;
            min-width: 160px;
        }}
        QMenu::item {{
            padding: 6px 32px 6px 16px;
            border-radius: 2px;
        }}
        QMenu::item:selected {{
            background-color: {HL};
            color: {FG};
        }}
        QMenu::item:disabled {{
            color: {FG_DIM};
        }}
        QMenu::separator {{
            height: 1px;
            background: {SEP};
            margin: 4px 8px;
        }}
    """


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("llama-menu")

    config = load_config()
    running = is_server_running(config)

    menu = QMenu()
    menu.setStyleSheet(menu_stylesheet())

    start_act = None
    stop_act = None
    restart_act = None

    if running:
        status_label = f"  {IC_RUNNING} Running"
        restart_act = menu.addAction(f"  {IC_RESTART} Restart")
        stop_act = menu.addAction(f"  {IC_STOP} Stop")
    else:
        status_label = f"  {IC_OFFLINE} Offline"
        start_act = menu.addAction(f"  {IC_START} Start")

    status_item = menu.addAction(status_label)
    status_item.setEnabled(False)

    menu.addSeparator()
    logs_act = menu.addAction(f"  {IC_LOGS} View Logs")
    config_act = menu.addAction(f"  {IC_CONFIG} Edit Config")

    x, y = get_cursor_pos()

    point = QPoint(x - 80, y + 4)

    chosen = menu.exec(point)

    if chosen is None:
        return

    if chosen == start_act:
        start_server(config)
    elif chosen == restart_act:
        restart_server(config)
    elif chosen == stop_act:
        stop_server(config)
    elif chosen == logs_act:
        log_file = config.get("log_file", "/tmp/llama-server.log")
        subprocess.Popen(
            ["kitty", "-e", "tail", "-f", log_file],
            start_new_session=True,
        )
    elif chosen == config_act:
        editor = os.environ.get("EDITOR", "nvim")
        subprocess.Popen(
            ["kitty", "-e", editor, CONFIG_FILE],
            start_new_session=True,
        )


if __name__ == "__main__":
    main()
