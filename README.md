# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Remotes

This repository is pushed to **two** origins simultaneously:

| Remote | URL |
|--------|-----|
| `origin` | <https://github.com/Gribochek277/dotfiles.git> |
| `gitea` | <http://100.110.77.11/serhii/dotfiles.git> |

## Setup

```bash
# Clone
git clone https://github.com/Gribochek277/dotfiles.git ~/.dotfiles

# Add second remote (if not already present)
git -C ~/.dotfiles remote add gitea http://100.110.77.11/serhii/dotfiles.git

# Stow all targets (creates symlinks in ~)
cd ~/.dotfiles
stow .

# Or stow individual targets
stow hypr
stow nvim
stow waybar
stow kitty
```

## Targets

Each top-level directory is a Stow target that symlinks into `~/.config/`:

| Target | Description |
| -------- | ------------- |
| `hypr/` | Hyprland window manager + WallRizz theming |
| `nvim/` | Neovim configuration (Lua, lazy.nvim) |
| `waybar/` | Waybar status bar |
| `kitty/` | Kitty terminal emulator |
| `tlp/` | TLP power management |

## Push to Both Remotes

```bash
# Push to both origins at once
git push --all origin
git push --all gitea

# Or use a git alias / post-commit hook
```
