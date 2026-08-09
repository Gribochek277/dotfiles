/*
 For:            Yazi file manager, https://github.com/sxyota/yazi
 Author:         https://github.com/5hubham5ingh
 Version:        0.5.0
 Prerequisite:   In ~/.config/yazi/theme.toml:
                   [flavor]
                   dark = "WallRizz"
                   light = "WallRizz"
                 Flavor written to ~/.config/yazi/flavors/WallRizz.yazi/flavor.toml.

 Schema: yazi 26.5.6 — https://yazi-rs.github.io/docs/configuration/theme
 Key facts for 26.5.6:
   - Section: [mgr]  (not [manager])
   - Section: [cmp]   (not [completion])
   - [icon] section controls icon glyph colors (separate from [filetype])
   - [filetype] rules use { url = "*", ... } for fallback (not name = "*")

 CRITICAL sandbox quirk: Color methods (darken/brighten/desaturate/spin/...)
 MUTATE the receiver in place. NEVER reuse a palette color without .clone().
*/

export function getDarkThemeConf(colors) {
  return generateTheme(colors, true);
}

export function getLightThemeConf(colors) {
  return generateTheme(colors, false);
}

export function setTheme(themeConfPath) {
  const flavorDir = HOME_DIR.concat("/.config/yazi/flavors/WallRizz.yazi");
  const flavorPath = flavorDir.concat("/flavor.toml");
  OS.exec(["sh", "-c", `mkdir -p "${flavorDir}" && cp -f -- "${themeConfPath}" "${flavorPath}"`]);
}

// Ensure fg/bg readability; fallback to pure black/white.
// Clones fg internally so the caller's object is never mutated.
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

// Pick black or white fg for a given bg (whichever contrasts better)
function fgOn(bg) {
  const black = Color("#000000");
  const white = Color("#ffffff");
  return Color.readability(bg, black) >= Color.readability(bg, white) ? black : white;
}

function generateTheme(colorCodes, isDark) {
  const palette = colorCodes.map((c) => Color(c));

  // --- Virtual background for contrast calc (NOT written to theme) ---
  let virtualBg;
  if (isDark) {
    const dark = palette.find((c) => c.isDark());
    virtualBg = dark ? dark.clone() : Color("#1e1e2e");
  } else {
    const light = palette.find((c) => c.isLight());
    virtualBg = light ? light.clone() : Color("#f0f0f0");
  }

  // --- Foreground: brightest (dark) or darkest (light) ---
  const sorted = palette.slice().sort((a, b) => a.getBrightness() - b.getBrightness());
  let fg;
  if (isDark) {
    fg = sorted[Math.max(0, sorted.length - 2)].clone();
  } else {
    fg = sorted[1].clone();
  }
  fg = ensureContrast(fg, virtualBg, 6.0, isDark);
  // Brightness floors (getBrightness returns 0-255)
  if (isDark && fg.getBrightness() < 180) fg = Color("#e0e0e0");
  if (!isDark && fg.getBrightness() > 110) fg = Color("#3a3a3a");

  // --- Accent colors from wallpaper hues ---
  const spinAngles = [30, 75, 120, 180, 240, 300];
  const accentSeeds = [
    sorted[Math.floor(sorted.length * 0.6)],
    sorted[Math.floor(sorted.length * 0.65)],
    sorted[Math.floor(sorted.length * 0.7)],
    sorted[Math.floor(sorted.length * 0.75)],
    sorted[Math.floor(sorted.length * 0.8)],
    sorted[Math.floor(sorted.length * 0.85)],
  ].filter((c) => c !== undefined);
  while (accentSeeds.length < 6) accentSeeds.push(sorted[0]);

  const accents = accentSeeds.map((seed, i) => {
    let c = seed.clone().spin(spinAngles[i]);
    if (isDark && c.getBrightness() < 80) c = c.brighten(40).saturate(10);
    if (!isDark && c.getBrightness() > 185) c = c.darken(60).saturate(10);
    c = ensureContrast(c, virtualBg, 3.0, isDark);
    return c;
  });
  while (accents.length < 6) accents.push(accents[accents.length - 1].clone());

  // --- Derived colors (clone before any mutating call) ---
  const selBg = accents[0].clone();
  let selFg = isDark ? Color("#000000") : Color("#ffffff");
  let it = 0;
  while (Color.readability(selBg, selFg) < 4.5 && it < 80) {
    selFg = selFg.clone();
    if (isDark) selFg = selFg.brighten(5);
    else selFg = selFg.darken(5);
    it++;
  }

  const tabInactiveBg = accents[1].clone().desaturate(20);
  const tabInactiveFg = ensureContrast(fg.clone().desaturate(20), tabInactiveBg, 4.5, !isDark);
  const borderColor = fg.clone().desaturate(40);

  const mkFg = ensureContrast(
    isDark ? Color("#000000") : Color("#ffffff"),
    accents[2],
    4.5,
    isDark
  );
  const markerCopied = { fg: mkFg.clone(), bg: accents[2].clone() };
  const markerCut = { fg: mkFg.clone(), bg: accents[3].clone() };
  const markerMarked = { fg: mkFg.clone(), bg: accents[4].clone() };
  const markerSelected = { fg: mkFg.clone(), bg: accents[5].clone() };

  const countCopied = { fg: selFg.clone(), bg: accents[2].clone() };
  const countCut = { fg: selFg.clone(), bg: accents[3].clone() };
  const countSelected = { fg: selFg.clone(), bg: accents[5].clone() };

  // Progress bar
  const progressNormal = { fg: fg.clone(), bg: accents[5].clone() };
  const progressError = { fg: fg.clone(), bg: accents[0].clone() };

  // Permissions
  const permSepFg = ensureContrast(fg.clone().desaturate(30), virtualBg, 4.5, isDark);

  // Input/select
  const inputBorder = accents[2].clone();

  // Find/Which
  const findKeyword = accents[0].clone();
  const findPosition = accents[5].clone();
  const whichCand = accents[4].clone();
  const whichDesc = accents[1].clone();
  const whichRest = ensureContrast(fg.clone().desaturate(15), virtualBg, 4.5, isDark);

  // Help
  const helpOn = accents[2].clone();
  const helpRun = accents[0].clone();
  const helpFooter = { fg: selFg.clone(), bg: accents[3].clone() };

  // Notify
  const notifyInfo = accents[2].clone();
  const notifyWarn = accents[4].clone();
  const notifyError = accents[0].clone();

  // File type + icon colors (ensured readable on virtualBg)
  const imageFg = ensureContrast(accents[0].clone(), virtualBg, 4.0, isDark);
  const videoFg = ensureContrast(accents[1].clone(), virtualBg, 4.0, isDark);
  const audioFg = ensureContrast(accents[2].clone(), virtualBg, 4.0, isDark);
  const archiveFg = ensureContrast(accents[3].clone(), virtualBg, 4.0, isDark);
  const dirFg = ensureContrast(accents[4].clone(), virtualBg, 4.0, isDark);

  const h = (c) => c.toHexString();

  return `
[mgr]
cwd = { fg = "${h(fg)}" }
hovered = { fg = "${h(selFg)}", bg = "${h(selBg)}" }
preview_hovered = { underline = true }
find_keyword = { fg = "${h(findKeyword)}", italic = true }
find_position = { fg = "${h(findPosition)}", bg = "reset", italic = true }
marker_copied = { fg = "${h(markerCopied.fg)}", bg = "${h(markerCopied.bg)}" }
marker_cut = { fg = "${h(markerCut.fg)}", bg = "${h(markerCut.bg)}" }
marker_marked = { fg = "${h(markerMarked.fg)}", bg = "${h(markerMarked.bg)}" }
marker_selected = { fg = "${h(markerSelected.fg)}", bg = "${h(markerSelected.bg)}" }
count_copied = { fg = "${h(countCopied.fg)}", bg = "${h(countCopied.bg)}" }
count_cut = { fg = "${h(countCut.fg)}", bg = "${h(countCut.bg)}" }
count_selected = { fg = "${h(countSelected.fg)}", bg = "${h(countSelected.bg)}" }
border_symbol = "│"
border_style = { fg = "${h(borderColor)}" }

[tabs]
active = { fg = "${h(selFg)}", bg = "${h(selBg)}", bold = true }
inactive = { fg = "${h(tabInactiveFg)}", bg = "${h(tabInactiveBg)}" }
width = 1

[mode]
normal_main = { fg = "${h(selFg)}", bg = "${h(accents[0])}", bold = true }
normal_alt = { fg = "${h(fgOn(accents[1]))}", bg = "${h(accents[1])}" }
select_main = { fg = "${h(selFg)}", bg = "${h(accents[2])}", bold = true }
select_alt = { fg = "${h(fgOn(accents[1]))}", bg = "${h(accents[1])}" }
unset_main = { fg = "${h(selFg)}", bg = "${h(accents[5])}", bold = true }
unset_alt = { fg = "${h(fgOn(accents[1]))}", bg = "${h(accents[1])}" }

[status]
perm_type = { fg = "${h(accents[0])}" }
perm_read = { fg = "${h(accents[3])}" }
perm_write = { fg = "${h(accents[4])}" }
perm_exec = { fg = "${h(accents[2])}" }
perm_sep = { fg = "${h(permSepFg)}" }
progress_label = { fg = "${h(fg)}", bold = true }
progress_normal = { fg = "${h(progressNormal.fg)}", bg = "${h(progressNormal.bg)}" }
progress_error = { fg = "${h(progressError.fg)}", bg = "${h(progressError.bg)}" }

[pick]
border = { fg = "${h(inputBorder)}" }
active = { fg = "${h(accents[0])}", bold = true }
inactive = { fg = "${h(fg)}", dim = true }

[input]
border = { fg = "${h(inputBorder)}" }
title = {}
value = {}
selected = { reversed = true }

[cmp]
border = { fg = "${h(inputBorder)}" }
active = { fg = "${h(accents[0])}", bold = true }
inactive = { fg = "${h(fg)}", dim = true }

[tasks]
border = { fg = "${h(inputBorder)}" }
title = {}
hovered = { fg = "${h(accents[0])}", underline = true }

[which]
mask = { bg = "${h(virtualBg)}" }
cand = { fg = "${h(whichCand)}" }
rest = { fg = "${h(whichRest)}" }
desc = { fg = "${h(whichDesc)}" }
separator = "  "
separator_style = { fg = "${h(whichDesc)}" }

[help]
on = { fg = "${h(helpOn)}" }
run = { fg = "${h(helpRun)}" }
desc = { fg = "${h(fg)}" }
hovered = { reversed = true, bold = true }
footer = { fg = "${h(helpFooter.fg)}", bg = "${h(helpFooter.bg)}" }

[notify]
title_info = { fg = "${h(notifyInfo)}" }
title_warn = { fg = "${h(notifyWarn)}" }
title_error = { fg = "${h(notifyError)}" }

[filetype]
rules = [
    { mime = "image/*", fg = "${h(imageFg)}" },
    { mime = "video/*", fg = "${h(videoFg)}" },
    { mime = "audio/*", fg = "${h(audioFg)}" },
    { mime = "application/zip", fg = "${h(archiveFg)}" },
    { mime = "application/gzip", fg = "${h(archiveFg)}" },
    { mime = "application/x-tar", fg = "${h(archiveFg)}" },
    { mime = "application/x-bzip", fg = "${h(archiveFg)}" },
    { mime = "application/x-bzip2", fg = "${h(archiveFg)}" },
    { mime = "application/x-7z-compressed", fg = "${h(archiveFg)}" },
    { mime = "application/x-rar", fg = "${h(archiveFg)}" },
    { mime = "application/pdf", fg = "${h(dirFg)}" },
    { url = "*", fg = "${h(fg)}" },
    { url = "*/", fg = "${h(dirFg)}" },
]

[icon]
dirs = [
    { name = ".config", text = ".", fg = "${h(accents[0])}" },
    { name = ".git", text = "", fg = "${h(accents[0])}" },
    { name = "*", text = "", fg = "${h(accents[0])}" },
]
conds = [
    { if = "dir & hovered", text = " ", fg = "${h(accents[0])}" },
    { if = "link", text = " ", fg = "${h(accents[5])}" },
    { if = "dir", text = " ", fg = "${h(accents[0])}" },
    { if = "exec", text = " ", fg = "${h(accents[2])}" },
    { if = "!dir", text = " ", fg = "${h(fg)}" },
]
exts = [
    { name = "jpg", text = "J", fg = "${h(imageFg)}" },
    { name = "jpeg", text = "J", fg = "${h(imageFg)}" },
    { name = "png", text = "P", fg = "${h(imageFg)}" },
    { name = "gif", text = "G", fg = "${h(imageFg)}" },
    { name = "mp4", text = "V", fg = "${h(videoFg)}" },
    { name = "mkv", text = "V", fg = "${h(videoFg)}" },
    { name = "webm", text = "V", fg = "${h(videoFg)}" },
    { name = "mp3", text = "A", fg = "${h(audioFg)}" },
    { name = "flac", text = "A", fg = "${h(audioFg)}" },
    { name = "wav", text = "A", fg = "${h(audioFg)}" },
    { name = "zip", text = "Z", fg = "${h(archiveFg)}" },
    { name = "tar", text = "Z", fg = "${h(archiveFg)}" },
    { name = "gz", text = "Z", fg = "${h(archiveFg)}" },
    { name = "7z", text = "Z", fg = "${h(archiveFg)}" },
    { name = "rar", text = "Z", fg = "${h(archiveFg)}" },
    { name = "pdf", text = "D", fg = "${h(dirFg)}" },
    { name = "txt", text = "T", fg = "${h(fg)}" },
    { name = "md", text = "M", fg = "${h(fg)}" },
    { name = "sh", text = "S", fg = "${h(accents[2])}" },
    { name = "lua", text = "L", fg = "${h(accents[3])}" },
    { name = "js", text = "J", fg = "${h(accents[4])}" },
    { name = "ts", text = "T", fg = "${h(accents[4])}" },
    { name = "py", text = "P", fg = "${h(accents[5])}" },
    { name = "rs", text = "R", fg = "${h(accents[0])}" },
]
`.trim();
}
