/*
 For:            Kitty terminal emulator, https://sw.kovidgoyal.net/kitty/
 Author:         https://github.com/5hubham5ingh
 Version:        0.0.2
 Prerequisite:   For this script to work, enable remote control in the kitty terminal.
                 To enable remote control, start kitty with allow_remote_control=yes.
                 Ex:- kitty allow_remote_control=yes
 */

export function getDarkThemeConf(colors) {
  const theme = generateTheme(colors, true);
  return generateThemeConfig(theme);
}

export function getLightThemeConf(colors) {
  const theme = generateTheme(colors, false);
  return generateThemeConfig(theme);
}

export function setTheme(themeConfPath) {
  const command = "kitty";
  OS.exec([command, "cp", themeConfPath, "/home/serhii/.config/waybar/theme.css"]);
}

function generateTheme(colorCodes, isDark = true) {
  const colors = colorCodes.map((c) => Color(c));
  const pickColor = (dark) => {
    // find the dark or light most frequent color index
    const index = colors.findIndex((color) =>
      (dark ?? isDark) ? color.isDark() : color.isLight()
    );

    if (index !== -1) {
      return colors.splice(index, 1)[0];
    }

    // Fallback: when looking for a light color (foreground) in an all-dark
    // palette, return a light neutral — NOT black. The old code returned
    // Color("black") here because `isDark` was true for the whole theme,
    // which produced black-on-black foreground.
    if (!dark) {
      return Color("white");
    }

    return isDark ? Color("black") : Color("white");
  };

  const background = pickColor();

  // ── Waybar visibility guard ───────────────────────────────────────
  // When the wallpaper is very dark, the "darkest" picked color can still
  // be medium-dark (e.g. #0062b9, V≈72) and visually identical to the
  // wallpaper, making the status bar disappear. Clamp the HSV Value to 35%
  // max so the bar background is always deep enough to stand out.
  const hsv = background.toHsv();
  // tinycolor2 toHsv() returns {h: 0-360, s: 0-100, v: 0-100}
  if (hsv.v > 35) {
      background = new Color({ h: hsv.h, s: hsv.s, v: 35 });
  }

  // Ensure visibility of colors against the background color.
  for (let i = 0; i < colors.length; i++) {
    let iterations = 0;
    while (!Color.isReadable(colors[i], background) && iterations < 100) {
      colors[i] = isDark ? colors[i].saturate(1).brighten(1) : colors[i].desaturate(1).darken(1);
      iterations++;
    }
  }

  // Ensure there are atleast 8 colors remaining
  while (colors.length < 8) {
    colors.push(
      colors[Math.floor(Math.random() * colors.length)].analogous()[3],
    );
  }

  // create theme
  const theme = Object.assign(
    {
      background,
      foreground: pickColor(false),
      cursor: pickColor(),
    },
    ...selectDistinctColors(colors, 8).map((color, i) => ({
      [`color${i}`]: color,
    })),
  );

  // ── WCAG contrast safety net ──────────────────────────────────────
  // If foreground didn't come from the palette (e.g. pure white fallback)
  // it's readable but visually jarring. Derive a harmonious foreground
  // from the wallpaper's average hue, then verify contrast ≥ 4.5:1.
  const minContrast = 4.5;
  const readability = Color.readability(theme.background, theme.foreground);

  if (readability < minContrast) {
    // Average hue from the original palette so the foreground shares the
    // wallpaper's color temperature (blue-ish for night scenes, warm for
    // sunsets, etc.)
    const hsvs = colors.map((c) => c.toHsv());
    const avgH = hsvs.reduce((s, h) => s + (h.h || 0), 0) / hsvs.length;
    const avgS = hsvs.reduce((s, h) => s + (h.s || 0), 0) / hsvs.length;

    // Start with a light color at the wallpaper's hue, then brighten until
    // contrast passes.
    let fg = new Color({ h: avgH, s: Math.min(avgS * 1.5, 60), v: 85 });
    let iterations = 0;
    while (Color.readability(theme.background, fg) < minContrast && iterations < 50) {
      fg = fg.brighten(2);
      iterations++;
    }
    theme.foreground = fg;
  }

  return theme;
}

function generateThemeConfig(theme) {
  // Create a more harmonized color palette
  const config = `
@define-color foreground ${theme.foreground.toHexString()};
@define-color background ${theme.background.toHexString()};

`.trim();

  return config;
}

function selectDistinctColors(colorObjects, count) {
  // Sort colors by perceived brightness
  const sortedColors = colorObjects.sort((a, b) =>
    a.getBrightness() - b.getBrightness()
  );

  // Select colors with maximum color distance
  const selectedColors = [];
  while (selectedColors.length < count && colorObjects.length > 0) {
    // If first selection, pick from middle of brightness range
    if (selectedColors.length === 0) {
      const midIndex = Math.floor(sortedColors.length / 2);
      selectedColors.push(sortedColors[midIndex]);
      sortedColors.splice(midIndex, 1);
      continue;
    }

    // Find color with maximum distance from previously selected colors
    let maxDistanceColor = null;
    let maxDistance = -1;

    for (let i = 0; i < sortedColors.length; i++) {
      const currentColor = sortedColors[i];
      const minDistance = Math.min(
        ...selectedColors.map((selected) =>
          Color.readability(selected, currentColor)
        ),
      );

      if (minDistance > maxDistance) {
        maxDistance = minDistance;
        maxDistanceColor = currentColor;
      }
    }

    if (maxDistanceColor) {
      selectedColors.push(maxDistanceColor);
      sortedColors.splice(sortedColors.indexOf(maxDistanceColor), 1);
    } else {
      break;
    }
  }

  return selectedColors;
}
