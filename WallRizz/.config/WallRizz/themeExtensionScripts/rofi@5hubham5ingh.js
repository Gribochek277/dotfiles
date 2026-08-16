/*
 For:            Rofi application launcher, https://github.com/davatorium/rofi
 Author:         https://github.com/5hubham5ingh
 Version:        0.0.2
 Prerequisite:   Rofi reads the theme file on every launch, so no daemon reload
                 is needed — the next invocation picks up the new colors
                 automatically. Launch the drun launcher with the theme:
                     rofi -show drun -theme ~/.config/rofi/theme.rasi
                 (configured in Hyprland's `$menu` / `var_menu`).
                 theme.rasi is a complete theme (variables + element selectors)
                 because rofi silently falls back to its built-in solarized
                 default if a file contains only a `*` variable block. The
                 `logout-menu.rasi` and `wifi-bluetooth-menu.rasi` consumers
                 override element styles and use `@main-fg`/`@main-bg`/etc.
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
  const content = STD.loadFile(themeConfPath);
  const rofiDir = HOME_DIR.concat("/.config/rofi");
  const themePath = rofiDir.concat("/theme.rasi");

  // mkdir -p ~/.config/rofi (mkdir-walk, same pattern pywal uses for its cache dir).
  rofiDir.split("/").forEach((dir, i, path) => {
    if (!dir) return;
    const currPath = path.filter((_, j) => j <= i).join("/");
    if (!OS.stat(currPath)[0]) OS.mkdir(currPath);
  });

  const file = STD.open(themePath, "w+");
  if (!file) return;
  file.puts(content);
  file.close();
  // No reload: rofi re-reads theme.rasi on each launch.
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
    // palette, return a light neutral — NOT black. Returning black here would
    // produce black-on-black foreground (the bug fixed in waybarthemer2.js).
    if (!dark) {
      return Color("white");
    }

    return isDark ? Color("black") : Color("white");
  };

  const background = pickColor();

  // Ensure visibility of colors against the background color.
  for (let i = 0; i < colors.length; i++) {
    let iterations = 0;
    while (!Color.isReadable(colors[i], background) && iterations < 100) {
      colors[i] = isDark
        ? colors[i].saturate(1).brighten(1)
        : colors[i].desaturate(1).darken(1);
      iterations++;
    }
  }

  // Ensure there are at least 8 colors remaining for selectDistinctColors.
  while (colors.length < 8) {
    colors.push(
      colors[Math.floor(Math.random() * colors.length)].analogous()[3],
    );
  }

  const distinctColors = selectDistinctColors(colors, 8);

  // Pick a light palette color and desaturate it heavily so the foreground
  // reads as soft off-white with a barely-perceptible wallpaper tint, rather
  // than as a colored text. Keeps the launcher readable on any wallpaper.
  const foreground = pickColor(false).desaturate(85);

  // Pick an accent for the selection highlight + window border: the most
  // saturated distinct color tends to read best as an accent.
  const accent = distinctColors
    .slice()
    .sort((a, b) => b.toHsv().s - a.toHsv().s)[0] || distinctColors[0];

  // Slightly raised input/prompt background for depth.
  const inputBg = isDark
    ? background.lighten(5)
    : background.darken(5);

  // Force a high-contrast neutral for the selected row. We want the COLOR to
  // come from `selectBg` (the accent) and the TEXT to be neutral so it never
  // competes with the selection color. Pure white on dark accents, pure black
  // on light accents. Fall back to a soft neutral if contrast still fails.
  let selectFg = accent.isDark() ? Color("white") : Color("black");
  if (!Color.isReadable(accent, selectFg)) {
    selectFg = accent.isDark() ? Color("#f5f5f5") : Color("#1a1a1a");
  }

  const theme = {
    background,
    foreground,
    accent,
    inputBg,
    selectBg: accent,
    selectFg,
  };

  // ── WCAG contrast safety net (ported from waybarthemer2.js) ──────────
  // If foreground didn't come from the palette (e.g. pure white fallback)
  // it's readable but visually jarring. Derive a harmonious foreground
  // from the wallpaper's average hue, then verify contrast ≥ 4.5:1.
  //
  // Saturation is capped at 12% (and scaled down to 0.2x the average) so the
  // fallback reads as a tinted off-white, not a colored text. The hue keeps
  // a subtle wallpaper connection; the value is brightened to pass contrast.
  const minContrast = 4.5;
  const readability = Color.readability(theme.background, theme.foreground);

  if (readability < minContrast) {
    const hsvs = colorCodes.map((c) => Color(c).toHsv());
    const avgH = hsvs.reduce((s, h) => s + (h.h || 0), 0) /
      (hsvs.length || 1);
    const avgS = hsvs.reduce((s, h) => s + (h.s || 0), 0) /
      (hsvs.length || 1);

    let fg = new Color({ h: avgH, s: Math.min(avgS * 0.2, 12), v: 90 });
    let iterations = 0;
    while (
      Color.readability(theme.background, fg) < minContrast &&
      iterations < 50
    ) {
      fg = fg.brighten(2);
      iterations++;
    }
    theme.foreground = fg;
  }

  return theme;
}

function generateThemeConfig(theme) {
  // Emit a COMPLETE rasi theme, not just a `*` variable block. Rofi treats
  // a file containing only a `*` block as a non-theme and falls back to its
  // built-in solarized-light default (with a "Failed to load theme" warning)
  // — so a `*`-only theme.rasi is silently ignored. We need at least the
  // `window` and `element` element selectors for rofi to accept the file
  // and apply the variables. This mirrors how shipped themes
  // (gruvbox-dark-hard.rasi, etc.) are structured.
  //
  // We emit three sets of variables for max compatibility:
  //   1. The custom `main-*` names that the existing `logout-menu.rasi` and
  //      `wifi-bluetooth-menu.rasi` reference via `@main-fg`, etc.
  //   2. The standard rofi variable names (`background`, `foreground`,
  //      `selected-normal-background`, ...) that the default drun launcher
  //      uses internally via `var(background)`, etc.
  //   3. Default element selectors that consume those variables, so the
  //      drun launcher renders with our colors out of the box.
  const isDark = theme.background.isDark();
  const alternateBg = isDark
    ? theme.background.lighten(3)
    : theme.background.darken(3);
  const urgentBg = Color("#cc241d");
  const activeBg = theme.accent;

  const config = `
* {
  /* Custom names (consumed by logout-menu.rasi / wifi-bluetooth-menu.rasi) */
  main-fg:        ${theme.foreground.toHexString()};
  main-bg:        ${theme.background.toHexString()};
  main-br:        ${theme.accent.toHexString()};
  input-bg:       ${theme.inputBg.toHexString()};
  select-bg:      ${theme.selectBg.toHexString()};
  select-fg:      ${theme.selectFg.toHexString()};

  /* Standard rofi names (consumed by the default drun launcher via var()) */
  background:                       ${theme.background.toHexString()};
  foreground:                       ${theme.foreground.toHexString()};
  border-color:                     ${theme.accent.toHexString()};
  separatorcolor:                   ${theme.accent.toHexString()};
  normal-background:                ${theme.background.toHexString()};
  normal-foreground:                ${theme.foreground.toHexString()};
  alternate-normal-background:      ${alternateBg.toHexString()};
  alternate-normal-foreground:      ${theme.foreground.toHexString()};
  selected-normal-background:       ${theme.selectBg.toHexString()};
  selected-normal-foreground:       ${theme.selectFg.toHexString()};
  urgent-background:                ${urgentBg.toHexString()};
  urgent-foreground:                ${theme.background.toHexString()};
  alternate-urgent-background:      ${urgentBg.toHexString()};
  alternate-urgent-foreground:      ${theme.background.toHexString()};
  selected-urgent-background:       ${urgentBg.toHexString()};
  selected-urgent-foreground:       ${theme.background.toHexString()};
  active-background:                ${activeBg.toHexString()};
  active-foreground:                ${theme.background.toHexString()};
  alternate-active-background:      ${activeBg.toHexString()};
  alternate-active-foreground:      ${theme.background.toHexString()};
  selected-active-background:       ${activeBg.toHexString()};
  selected-active-foreground:       ${theme.background.toHexString()};
}

window {
  background-color: var(main-bg);
  border:           2px;
  border-color:     var(main-br);
  padding:          5;
}

mainbox {
  background-color: var(main-bg);
}

inputbar {
  background-color: var(input-bg);
  text-color:       var(main-fg);
  padding:          8px 10px;
  spacing:          0;
  children:         [ "prompt", "entry" ];
}

prompt {
  background-color: transparent;
  text-color:       var(main-fg);
  margin:           0 8px 0 0;
}

entry {
  background-color:  var(input-bg);
  text-color:        var(main-fg);
  placeholder:       "Type to filter";
  placeholder-color: var(main-fg);
  cursor:            text;
}

listview {
  background-color: var(main-bg);
  lines:            8;
  columns:          1;
  spacing:          4px;
  padding:          6px 0;
  cycle:            true;
  fixed-height:     false;
}

element {
  padding:          6px 10px;
  spacing:          0;
  background-color: transparent;
  text-color:       var(main-fg);
  cursor:           pointer;
}

element normal.normal {
  background-color: var(main-bg);
  text-color:       var(main-fg);
}

element selected.normal {
  background-color: var(select-bg);
  text-color:       var(select-fg);
}

element normal.urgent {
  background-color: var(urgent-background);
  text-color:       var(urgent-foreground);
}

element selected.urgent {
  background-color: var(selected-urgent-background);
  text-color:       var(selected-urgent-foreground);
}

element normal.active {
  background-color: var(active-background);
  text-color:       var(active-foreground);
}

element selected.active {
  background-color: var(selected-active-background);
  text-color:       var(selected-active-foreground);
}

element-text {
  background-color: transparent;
  text-color:       inherit;
  cursor:           inherit;
}

element-icon {
  background-color: transparent;
  text-color:       inherit;
  size:             1em;
}
`.trim();

  return config;
}

function selectDistinctColors(colorObjects, count) {
  // Sort colors by perceived brightness
  // NB: copy before sorting/splicing — .sort()/.splice() would mutate the
  // caller's palette in place and empty it for low-color wallpapers.
  const sortedColors = colorObjects.slice().sort((a, b) =>
    a.getBrightness() - b.getBrightness()
  );

  // Select colors with maximum color distance
  const selectedColors = [];
  while (selectedColors.length < count && sortedColors.length > 0) {
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