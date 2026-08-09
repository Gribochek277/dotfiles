/*
 For:            hyprpaper, https://github.com/hyprwm/hyprpaper
 Author:         https://github.com/5hubham5ingh
 Prerequisite:   hyprpaper daemon should be running (normally started via
                 `exec-once = hyprpaper` / `hl.exec_cmd("hyprpaper")` in autostart).

 Why this version:
   - Old script used `pkill hyprpaper` + `hyprctl dispatch exec hyprpaper`, which is
     a race: the new process races to bind the IPC socket while the old one is
     still dying, so the new daemon often fails to start and wallpapers never
     apply until a full session reboot. Fixed by using hyprpaper's IPC
     (`hyprctl hyprpaper wallpaper ,<path>`) to hot-swap the wallpaper without
     restarting the daemon.
   - Old script also did `sudo cp` to /usr/share/backgrounds/current-wallpaper.jpg
     with no NOPASSWD rule, so it hung waiting for a password. The fixed-path
     copy now lives under ~/.local/share/backgrounds (no sudo).
*/

function setWallpaper(wallpaperPath) {
  const wp = wallpaperPath.replace(/\/{2,}/g, "/");
  const confDir = "/home/serhii/.config/hypr";
  const confPath = `${confDir}/hyprpaper.conf`;
  const fixedDir = "/home/serhii/.local/share/backgrounds";
  const fixedWallpaper = `${fixedDir}/current-wallpaper.jpg`;

  // One sh -c so the steps run strictly in order regardless of whether
  // OS.exec is sync or async.
  OS.exec([
    "sh", "-c",
    [
      "set -e",
      `mkdir -p "${confDir}" "${fixedDir}"`,
      `cat > "${confPath}" <<'HYPRPAPER_EOF'`,
      "wallpaper {",
      "  monitor =",
      `  path = ${wp}`,
      "}",
      "HYPRPAPER_EOF",
      // Best-effort fixed-path copy; never fatal.
      `cp -f -- "${wp}" "${fixedWallpaper}" 2>/dev/null || true`,
      // Make sure hyprpaper is up before asking it to swap the wallpaper.
      "if ! pgrep -x hyprpaper >/dev/null; then",
      "  nohup hyprpaper >/dev/null 2>&1 &",
      "  i=0",
      "  while [ $i -lt 25 ]; do",
      "    pgrep -x hyprpaper >/dev/null && break",
      "    sleep 0.1",
      "    i=$((i + 1))",
      "  done",
      "fi",
      // Hot-swap the wallpaper via IPC; the leading comma means "fallback
      // wallpaper for any monitor" (same semantics as `monitor =` in the conf).
      `hyprctl -q hyprpaper wallpaper ,${wp}`,
    ].join("\n"),
  ]);
}

export { setWallpaper };