# AGENTS.md

## Project Overview

Personal dotfiles managed by [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a Stow target that creates symlinks from `~/.config/` (or `~/etc/`) into the home directory.

**Stack:** Hyprland (Wayland), Neovim (Lua), Waybar, Kitty, Arch Linux, WallRizz theming pipeline.

## Repository Structure

```
.
├── hypr/          → ~/.config/hypr/       (Hyprland + WallRizz)
├── nvim/          → ~/.config/nvim/       (Neovim Lua config, lazy.nvim)
├── waybar/        → ~/.config/waybar/     (Waybar status bar)
├── kitty/         → ~/.config/kitty/      (Kitty terminal)
├── WallRizz/      → ~/.config/WallRizz/   (WallRizz wallpaper & theme manager)
├── tlp/           → ~/etc/tlp.d/          (TLP power profiles)
├── README.md
├── AGENTS.md
└── .git/
```

## Remotes

| Remote  | URL |
|---------|-----|
| `origin` | <https://github.com/Gribochek277/dotfiles.git> |
| `gitea`  | <http://100.110.77.11/serhii/dotfiles.git> |

Push to both with `git pushboth` (git alias → `git push --all origin && git push --all gitea`).

## Per-Target Conventions

### `hypr/` — Hyprland Window Manager

- **Entry point:** `hypr/.config/hypr/hyprland.conf` (modular — sources many sub-configs)
- **Config layout:** `config/` (variables, keybinds, window-rules, layouts, look-and-feel), `monitors.conf`/`.lua`
- **Theming:** WallRizz generates `wallrizHyprConfig.conf` and `WallRizzTheme.conf` at runtime; `WallRizzTheme.lua` defines the Lua theme. Variables live in `config/variables.conf` / `variables.lua`
- **HyprMod GUI** config at `hyprland-gui.conf` (managed by HyprMod, sourced from main conf)
- **Language:** `.conf` for Hyprland directives, `.lua` for WallRizz/theming logic
- **Key conventions:**
  - Config is split into `config/keybinds/`, `config/layouts/`, `config/look-and-feel/`, etc.
  - Monitors config is in `monitors.conf` with a Lua companion `monitors.lua`
  - Scripts live in `~/.config/hypr/scripts/` (some may not be tracked here)

### `nvim/` — Neovim Configuration

- **Entry point:** `nvim/.config/nvim/init.lua`
- **Plugin manager:** lazy.nvim (`lua/plugins/`, `lazy-lock.json`)
- **Structure:**
  - `lua/configs/` — conform, lazy, lsp, nvim-dap, nvim-dap-ui
  - `lua/plugins/` — per-plugin config modules (blink, colorscheme, fzf-lua, hop, pi, themes, vim-navigator)
  - `lua/` — mappings, options, autocmds, localized_keymaps, pi_models, theme
- **Theming:** `flow` is the fallback colorscheme; extra themes (tokyonight, catppuccin, gruvbox, rose-pine) in `lua/plugins/themes.lua` are set up but never auto-applied. `lua/theme.lua` restores the last picked theme from `stdpath("state")/nvim-theme.last` at startup (falls back to flow); `<leader>uc` opens the fzf-lua colorschemes picker.
- **Language:** Lua, formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua)
- **StyLua config:** `nvim/.config/nvim/.stylua.toml` (2-space indent, 120-col width, double quotes, no call parens)
- **Run StyLua before committing:** `stylua -c nvim/.config/nvim/.stylua.toml nvim/.config/nvim/lua/`
- **Exclude from tracking:** `nvim/.config/nvim/.opencode/` (third-party tool runtime data)
- **Key plugins:** blink.cmp (completion), nvim-dap (debugging), fzf-lua, hop, vim-navigator, custom `pi` plugin

### `waybar/` — Waybar Status Bar

- **Entry point:** `waybar/.config/waybar/config.jsonc`
- **Styling:** `style.css` + `theme.css` (WallRizz-generated theme)
- **Layout:** left (workspaces, LLM indicators), center (clock, system-update), right (tray, language, pulseaudio, backlight, cpu, power-profile, battery)
- **Scripts:** `waybar/.config/waybar/scripts/` — power-profile, llama-server-status, llama-remote-status, system-update, brightness-control, volume-control, siloctl
- **Config format:** JSONC (comments allowed)
- **Custom modules** use `exec` scripts returning JSON (`return-type: json`) with signal-based refresh

### `kitty/` — Kitty Terminal

- **Entry point:** `kitty/.config/kitty/kitty.conf`
- **Themes:** `Cherry Midnight.conf`, `Tokyo Night.conf`, `current-theme.conf` (active symlink or copy)
- **Font:** JetBrainsMono Nerd Font + Symbols Nerd Font for U+E000-U+F8FF
- **Config format:** Kitty native (line-based, colon-prefixed comments for sections)

### `WallRizz/` — Wallpaper & System Theme Manager

- **Target:** `~/.config/WallRizz/`
- **Layout:** `WallRizz/.config/WallRizz/` — wallpaper daemon handler `hyprpaper@5hubham5ingh.js` + `themeExtensionScripts/` (kitty, hyprland, waybar, pi, sddm, rofi, yazi, btop, herdr, pywal, vsCode)
- **Language:** JavaScript (ES2023, QuickJS runtime)
- **Exclude from tracking:** runtime dirs `.pi/` and `themeExtensionScripts/.opencode/` (see `WallRizz/.config/WallRizz/.gitignore`)
- **Cache:** generated themes live in `~/.cache/WallRizz/` (not tracked)
- **Generated outputs:** themes are written into other targets at runtime (e.g. `hypr/wallrizHyprConfig.conf`, `waybar/theme.css`, `kitty/current-theme.conf`) — tracked but regenerated on every wallpaper change

### `tlp/` — Power Management

- **Target:** `~/etc/tlp.d/` (not `~/.config/`)
- **Config:** `tlp/etc/tlp.d/10-power-profiles.conf`

## General Rules

1. **GNU Stow layout:** every tracked directory is a Stow target. Symlinks point from `~/.config/<app>` or `~/etc/<dir>` into this repo. Never commit files directly into `~/.config/` — commit them into the Stow target directories.
2. **No .gitignore needed for Stow:** the Stow directory structure *is* the config structure. Track only config files, not runtime/generated files.
3. **Push to both remotes:** always use `git pushboth` or explicitly push to both `origin` and `gitea`.
4. **WallRizz-generated files** (e.g., `theme.css`, `wallrizHyprConfig.conf`, `current-theme.conf`) are tracked but regenerated at runtime. Edits to them may be overwritten by WallRizz.
5. **Avoid absolute paths** in config files where possible — use `$HOME`, `~`, or relative paths. Hardcoded paths like `/home/serhii/` should be flagged for review.

## Useful Commands

```bash
# Stow all targets
cd ~/.dotfiles && stow .

# Stow individual target
stow hypr

# Restow (re-deploy symlinks)
stow -R hypr && stow hypr

# Unstow (remove symlinks)
stow -D nvim

# Lint Neovim Lua
stylua -c nvim/.config/nvim/.stylua.toml nvim/.config/nvim/lua/ --check

# Format Neovim Lua
stylua -c nvim/.config/nvim/.stylua.toml nvim/.config/nvim/lua/

# Push to both remotes
git pushboth

# Validate Waybar config
waybar -c ~/.config/waybar/config.jsonc

# Check Hyprland config syntax
hyprctl reload
```
