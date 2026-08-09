/*
 For:            Hyprland, https://hyprland.org
 Author:         https://github.com/5hubham5ingh
 Version:        0.0.4 (Lua config port)
 Prerequisite:   Hyprland now loads `~/.config/hypr/hyprland.lua`. Make sure it
                 contains `require("WallRizzTheme")` near the bottom (replacing
                 the old `source = ~/.config/hypr/WallRizzTheme.conf` line).
*/

function createHyprlandTheme(colors, isDark = true) {
  // Validate input
  if (colors.length < 5) {
    throw new Error("At least 5 colors required for theme generation");
  }

  // Helper to calculate "distance" between colors based on luminance and hue
  const colorDistance = (color1, color2) => {
    const lDiff = color1.getLuminance() - color2.getLuminance();
    const hDiff = Math.min(
      Math.abs((color1.toHsv().h || 0) - (color2.toHsv().h || 0)),
      360 - Math.abs((color1.toHsv().h || 0) - (color2.toHsv().h || 0)),
    );
    return Math.sqrt(lDiff ** 2 + (hDiff / 360) ** 2);
  };

  // Select the most distinct colors
  const selectDistinctColors = (inputColors, targetCount) => {
    const selected = [Color(inputColors[0])];
    const remaining = inputColors.slice(1).map(Color);

    while (selected.length < targetCount && remaining.length > 0) {
      let bestCandidate = null;
      let maxMinDistance = -Infinity;

      for (const candidate of remaining) {
        const minDistance = Math.min(
          ...selected.map((existing) => colorDistance(candidate, existing)),
        );

        if (minDistance > maxMinDistance) {
          maxMinDistance = minDistance;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate) {
        selected.push(bestCandidate);
        remaining.splice(remaining.indexOf(bestCandidate), 1);
      }
    }

    return selected;
  };

  // Select five distinct colors, ensuring the count with random additions if necessary
  const distinctColors = selectDistinctColors(colors, 5);
  while (distinctColors.length < 5) {
    distinctColors.push(
      distinctColors[Math.floor(Math.random() * distinctColors.length)]
        .analogous()[5],
    );
  }

  // Map colors for theme properties
  const [
    backgroundSource,
    foregroundSource,
    activeBorder1,
    activeBorder2,
    inactiveBorder,
  ] = distinctColors;

  const adjustBrightness = (color, amount) =>
    isDark ? color.darken(amount) : color.lighten(amount);

  return {
    background: adjustBrightness(backgroundSource, 10).toHexString(),
    foreground: adjustBrightness(foregroundSource, 20).toHexString(),
    activeBorder: [
      activeBorder1.setAlpha(0.7).toHexString(),
      activeBorder2.toHexString(),
    ],
    inactiveBorder: inactiveBorder.toHexString(),
    shadow: backgroundSource.clone().setAlpha(0.4).toHex8String(),
    groupColors: {
      activeGroup: activeBorder1.toHexString(),
      inactiveGroup: activeBorder2.toHexString(),
      lockedActiveGroup: activeBorder1.darken(10).toHexString(),
      lockedInactiveGroup: activeBorder2.darken(10).toHexString(),
    },
    splash: foregroundSource.toHexString(),
  };
}
// Translate a `#RRGGBB` or `#RRGGBBAA` color from the theme object into a
// Hyprland-Lua color string literal. The literal must be quoted so that Lua
// sees it as a string; bare `rgb(402d2e)` would be parsed as a malformed
// number because it looks like hex without a `0x` prefix.
function toLuaColor(hex) {
  const s = hex.startsWith("#") ? hex.substring(1) : hex;
  return s.length === 8 ? `"rgba(${s})"` : `"rgb(${s})"`;
}
const opaqueLua = (hex) => `"rgb(${hex.replace("#", "")})"`;

function createHyprlandConfig(theme) {
  // Emit Lua that `require("WallRizzTheme")` can run via `hl.config({...})`.
  // Mirrors the previous .conf semantics 1:1, just in Lua table form
  // (matching the layout Hyprland's own example hyprland.lua uses).
  return `hl.config({
  general = {
    col = {
      active_border = {
        colors = {${toLuaColor(theme.activeBorder[0])}, ${opaqueLua(theme.activeBorder[1])}},
        angle = 45,
      },
      inactive_border = ${opaqueLua(theme.inactiveBorder)},
    },
  },
  group = {
    col = {
      border_active = ${opaqueLua(theme.groupColors.activeGroup)},
      border_inactive = ${opaqueLua(theme.groupColors.inactiveGroup)},
      border_locked_active = ${opaqueLua(theme.groupColors.lockedActiveGroup)},
      border_locked_inactive = ${opaqueLua(theme.groupColors.lockedInactiveGroup)},
    },
    groupbar = {
      text_color = ${opaqueLua(theme.foreground)},
      col = {
        active = ${opaqueLua(theme.groupColors.activeGroup)},
        inactive = ${opaqueLua(theme.groupColors.inactiveGroup)},
      },
    },
  },
  misc = {
    background_color = ${opaqueLua(theme.background)},
    col = {
      splash = ${opaqueLua(theme.splash)},
    },
  },
})`.trim();
}
const getDarkThemeConf = (colors) =>
  createHyprlandConfig(createHyprlandTheme(colors, true));

const getLightThemeConf = (colors) =>
  createHyprlandConfig(createHyprlandTheme(colors, false));

function setTheme(themeConfPath) {
  // Hyprland now loads `hyprland.lua`, which does `require("WallRizzTheme")`.
  // WallRizz has already written the Lua theme produced by `getDarkThemeConf` /
  // `getLightThemeConf` to `themeConfPath` (with a `.conf` extension, but the
  // content is valid Lua). Inline that content straight into WallRizzTheme.lua
  // (instead of `dofile(...)`) so a `hyprctl reload` re-executes the current
  // theme even though Lua's `require` caches `package.loaded`.
  const themeLuaPath = HOME_DIR.concat("/.config/hypr/WallRizzTheme.lua");
  OS.exec([
    "sh", "-c",
    `mkdir -p ~/.config/hypr && cp -f -- "${themeConfPath}" "${themeLuaPath}"`,
  ]);
  // Pick up the new theme live, without a session restart.
  OS.exec(["hyprctl", "reload"]);
}

export { getDarkThemeConf, getLightThemeConf, setTheme };
