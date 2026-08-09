/*
 For:            herdr — agent multiplexer (https://herdr.dev)
 Author:         https://github.com/5hubham5ingh
 Version:        0.1.0
 Prerequisite:   None — the extension manages ~/.config/herdr/config.toml itself.

 How it works:
   - Generates a [theme.custom] override block (accent/text/semantic colors)
     derived from the wallpaper palette.
   - setTheme() splices that block into ~/.config/herdr/config.toml, keeping
     every other setting untouched, then runs `herdr server reload-config`
     so the change applies to a running session.
   - BACKGROUND IS NEVER REPAINTED: panel_bg / surface0 / surface1 /
     surface_dim / overlay0 / overlay1 are left unset, so herdr keeps the
     base theme's backgrounds (rose-pine by default) exactly as they were.
   - Light mode: the base theme name is switched to its light sibling
     (rose-pine -> rose-pine-dawn, etc.) so dark text stays readable.

 Schema reference: https://herdr.dev/docs/config-reference/ (theme.custom)
 Color values accept hex, named colors, rgb(r,g,b), or reset aliases.
*/

export function getDarkThemeConf(colors) {
  return generateTheme(colors, true);
}

export function getLightThemeConf(colors) {
  return generateTheme(colors, false);
}

export function setTheme(themeConfPath) {
  const configPath = HOME_DIR.concat("/.config/herdr/config.toml");
  const isLight = themeConfPath.indexOf("-light") !== -1;

  const py = [
    "import sys, re",
    "conf, theme_path, mode = sys.argv[1], sys.argv[2], sys.argv[3]",
    "custom = open(theme_path).read().strip()",
    "lines = open(conf).read().split('\\n')",
    "start = None",
    "for i, ln in enumerate(lines):",
    "    if re.match(r'^\\s*\\[theme(\\]|\\.)', ln):",
    "        start = i",
    "        break",
    "name = None",
    "auto_switch = None",
    "if start is not None:",
    "    end = len(lines)",
    "    for j in range(start + 1, len(lines)):",
    "        m2 = re.match(r'^\\s*\\[([^\\]]+)\\]', lines[j])",
    "        if m2 and not m2.group(1).startswith('theme'):",
    "            end = j",
    "            break",
    "    block = '\\n'.join(lines[start:end])",
    "    m = re.search(r'^\\s*name\\s*=\\s*\"([^\"]+)\"', block, re.M)",
    "    if m: name = m.group(1)",
    "    m = re.search(r'^\\s*auto_switch\\s*=\\s*(true|false)', block, re.M)",
    "    if m: auto_switch = m.group(1)",
    "    del lines[start:end]",
    "if name is None:",
    "    name = 'rose-pine'",
    "if auto_switch is None:",
    "    auto_switch = 'false'",
    "LIGHT = {",
    "    'rose-pine': 'rose-pine-dawn',",
    "    'catppuccin': 'catppuccin-latte',",
    "    'catppuccin-mocha': 'catppuccin-latte',",
    "    'tokyo-night': 'tokyo-night-day',",
    "    'tokyonight': 'tokyo-night-day',",
    "    'gruvbox': 'gruvbox-light',",
    "    'gruvbox-dark': 'gruvbox-light',",
    "    'one-dark': 'one-light',",
    "    'onedark': 'one-light',",
    "    'kanagawa': 'kanagawa-lotus',",
    "    'solarized': 'solarized-light',",
    "    'solarized-dark': 'solarized-light',",
    "}",
    "DARK = {",
    "    'rose-pine-dawn': 'rose-pine',",
    "    'catppuccin-latte': 'catppuccin',",
    "    'tokyo-night-day': 'tokyo-night',",
    "    'gruvbox-light': 'gruvbox',",
    "    'one-light': 'one-dark',",
    "    'kanagawa-lotus': 'kanagawa',",
    "    'solarized-light': 'solarized',",
    "}",
    "if mode == 'dark' and name in DARK:",
    "    name = DARK[name]",
    "elif mode == 'light' and name in LIGHT:",
    "    name = LIGHT[name]",
    "new_block = '[theme]\\nname = \\\"%s\\\"\\nauto_switch = %s\\n\\n%s' % (name, auto_switch, custom)",
    "out = '\\n'.join(lines).rstrip('\\n')",
    "if out and not out.endswith('\\n'):",
    "    out += '\\n'",
    "out += new_block + '\\n'",
    "open(conf, 'w').write(out)",
    "print('theme updated:', name)",
  ].join("\n");

  const script =
    "python3 - " +
    JSON.stringify(configPath) +
    " " +
    JSON.stringify(themeConfPath) +
    " " +
    (isLight ? "light" : "dark") +
    " <<'PYEOF'\n" +
    py +
    "\nPYEOF\n" +
    "herdr server reload-config >/dev/null 2>&1 || true";

  OS.exec(["sh", "-c", script]);
}

// Clone-safe contrast clamp; every loop capped, safe fallback.
function ensureContrast(fg, bg, minRatio, isDark) {
  fg = fg.clone();
  let iters = 0;
  while (Color.readability(bg, fg) < minRatio && iters < 80) {
    if (isDark) fg = fg.brighten(2).saturate(1);
    else fg = fg.darken(2);
    iters++;
  }
  if (Color.readability(bg, fg) < minRatio) {
    fg = isDark ? Color("#ffffff") : Color("#000000");
  }
  return fg;
}

// Spin a color so its hue lands on targetHue (0-360), preserving saturation/value.
function hueTarget(color, targetHue) {
  const h = color.toHsv().h || 0;
  let d = targetHue - h;
  while (d > 180) d -= 360;
  while (d < -180) d += 360;
  return color.clone().spin(d);
}

function generateTheme(colorCodes, isDark) {
  const palette = colorCodes.map((c) => Color(c));

  // Virtual background for contrast math (never written to config).
  // Fixed to the actual herdr base backgrounds: rose-pine panel_bg for dark,
  // rose-pine-dawn panel_bg for light. This keeps colors readable even when
  // the wallpaper palette is all-dark or all-light.
  const virtualBg = isDark ? Color("#191724") : Color("#faf4ed");

  const sorted = palette.slice().sort((a, b) => a.getBrightness() - b.getBrightness());

  // --- text: brightest (dark) / darkest (light), contrast >= 6 ---
  let text;
  if (isDark) {
    text = (sorted[sorted.length - 2] || Color("#e0e0e0")).clone();
  } else {
    text = (sorted[1] || Color("#3a3a3a")).clone();
  }
  text = ensureContrast(text, virtualBg, 6.0, isDark);
  if (isDark && text.getBrightness() < 180) text = Color("#e0e0e0");
  if (!isDark && text.getBrightness() > 110) text = Color("#3a3a3a");

  // --- subtext0: dimmed secondary text (clearly dimmer than text) ---
  let subtext0;
  if (isDark) {
    subtext0 = ensureContrast(text.clone().darken(18), virtualBg, 3.5, isDark);
    if (subtext0.getBrightness() < 120) subtext0 = Color("#a0a0a0");
  } else {
    subtext0 = ensureContrast(text.clone().lighten(18), virtualBg, 3.5, isDark);
    if (subtext0.getBrightness() > 200) subtext0 = Color("#7a7a7a");
  }

  // --- accent: vivid spin of a mid-bright palette color ---
  const seed = (sorted[Math.floor(sorted.length * 0.7)] || sorted[sorted.length - 1]).clone();
  let accent = ensureContrast(seed.spin(30), virtualBg, 4.5, isDark);
  if (isDark && accent.getBrightness() < 110) accent = accent.brighten(60).saturate(10);
  if (!isDark && accent.getBrightness() > 175) accent = accent.darken(40).saturate(10);
  accent = ensureContrast(accent, virtualBg, 4.5, isDark);

  // --- semantic colors: hue-targeted, then contrast/brightness adjusted ---
  const mk = (targetHue) => {
    let c = hueTarget(accent, targetHue);
    c = ensureContrast(c, virtualBg, 4.0, isDark);
    if (isDark && c.getBrightness() < 90) c = c.brighten(50).saturate(10);
    if (!isDark && c.getBrightness() > 175) c = c.darken(45).saturate(10);
    c = ensureContrast(c, virtualBg, 4.0, isDark);
    return c;
  };
  const mauve = mk(280);
  const green = mk(120);
  const yellow = mk(50);
  const red = mk(0);
  const blue = mk(235);
  const teal = mk(175);
  const peach = mk(25);

  const h = (c) => c.toHexString();
  const lines = [
    "[theme.custom]",
    'accent = "' + h(accent) + '"',
    'text = "' + h(text) + '"',
    'subtext0 = "' + h(subtext0) + '"',
    'mauve = "' + h(mauve) + '"',
    'green = "' + h(green) + '"',
    'yellow = "' + h(yellow) + '"',
    'red = "' + h(red) + '"',
    'blue = "' + h(blue) + '"',
    'teal = "' + h(teal) + '"',
    'peach = "' + h(peach) + '"',
  ];
  return lines.join("\n");
}
