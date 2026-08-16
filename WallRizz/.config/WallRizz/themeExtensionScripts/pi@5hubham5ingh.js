/*
 For:            Pi coding agent, https://github.com/earendil-works/pi
 Author:         https://github.com/5hubham5ingh
 Version:        0.0.1
 Prerequisite:   pi loads custom themes from ~/.pi/agent/themes/<name>.json and
                 hot-reloads the currently active custom theme when its file
                 changes. This extension writes the theme file there and flips
                 the active theme once via ~/.pi/agent/settings.json
                 ("theme": "wallrizz"). After that, every wallpaper change
                 updates the theme live without restarting pi.

                 Protected tokens (kept as "" = terminal default, so they follow
                 the terminal colors, which are themselves themed from the same
                 wallpaper via the kitty extension):
                   - text            (default text / AI response body)
                   - userMessageText (user input in the transcript)
                 Everything else is derived from the wallpaper palette.
 */

const THEME_NAME = "wallrizz";
const SCHEMA_URL = "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";

export function getDarkThemeConf(colors) {
  return generateThemeConfig(generateTheme(colors, true));
}

export function getLightThemeConf(colors) {
  return generateThemeConfig(generateTheme(colors, false));
}

export function setTheme(themeConfPath) {
  const content = STD.loadFile(themeConfPath);
  const themesDir = HOME_DIR.concat("/.pi/agent/themes");
  const themePath = themesDir.concat("/", THEME_NAME, ".json");
  const settingsPath = HOME_DIR.concat("/.pi/agent/settings.json");

  // Write the theme file. If wallrizz is already the active pi theme, pi's
  // theme watcher hot-reloads this file immediately.
  OS.exec(["sh", "-c", `set -e; mkdir -p "${themesDir}"`]);
  const themeFile = STD.open(themePath, "w");
  if (!themeFile) return;
  themeFile.puts(content);
  themeFile.close();

  // Activate the theme in pi settings, preserving every other key.
  // Only touch settings.json once — if wallrizz is already active, the file
  // write above is enough.
  if (!OS.stat(settingsPath)[0]) return;
  let settings;
  try {
    settings = JSON.parse(STD.loadFile(settingsPath));
  } catch (_err) {
    return; // unparseable settings — never clobber it
  }
  if (!settings || typeof settings !== "object") return;
  if (settings.theme === THEME_NAME) return;
  settings.theme = THEME_NAME;
  const out = STD.open(settingsPath, "w");
  if (!out) return;
  out.puts(JSON.stringify(settings, null, 2));
  out.close();
}

function generateTheme(colorCodes, isDark) {
  const colors = colorCodes.map((c) => Color(c));
  // tinycolor2 >= 1.6.0 mutates on lighten/darken/brighten/saturate/
  // desaturate/spin — always operate on clones.
  const adjust = (c, amt) =>
    isDark ? c.clone().lighten(amt) : c.clone().darken(amt);

  // Background: darkest (dark mode) / lightest (light mode) palette color,
  // clamped in value so pi's boxes and borders stand apart from the terminal
  // background (which kitty themes from the same wallpaper).
  // `dark = isDark` so the black/white fallback matches the mode.
  let background = pickColor(colors, isDark, isDark);
  const hsv = background.toHsv(); // tinycolor2 1.6.0: s/v are 0-1, h is 0-360
  if (isDark && hsv.v > 0.35) {
    background = new Color({ h: hsv.h, s: hsv.s, v: 0.35 });
  } else if (!isDark && hsv.v < 0.75) {
    background = new Color({ h: hsv.h, s: hsv.s, v: 0.75 });
  }
  const bg = background;

  // Ensure every palette color stays readable against the background.
  for (let i = 0; i < colors.length; i++) {
    let iterations = 0;
    while (!Color.isReadable(colors[i], bg) && iterations < 100) {
      colors[i] = isDark
        ? colors[i].saturate(1).brighten(1)
        : colors[i].desaturate(1).darken(1);
      iterations++;
    }
  }
  // Always have at least 8 colors to work with.
  while (colors.length < 8) {
    colors.push(
      colors[Math.floor(Math.random() * colors.length)].analogous()[3],
    );
  }

  // Visually distinct palette (sorted by brightness, darkest first).
  const distinct = selectDistinctColors(colors.slice(), 8);
  const accent = distinct.reduce((best, c) =>
    c.toHsv().s > best.toHsv().s ? c : best
  );

  // Semantic colors: nearest palette hue, otherwise hue-spin the accent.
  const success = semanticColor(distinct, accent, 120, isDark);
  const error = semanticColor(distinct, accent, 0, isDark);
  const warning = semanticColor(distinct, accent, 45, isDark);

  // Neutrals derived from the background.
  const muted = adjust(bg, 45);
  const dim = adjust(bg, 28);
  const thinkingText = adjust(bg, 40);

  // Borders.
  const border = distinct[0];
  const borderAccent = accent;
  const borderMuted = adjust(bg, 20);

  // Backgrounds.
  // In light mode, clamp panels to a soft pastel range (v ≥ 0.78, s ≤ 0.35)
  // so dark text always passes WCAG AA; in dark mode panels are bg-derived.
  const lightPanel = (c) => {
    if (isDark) return c;
    const h = c.toHsv();
    return new Color({ h: h.h, s: Math.min(h.s, 0.35), v: Math.max(h.v, 0.78) });
  };
  const selectedBg = lightPanel(adjust(bg, 6));
  const userMessageBg = lightPanel(adjust(bg, 8));
  const customMessageBg = lightPanel(adjust(bg, 12));
  const toolPendingBg = lightPanel(adjust(bg, 3));
  // Tinted tool boxes use fixed green/red hues (hue-rotating bg is
  // unpredictable — e.g. cyan + 120° lands on magenta), keeping the
  // wallpaper's saturation/value.
  const toolBg = (hue) => {
    const h = bg.toHsv();
    const base = new Color({
      h: hue,
      s: Math.min(h.s + 0.35, 0.6),
      v: h.v,
    });
    return lightPanel(isDark ? base.clone().lighten(3) : base.clone().darken(3));
  };
  const toolSuccessBg = toolBg(120);
  const toolErrorBg = toolBg(0);

  // Markdown.
  const mdHeading = isDark
    ? distinct[4].clone().brighten(8)
    : distinct[4].clone().darken(8);
  const mdLink = accent;
  const mdCode = accent;
  const mdCodeBlock = isDark
    ? distinct[3].clone().brighten(5)
    : distinct[3].clone().darken(5);

  // Syntax (the distinct palette is already readable against bg).
  const syntaxKeyword = distinct[1];
  const syntaxFunction = distinct[2];
  const syntaxVariable = distinct[3];
  const syntaxString = distinct[4];
  const syntaxNumber = distinct[5];
  const syntaxType = distinct[6];

  // Thinking-level borders: subtle → loud.
  const thinkingOff = borderMuted;
  const thinkingMinimal = borderMuted;
  const thinkingLow = distinct[0];
  const thinkingMedium = distinct[1];
  const thinkingHigh = accent;
  const thinkingXhigh = adjust(accent, 10);
  const thinkingMax = adjust(accent.clone().spin(30), 10);

  const theme = {
    accent: accent.toHexString(),
    border: border.toHexString(),
    borderAccent: borderAccent.toHexString(),
    borderMuted: borderMuted.toHexString(),
    success: success.toHexString(),
    error: error.toHexString(),
    warning: warning.toHexString(),
    muted: muted.toHexString(),
    dim: dim.toHexString(),
    text: "", // protected — terminal default
    thinkingText: thinkingText.toHexString(),
    selectedBg: selectedBg.toHexString(),
    scrollbarThumb: selectedBg.toHexString(),
    userMessageBg: userMessageBg.toHexString(),
    userMessageText: "", // protected — terminal default
    customMessageBg: customMessageBg.toHexString(),
    customMessageText: muted.toHexString(),
    customMessageLabel: accent.toHexString(),
    toolPendingBg: toolPendingBg.toHexString(),
    toolSuccessBg: toolSuccessBg.toHexString(),
    toolErrorBg: toolErrorBg.toHexString(),
    toolTitle: accent.toHexString(),
    toolOutput: muted.toHexString(),
    mdHeading: mdHeading.toHexString(),
    mdLink: mdLink.toHexString(),
    mdLinkUrl: dim.toHexString(),
    mdCode: mdCode.toHexString(),
    mdCodeBlock: mdCodeBlock.toHexString(),
    mdCodeBlockBorder: borderMuted.toHexString(),
    mdQuote: muted.toHexString(),
    mdQuoteBorder: borderMuted.toHexString(),
    mdHr: borderMuted.toHexString(),
    mdListBullet: accent.toHexString(),
    toolDiffAdded: success.toHexString(),
    toolDiffRemoved: error.toHexString(),
    toolDiffContext: muted.toHexString(),
    syntaxComment: dim.toHexString(),
    syntaxKeyword: syntaxKeyword.toHexString(),
    syntaxFunction: syntaxFunction.toHexString(),
    syntaxVariable: syntaxVariable.toHexString(),
    syntaxString: syntaxString.toHexString(),
    syntaxNumber: syntaxNumber.toHexString(),
    syntaxType: syntaxType.toHexString(),
    syntaxOperator: muted.toHexString(),
    syntaxPunctuation: dim.toHexString(),
    thinkingOff: thinkingOff.toHexString(),
    thinkingMinimal: thinkingMinimal.toHexString(),
    thinkingLow: thinkingLow.toHexString(),
    thinkingMedium: thinkingMedium.toHexString(),
    thinkingHigh: thinkingHigh.toHexString(),
    thinkingXhigh: thinkingXhigh.toHexString(),
    thinkingMax: thinkingMax.toHexString(),
    bashMode: success.toHexString(),
  };

  // ── WCAG contrast safety net ───────────────────────────────────────
  // Adjust each foreground against its real background until it passes AA.
  const readable = (fg, bgColor) =>
    ensureReadable(fg, bgColor, isDark).toHexString();
  theme.accent = readable(accent, selectedBg);
  theme.border = readable(border, bg);
  theme.borderAccent = theme.accent;
  theme.borderMuted = readable(borderMuted, bg);
  theme.success = readable(success, toolSuccessBg);
  theme.error = readable(error, toolErrorBg);
  theme.warning = readable(warning, userMessageBg);
  theme.muted = readable(muted, userMessageBg);
  theme.dim = readable(dim, userMessageBg);
  theme.thinkingText = readable(thinkingText, selectedBg);
  theme.customMessageText = readable(muted, customMessageBg);
  theme.customMessageLabel = theme.accent;
  theme.toolTitle = readable(accent, toolPendingBg);
  theme.toolOutput = readable(muted, toolPendingBg);
  theme.mdHeading = readable(mdHeading, selectedBg);
  theme.mdLink = theme.accent;
  theme.mdLinkUrl = theme.dim;
  theme.mdCode = theme.accent;
  theme.mdCodeBlock = readable(mdCodeBlock, userMessageBg);
  theme.mdCodeBlockBorder = theme.borderMuted;
  theme.mdQuote = theme.muted;
  theme.mdQuoteBorder = theme.borderMuted;
  theme.mdHr = theme.borderMuted;
  theme.mdListBullet = theme.accent;
  theme.toolDiffAdded = theme.success;
  theme.toolDiffRemoved = theme.error;
  theme.toolDiffContext = theme.muted;
  theme.syntaxComment = theme.dim;
  theme.syntaxKeyword = readable(syntaxKeyword, bg);
  theme.syntaxFunction = readable(syntaxFunction, bg);
  theme.syntaxVariable = readable(syntaxVariable, bg);
  theme.syntaxString = readable(syntaxString, bg);
  theme.syntaxNumber = readable(syntaxNumber, bg);
  theme.syntaxType = readable(syntaxType, bg);
  theme.syntaxOperator = theme.muted;
  theme.syntaxPunctuation = theme.dim;
  theme.thinkingLow = readable(thinkingLow, bg);
  theme.thinkingMedium = readable(thinkingMedium, bg);
  theme.thinkingHigh = theme.accent;
  theme.thinkingXhigh = readable(thinkingXhigh, bg);
  theme.thinkingMax = readable(thinkingMax, bg);
  theme.bashMode = theme.success;

  return theme;
}

function generateThemeConfig(theme) {
  return JSON.stringify(
    {
      $schema: SCHEMA_URL,
      name: THEME_NAME,
      colors: theme,
    },
    null,
    2,
  );
}

/** Pick the first dark/light color from the palette (waybarthemer2 fix:
 *  never fall back to black when a light color is requested). */
function pickColor(colors, isDark, dark) {
  const index = colors.findIndex((c) =>
    (dark ?? isDark) ? c.isDark() : c.isLight()
  );
  if (index !== -1) return colors.splice(index, 1)[0];
  if (!dark) return Color("white");
  return isDark ? Color("black") : Color("white");
}

/** Pick N visually distinct colors by max-min color distance. */
function selectDistinctColors(colorObjects, count) {
  // NB: copy before sorting/splicing — .sort()/.splice() would mutate the
  // caller's palette in place and empty it for low-color wallpapers.
  const sortedColors = colorObjects.slice().sort((a, b) =>
    a.getBrightness() - b.getBrightness()
  );
  const selectedColors = [];
  while (selectedColors.length < count && sortedColors.length > 0) {
    if (selectedColors.length === 0) {
      const midIndex = Math.floor(sortedColors.length / 2);
      selectedColors.push(sortedColors[midIndex]);
      sortedColors.splice(midIndex, 1);
      continue;
    }
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

/** Brighten/darken a foreground until it passes WCAG AA (≥ 4.5:1). */
function ensureReadable(fg, bgColor, isDark) {
  let c = Color(fg).clone();
  let iterations = 0;
  while (!Color.isReadable(c, bgColor) && iterations < 100) {
    c = isDark ? c.brighten(2).saturate(1) : c.darken(2).desaturate(1);
    iterations++;
  }
  return c;
}

/** Semantic colors (success/error/warning): use a palette color only when it
 *  is genuinely close to the target hue (≤ 30°) AND clearly distinct from the
 *  accent; otherwise spin the accent so the semantic color is recognizable
 *  (e.g. a warm wallpaper has no red — error must not look like the border).
 *  For grayscale wallpapers there is no hue to work with, so fabricate a soft
 *  tint that keeps the palette's value. */
function semanticColor(distinct, accent, targetHue, isDark) {
  const hueDelta = (a, b) => {
    let d = Math.abs(a - b);
    if (d > 180) d = 360 - d;
    return d;
  };
  const accentHsv = accent.toHsv();
  const accentHue = accentHsv.h || 0;
  if ((accentHsv.s || 0) < 0.15) {
    const v = accentHsv.v;
    return new Color({
      h: targetHue,
      s: 0.35,
      v: isDark ? Math.max(v, 0.8) : Math.min(v, 0.45),
    });
  }
  let best = null;
  let bestDelta = 361;
  for (let i = 0; i < distinct.length; i++) {
    const h = distinct[i].toHsv().h || 0;
    const d = hueDelta(h, targetHue);
    if (d < bestDelta) {
      bestDelta = d;
      best = distinct[i];
    }
  }
  if (
    best &&
    bestDelta <= 30 &&
    hueDelta(best.toHsv().h || 0, accentHue) >= 25
  ) {
    return best;
  }
  return accent.clone().spin(targetHue - accentHue);
}
