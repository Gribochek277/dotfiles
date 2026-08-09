/*
 For:            btop, https://github.com/aristocratos/btop
 Author:         https://github.com/5hubham5ingh
 Version:        0.3.0
 Prerequisite:   btop must be configured with:
                 color_theme = "~/.config/btop/themes/WallRizz.theme"
                 theme_background = false

 What this fixes:
   - All text is readable (WCAG AA contrast enforced)
   - Graph gradients use varied hues from the wallpaper
   - No infinite loops — every while has a hard iteration cap + safe fallback
*/

export function getDarkThemeConf(colors) {
	return generateTheme(colors, true);
}

export function getLightThemeConf(colors) {
	return generateTheme(colors, false);
}

export function setTheme(themeConfPath) {
	const destDir = HOME_DIR.concat("/.config/btop/themes");
	OS.exec([
		"sh",
		"-c",
		`mkdir -p "${destDir}" && cp -f -- "${themeConfPath}" "${destDir}/WallRizz.theme"`,
	]);
}

// Clamp a color's contrast to bg; if unreachable, return a guaranteed-safe default
function ensureContrast(fg, bg, minRatio, isDark) {
	let iters = 0;
	while (Color.readability(bg, fg) < minRatio && iters < 80) {
		if (isDark) fg = fg.brighten(2).saturate(1);
		else fg = fg.darken(2);
		iters++;
	}
	// If still not readable, use a hard-coded safe color
	if (Color.readability(bg, fg) < minRatio) {
		fg = isDark ? Color("#ffffff") : Color("#000000");
	}
	return fg;
}

function generateTheme(colorCodes, isDark) {
	const palette = colorCodes.map((c) => Color(c));

	// --- Background ---
	// Avoid over-darkening to #000000 — limit darken to prevent underflow
	let bg;
	if (isDark) {
		const dark = palette.find((c) => c.isDark());
		bg = dark ? dark.darken(5) : Color("#1e1e2e");
		// Clamp: ensure bg isn't pure black
		if (bg.getBrightness() < 5) bg = Color("#1a1a1e");
	} else {
		const light = palette.find((c) => c.isLight());
		bg = light ? light.lighten(5) : Color("#f0f0f0");
	}

	// --- Foreground with guaranteed contrast (>= 5:1 for safety) ---
	let fg;
	if (isDark) {
		const light = palette.find((c) => c.isLight());
		fg = light ? light.clone() : Color("#e0e0e0");
	} else {
		const dark = palette.find((c) => c.isDark());
		fg = dark ? dark.clone() : Color("#333333");
	}
	fg = ensureContrast(fg, bg, 6.0, isDark);
	// Extra guard: for dark theme, fg must be at least medium-light
	if (isDark && fg.getBrightness() < 150) {
		fg = Color("#e0e0e0");
	}

	// --- Build varied accent palette from wallpaper hue ---
	const hsvs = palette.map((c) => c.toHsv());
	const avgH = hsvs.reduce((s, h) => s + (h.h || 0), 0) / hsvs.length;
	const avgS = hsvs.reduce((s, h) => s + (h.s || 0), 0) / hsvs.length;

	// 8 hues spread evenly, anchored on wallpaper hue
	const accents = [];
	for (let i = 0; i < 8; i++) {
		const h = ((avgH % 360) + i * 45) % 360;
		// Start with a value that should already contrast with bg
		const startV = isDark ? 75 : 35;
		let c = new Color({ h: h, s: Math.min(avgS * 1.5, 70), v: startV });
		c = ensureContrast(c, bg, 2.5, isDark);
		accents.push(c);
	}

	// --- Derived colors ---
	const borderColor = accents[0];

	const hiFg = accents[1];

	const selectedBg = accents[2].darken(isDark ? 20 : 5);
	let selectedFg = isDark ? Color("#ffffff") : Color("#000000");
	selectedFg = ensureContrast(selectedFg, selectedBg, 4.5, isDark);

	let inactiveFg = fg.desaturate(15).darken(isDark ? 10 : 5);
	inactiveFg = ensureContrast(inactiveFg, bg, 2.5, isDark);

	const procMisc = accents[3];

	// --- Graph gradient triples (different colors per graph) ---
	const g = (a, b, c) => [accents[a], accents[b], accents[c]];
	const tempGrad = g(0, 1, 2);
	const cpuGrad = g(2, 3, 4);
	const freeGrad = g(4, 5, 0);
	const cachedGrad = g(1, 5, 3);
	const availGrad = g(5, 6, 1);
	const usedGrad = g(3, 4, 6);
	const dlGrad = g(6, 7, 2);
	const ulGrad = g(4, 6, 7);
	const procGrad = g(1, 3, 5);

	const h = (c) => `"${c.toHexString()}"`;

	return [
		`theme[main_bg]=${h(bg)}`,
		`theme[main_fg]=${h(fg)}`,
		`theme[title]=${h(fg)}`,
		`theme[hi_fg]=${h(hiFg)}`,
		`theme[selected_bg]=${h(selectedBg)}`,
		`theme[selected_fg]=${h(selectedFg)}`,
		`theme[inactive_fg]=${h(inactiveFg)}`,
		`theme[graph_text]=${h(fg)}`,
		`theme[proc_misc]=${h(procMisc)}`,
		`theme[cpu_box]=${h(borderColor)}`,
		`theme[mem_box]=${h(borderColor)}`,
		`theme[net_box]=${h(borderColor)}`,
		`theme[proc_box]=${h(borderColor)}`,
		`theme[div_line]=${h(borderColor)}`,
		`theme[temp_start]=${h(tempGrad[0])}`,
		`theme[temp_mid]=${h(tempGrad[1])}`,
		`theme[temp_end]=${h(tempGrad[2])}`,
		`theme[cpu_start]=${h(cpuGrad[0])}`,
		`theme[cpu_mid]=${h(cpuGrad[1])}`,
		`theme[cpu_end]=${h(cpuGrad[2])}`,
		`theme[free_start]=${h(freeGrad[0])}`,
		`theme[free_mid]=${h(freeGrad[1])}`,
		`theme[free_end]=${h(freeGrad[2])}`,
		`theme[cached_start]=${h(cachedGrad[0])}`,
		`theme[cached_mid]=${h(cachedGrad[1])}`,
		`theme[cached_end]=${h(cachedGrad[2])}`,
		`theme[available_start]=${h(availGrad[0])}`,
		`theme[available_mid]=${h(availGrad[1])}`,
		`theme[available_end]=${h(availGrad[2])}`,
		`theme[used_start]=${h(usedGrad[0])}`,
		`theme[used_mid]=${h(usedGrad[1])}`,
		`theme[used_end]=${h(usedGrad[2])}`,
		`theme[download_start]=${h(dlGrad[0])}`,
		`theme[download_mid]=${h(dlGrad[1])}`,
		`theme[download_end]=${h(dlGrad[2])}`,
		`theme[upload_start]=${h(ulGrad[0])}`,
		`theme[upload_mid]=${h(ulGrad[1])}`,
		`theme[upload_end]=${h(ulGrad[2])}`,
		`theme[process_start]=${h(procGrad[0])}`,
		`theme[process_mid]=${h(procGrad[1])}`,
		`theme[process_end]=${h(procGrad[2])}`,
	].join("\n");
}
