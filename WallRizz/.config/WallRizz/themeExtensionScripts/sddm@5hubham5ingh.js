/*
 For:            SDDM (where-is-my-sddm-theme), https://github.com/stepanzubkov/where-is-my-sddm-theme
 Author:         https://github.com/5hubham5ingh
 Version:        0.0.1
 Prerequisite:   SDDM must be configured to use where-is-my-sddm-theme.
                 /etc/sddm.conf.d/theme.conf must have:
                   [Theme]
                   Current=where-is-my-sddm-theme

                 Optional setup (run once, requires password) for automatic applying:
                   sudo cp ~/.config/WallRizz/themeExtensionScripts/sddm-sudoers-rule /etc/sudoers.d/wallrizz-sddm
                   sudo chmod 440 /etc/sudoers.d/wallrizz-sddm

 What it does:
   - Generates a themed theme.conf from the wallpaper palette
   - Copies selected wallpaper to /usr/share/backgrounds/current-wallpaper.jpg
   - Points SDDM background to /usr/share/backgrounds/current-wallpaper.jpg
   - Sets basicTextColor, passwordCursorColor, backgroundFill from the palette
   - Copies theme.conf to /usr/share/sddm/themes/where-is-my-sddm-theme/theme.conf
   - Changes take effect at next SDDM login screen
*/

// ── Color picking helpers (battle-tested across existing extensions) ──

function pickColor(colors, isDark, dark) {
  const cs = colors.map((c) => Color(c));
  const i = cs.findIndex((c) => (dark ?? isDark) ? c.isDark() : c.isLight());
  if (i !== -1) return { color: cs.splice(i, 1)[0], colors: cs };
  return { color: dark ? (isDark ? Color("black") : Color("white")) : Color("white"),
           colors: cs };
}

function selectDistinctColors(colorObjects, count) {
  const sorted = colorObjects.slice().sort((a, b) => a.getBrightness() - b.getBrightness());
  const picked = [];
  while (picked.length < count && sorted.length > 0) {
    if (picked.length === 0) {
      const mid = Math.floor(sorted.length / 2);
      picked.push(sorted[mid]); sorted.splice(mid, 1); continue;
    }
    let best = null, bestDist = -1;
    for (const c of sorted) {
      const minD = Math.min(...picked.map((p) => Color.readability(p, c)));
      if (minD > bestDist) { bestDist = minD; best = c; }
    }
    if (best) { picked.push(best); sorted.splice(sorted.indexOf(best), 1); }
    else break;
  }
  return picked;
}

// ── Theme generation ──

function generateTheme(colorCodes, isDark) {
  const colors = colorCodes.map((c) => Color(c));

  // Pick background (dark color for dark theme, light for light)
  const bgResult = pickColor(colors, isDark);
  let background = bgResult.color;
  const remaining = bgResult.colors;

  // Pick foreground (opposite of background for contrast)
  const fgResult = pickColor(remaining, isDark, !isDark);
  let foreground = fgResult.color;
  const remaining2 = fgResult.colors;

  // Pick accent from remaining
  const distinct = selectDistinctColors(remaining2, 3);
  const accent = distinct.length > 0 ? distinct[0] : foreground;

  // ── WCAG contrast safety net ──
  const minContrast = 4.5;
  if (Color.readability(background, foreground) < minContrast) {
    const hsvs = colorCodes.map((c) => Color(c).toHsv());
    const avgH = hsvs.reduce((s, h) => s + (h.h || 0), 0) / hsvs.length;
    const avgS = hsvs.reduce((s, h) => s + (h.s || 0), 0) / hsvs.length;

    let fg = new Color({ h: avgH, s: Math.min(avgS * 1.5, 60), v: isDark ? 85 : 25 });
    let iterations = 0;
    while (Color.readability(background, fg) < minContrast && iterations < 50) {
      fg = isDark ? fg.brighten(2) : fg.darken(2);
      iterations++;
    }
    foreground = fg;
  }

  return {
    background: background.toHexString(),
    foreground: foreground.toHexString(),
    accent: accent.toHexString(),
  };
}

function generateThemeConf(theme) {
  return `[General]
# Password mask character
passwordCharacter=*
# Mask password characters or not ("true" or "false")
passwordMask=true
# value "1" is all display width, "0.5" is a half of display width etc.
passwordInputWidth=0.5
# Background color of password input
passwordInputBackground=
# Radius of password input corners
passwordInputRadius=
# Width of the border for the password input
passwordInputBorderWidth=0
# Border color for the password input
passwordInputBorderColor=
# "true" for visible cursor, "false"
passwordInputCursorVisible=true
# Font size of password (in points)
passwordFontSize=96
passwordCursorColor=random
passwordTextColor=${theme.foreground}
# Allow blank password (e.g., if authentication is done by another PAM module)
passwordAllowEmpty=false

# Radius of the border which is displayed upon wrong authentication attempt
wrongPasswordBorderRadius=
# Color of the border which is displayed upon wrong authentication attempt
wrongPasswordBorderColor=

# Enable or disable cursor blink animation ("true" or "false")
cursorBlinkAnimation=true

# Show or not sessions choose label
showSessionsByDefault=true
# Font size of sessions choose label (in points).
sessionsFontSize=24

# Show or not users choose label
showUsersByDefault=false
# Font size of users choose label (in points)
usersFontSize=48
# Show user real name on label by default
showUserRealNameByDefault=true

# Path to background image
background=/usr/share/backgrounds/current-wallpaper.jpg
# Or use just one color
backgroundFill=${theme.background}
# Fill mode for image background
# Value must be on of: aspect, fill, tile, pad
backgroundFillMode=aspect

# Default text color for all labels
basicTextColor=${theme.foreground}

# Blur radius for background image
blurRadius=0

# Hide cursor
hideCursor=false

# Default font
font=JetBrainsMono Nerd Font

# Font of help message
helpFont=JetBrainsMono Nerd Font
# Font size of help message (in points)
helpFontSize=18
`.trim();
}

// ── Public API ──

export function getDarkThemeConf(colors) {
  const theme = generateTheme(colors, true);
  return generateThemeConf(theme);
}

export function getLightThemeConf(colors) {
  const theme = generateTheme(colors, false);
  return generateThemeConf(theme);
}

export function setTheme(themeConfPath) {
  // hyprpaper@5hubham5ingh.js already copied the wallpaper here —
  // we copy it to the SDDM-readable location.
  const wpSrc = HOME_DIR.concat("/.local/share/backgrounds/current-wallpaper.jpg");
  const wpDst = "/usr/share/backgrounds/current-wallpaper.jpg";

  // Copy wallpaper + theme.conf via the helper script (NOPASSWD sudoers rule required)
  const applyScript = HOME_DIR.concat("/.config/WallRizz/themeExtensionScripts/apply-sddm-theme.sh");
  OS.exec(["sh", "-c",
    `sudo "${applyScript}" "${themeConfPath}" "${wpSrc}" "${wpDst}"`,
  ]);
}
