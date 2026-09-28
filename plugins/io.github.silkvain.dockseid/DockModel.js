// Pure helpers for Dockseid's persisted state (~/.local/state/dockseid/state.json).
// No Quickshell/QML singleton access here — Dock.qml owns anything that
// needs DesktopEntries, Quickshell.iconPath, or ToplevelManager.

.pragma library

// Ship with the dock's best-feeling setup already on — someone installing
// Dockseid for the first time should get a fully-featured, tasteful dock
// immediately, with the tweak knobs there for whoever wants to deviate
// rather than being required to opt into what most people would want anyway.
function defaultSettings() {
  return {
    shape: "rounded",        // "square" | "rounded" | "pill"
    opacity: 0.35,            // dock surface alpha — 35%
    blur: 0.05,               // 0..1: blur of the wallpaper seen through the dock; 0 = off
    glass: false,             // frosted-glass look; overrides opacity, blur and outline while on
    magnify: false,           // macOS-style fisheye magnification of icons under the cursor
    // Each themeable color is its own choice: follow the system theme, or use
    // the user's color. The picked colors are kept when switching back, so
    // toggling never loses one.
    useCustomBackground: true,
    useCustomBorder: true,
    useCustomLogo: false,
    customBackground: "#585558",
    customBorder: "#413c3f",   // outline color, used when the outline is set to Custom
    customLogo: "",            // Omarchy logo button color in custom theme mode; "" = follow the theme accent
    position: "bottom",       // "bottom" | "top" | "left" | "right"
    monitor: "primary",       // "all" | "primary" | a specific screen name
    visibility: "autohide",   // "autohide" | "always"
    size: 0.8,                 // scale factor applied to icon/pill sizing — 80%
    // Tracked separately per visibility mode: a wide gap reads nicely for a
    // floating auto-hide dock, but the same gap in always-visible mode just
    // eats screen space for no reason since the dock isn't trying to look
    // "detached" there. Switching modes keeps each one's own last value
    // instead of carrying one over onto the other.
    edgeGapAutohide: 15,       // px gap kept clear of the physical screen edge
    edgeGapAlways: 10,
    borderEnabled: true,       // whether the pill draws an outline at all
    borderWidth: 1,            // px, uniform on every side when enabled
    // Off by default: the dock stays out of the way of a fullscreened app.
    // Turn it on and the dock still reveals on hover over the fullscreen window
    // (raised above it) without permanently occupying the screen.
    showInFullscreen: false,
    // On by default. Only relevant in auto-hide mode: when on, a screen whose
    // current workspace has no windows keeps the dock permanently shown there
    // instead of hiding it — nothing else is using that space anyway.
    // Irrelevant (and ignored) in always-visible mode, which is already
    // permanently shown regardless of what's open.
    showWhenEmpty: true
  }
}

function defaultState() {
  return { version: 1, pinned: [], order: [], settings: defaultSettings() }
}

function clampOpacity(value) {
  var n = Number(value)
  if (!isFinite(n)) return defaultSettings().opacity
  return Math.max(0.35, Math.min(1, n))
}

function clampBlur(value) {
  var n = Number(value)
  if (!isFinite(n)) return defaultSettings().blur
  return Math.max(0, Math.min(1, n))
}

function clampSize(value) {
  var n = Number(value)
  if (!isFinite(n)) return defaultSettings().size
  return Math.max(0.7, Math.min(1.6, n))
}

// Plain screen pixels, not run through Style.space() — this compensates for
// a physical bezel, which has nothing to do with the UI's font/spacing scale.
function clampEdgeGap(value, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback === undefined ? 0 : fallback
  return Math.max(0, Math.min(48, n))
}

function clampBorderWidth(value) {
  var n = Number(value)
  if (!isFinite(n)) return defaultSettings().borderWidth
  return Math.max(1, Math.min(6, n))
}

function normalizeShape(value) {
  return (value === "square" || value === "rounded" || value === "pill") ? value : "pill"
}

function normalizePosition(value) {
  return (value === "top" || value === "left" || value === "right") ? value : "bottom"
}

function normalizeMonitor(value) {
  var v = typeof value === "string" ? value.trim() : ""
  return v.length > 0 ? v : "primary"
}

function normalizeVisibility(value) {
  return value === "always" ? "always" : "autohide"
}

function isValidHex(value) {
  return typeof value === "string" && /^#[0-9A-Fa-f]{6}$/.test(value)
}

function normalizeHex(value, fallback) {
  return isValidHex(value) ? value : fallback
}

function normalizeSettings(raw) {
  var d = defaultSettings()
  var s = (raw && typeof raw === "object") ? raw : {}
  var legacyCustom = s.themeMode === "custom"
  return {
    shape: normalizeShape(s.shape),
    opacity: clampOpacity(s.opacity === undefined ? d.opacity : s.opacity),
    // Older state files had one shared themeMode ("custom" switched every color
    // at once); it becomes the starting value of each independent switch.
    useCustomBackground: s.useCustomBackground === undefined ? legacyCustom : !!s.useCustomBackground,
    useCustomBorder: s.useCustomBorder === undefined ? legacyCustom : !!s.useCustomBorder,
    customBackground: normalizeHex(s.customBackground, d.customBackground),
    // Older state files have no outline color; seed it from the old custom
    // accent (the accent is no longer configurable, but the outline used to be
    // derived from it), so upgrading keeps the colour they had.
    customBorder: normalizeHex(s.customBorder, normalizeHex(s.customAccent, d.customBorder)),
    // "" (never chosen) keeps following the theme's accent, so switching to
    // Custom doesn't change the logo until the user picks a color for it.
    customLogo: isValidHex(s.customLogo) ? s.customLogo : "",
    // The logo has no color of its own until one is picked, so it can only be
    // custom once it has one.
    useCustomLogo: isValidHex(s.customLogo) && (s.useCustomLogo === undefined ? legacyCustom : !!s.useCustomLogo),
    position: normalizePosition(s.position),
    monitor: normalizeMonitor(s.monitor),
    visibility: normalizeVisibility(s.visibility),
    blur: clampBlur(s.blur === undefined ? d.blur : s.blur),
    glass: s.glass === undefined ? d.glass : !!s.glass,
    magnify: s.magnify === undefined ? d.magnify : !!s.magnify,
    size: clampSize(s.size === undefined ? d.size : s.size),
    // s.edgeGap is the pre-split field (single shared gap) — if present and
    // the new per-mode fields aren't, seed both from it so upgrading from an
    // older state.json doesn't reset anyone's offset to the default.
    edgeGapAutohide: clampEdgeGap(
      s.edgeGapAutohide !== undefined ? s.edgeGapAutohide : (s.edgeGap !== undefined ? s.edgeGap : d.edgeGapAutohide),
      d.edgeGapAutohide),
    edgeGapAlways: clampEdgeGap(
      s.edgeGapAlways !== undefined ? s.edgeGapAlways : (s.edgeGap !== undefined ? s.edgeGap : d.edgeGapAlways),
      d.edgeGapAlways),
    borderEnabled: s.borderEnabled === undefined ? d.borderEnabled : !!s.borderEnabled,
    borderWidth: clampBorderWidth(s.borderWidth === undefined ? d.borderWidth : s.borderWidth),
    showInFullscreen: s.showInFullscreen === undefined ? d.showInFullscreen : !!s.showInFullscreen,
    showWhenEmpty: s.showWhenEmpty === undefined ? d.showWhenEmpty : !!s.showWhenEmpty
  }
}

// Where a popup should grow from, given which screen edge the dock itself is
// anchored to — always positioned clear of the dock, pointing back at it.
// Mirrors the bar's own tooltip placement math (Bar.qml's tooltipAnchor).
function anchorOffset(position, anchorWidth, anchorHeight, popupWidth, popupHeight, gap) {
  if (position === "top") return { x: anchorWidth / 2 - popupWidth / 2, y: anchorHeight + gap }
  if (position === "left") return { x: anchorWidth + gap, y: anchorHeight / 2 - popupHeight / 2 }
  if (position === "right") return { x: -popupWidth - gap, y: anchorHeight / 2 - popupHeight / 2 }
  return { x: anchorWidth / 2 - popupWidth / 2, y: -popupHeight - gap } // bottom (default)
}

function normalizePinned(raw) {
  if (!Array.isArray(raw)) return []
  var seen = ({})
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var id = String(raw[i] || "").trim()
    if (id.length === 0 || seen[id]) continue
    seen[id] = true
    out.push(id)
  }
  return out
}

// Same shape as pinned (a deduped list of dock-item keys) — kept as a
// separate name because it means something different: the user's manual
// drag order, covering pinned and running-unpinned items alike.
function normalizeOrder(raw) {
  return normalizePinned(raw)
}

// Arranges dockItems per the user's saved drag order. Anything not yet in
// `orderKeys` (an app the user has never dragged, e.g. freshly launched)
// keeps its place in `items`' existing order and is appended after the
// known ones — matching today's "pinned first, then first-seen" default
// for whatever hasn't been manually arranged.
function sortByOrder(items, orderKeys) {
  var rank = ({})
  for (var i = 0; i < orderKeys.length; i++) rank[orderKeys[i]] = i
  var known = []
  var unknown = []
  for (var j = 0; j < items.length; j++) {
    if (Object.prototype.hasOwnProperty.call(rank, items[j].key)) known.push(items[j])
    else unknown.push(items[j])
  }
  known.sort(function(a, b) { return rank[a.key] - rank[b.key] })
  return known.concat(unknown)
}

// Tolerant parse: malformed/missing fields fall back to defaults instead of
// throwing, so a corrupt state file never blocks the dock from rendering.
function parseState(rawText) {
  var parsed = null
  try { parsed = JSON.parse(rawText) } catch (e) { parsed = null }
  if (!parsed || typeof parsed !== "object") return defaultState()
  return {
    version: 1,
    pinned: normalizePinned(parsed.pinned),
    order: normalizeOrder(parsed.order),
    settings: normalizeSettings(parsed.settings)
  }
}

function serializeState(state) {
  var safe = {
    version: 1,
    pinned: normalizePinned(state ? state.pinned : []),
    order: normalizeOrder(state ? state.order : []),
    settings: normalizeSettings(state ? state.settings : null)
  }
  return JSON.stringify(safe, null, 2) + "\n"
}

// ------------------------------------------------------- hover window labels
// Browser and web-app windows report their page title (or a raw URL) as the
// window title, which makes a hover preview long and noisy. These shorten it
// to just the site name, or "New Window" when nothing is loaded.

// Plain browsers by class, plus Chromium --app windows (class contains "__").
function isBrowserWindow(appId) {
  var id = String(appId || "")
  if (id.indexOf("__") !== -1) return true
  return /^(?:google-chrome|microsoft-edge|brave|chromium|chrome|opera|vivaldi|helium|firefox|zen|librewolf|floorp)\b/i.test(id)
}

// "www.apple.com/uk/shop" -> "apple.com"; keeps "co.uk"-style suffixes whole.
function siteNameFromUrl(text) {
  var m = String(text).match(/^(?:[a-z][a-z0-9+.-]*:\/\/)?([^\/\s?#:]+\.[a-z]{2,})(?:[:\/?#].*)?$/i)
  if (!m) return ""
  var parts = m[1].toLowerCase().replace(/^www\./, "").split(".")
  var i = parts.length - 2
  if (i > 0 && /^(?:co|com|org|net|gov|ac|edu)$/.test(parts[i])) i--
  return parts.slice(Math.max(0, i)).join(".")
}

function shortWindowLabel(title) {
  var t = String(title || "").trim()
  // Drop a trailing " - Brave" / " — Mozilla Firefox" style browser suffix.
  t = t.replace(/\s+[-–—|]\s+(?:brave|google chrome|chromium|mozilla firefox|firefox|microsoft edge|vivaldi|opera|zen browser|librewolf|helium)(?:\s.*)?$/i, "").trim()
  if (t.length === 0 || /^(?:new tab|untitled|about:blank|start page|home)$/i.test(t)) return "New Window"

  var site = siteNameFromUrl(t)
  if (site.length > 0) return site

  // "Page title - Site" / "Site | Section | Page": the site name conventionally
  // sits at the end, so keep only the last segment.
  var segments = t.split(/\s+[-–—|·•]\s+/)
  var last = segments[segments.length - 1].trim()
  if (segments.length > 1 && last.length > 0) t = last
  return t.length > 24 ? t.slice(0, 23) + "…" : t
}

// ----------------------------------------------------------- speech bubble
// SVG path for a rounded body with a small triangular tail centered on one
// side, drawn as a single closed outline so a stroke wraps the tail cleanly.
// tailSide is the side the tail sticks out of ("top" | "bottom" | "left" |
// "right"); the body's top-left is at (bx, by), which the caller offsets by
// the tail height on top/left so the tail stays inside the item's bounds.
function bubblePath(bx, by, bw, bh, radius, tailW, tailH, tailSide) {
  // The tail's base must fit on the body's straight edge, so cap the corner
  // radius by whatever length is left on the tail's side once it's subtracted.
  var along = (tailSide === "left" || tailSide === "right") ? bh : bw
  var r = Math.max(0, Math.min(radius, bw / 2, bh / 2, (along - tailW) / 2))
  var hw = tailW / 2
  var cx = bx + bw / 2
  var cy = by + bh / 2
  var R = bx + bw
  var B = by + bh
  var arc = " A" + r + "," + r + " 0 0 1 "
  var p = "M" + (bx + r) + "," + by
  if (tailSide === "top") p += " L" + (cx - hw) + "," + by + " L" + cx + "," + (by - tailH) + " L" + (cx + hw) + "," + by
  p += " L" + (R - r) + "," + by + arc + R + "," + (by + r)
  if (tailSide === "right") p += " L" + R + "," + (cy - hw) + " L" + (R + tailH) + "," + cy + " L" + R + "," + (cy + hw)
  p += " L" + R + "," + (B - r) + arc + (R - r) + "," + B
  if (tailSide === "bottom") p += " L" + (cx + hw) + "," + B + " L" + cx + "," + (B + tailH) + " L" + (cx - hw) + "," + B
  p += " L" + (bx + r) + "," + B + arc + bx + "," + (B - r)
  if (tailSide === "left") p += " L" + bx + "," + (cy + hw) + " L" + (bx - tailH) + "," + cy + " L" + bx + "," + (cy - hw)
  p += " L" + bx + "," + (by + r) + arc + (bx + r) + "," + by + " Z"
  return p
}

// ------------------------------------------------------ icon magnification
// Fisheye layout for the icon strip. `pointer` is the cursor's position along
// the strip's primary axis (< 0 = not hovering: everything rests). Each icon
// scales up by a cosine bell of its distance from the cursor (up to maxScale
// within `radius` slots), the neighbours' spacing grows to make room, and the
// whole strip is squeezed back to its resting length so the dock itself never
// changes size. `pitch` is the resting distance between icon origins and
// `slot` the icon's own footprint (pitch minus the gap).
// Returns { origins: [...], scales: [...] } — origins are where each icon's
// top-left sits along the axis.
function magnifyLayout(count, pitch, slot, pointer, maxScale, radius) {
  var origins = []
  var scales = []
  var reach = pitch * radius
  var widths = []
  var total = 0
  for (var i = 0; i < count; i++) {
    var s = 1
    if (pointer >= 0) {
      var t = Math.abs(i * pitch + slot / 2 - pointer) / reach
      if (t < 1) s = 1 + (maxScale - 1) * 0.5 * (1 + Math.cos(Math.PI * t))
    }
    scales.push(s)
    widths.push(pitch * s)
    total += pitch * s
  }
  var k = total > 0 ? (count * pitch) / total : 1
  var run = 0
  for (var j = 0; j < count; j++) {
    origins.push(k * (run + widths[j] / 2) - (pitch - slot) / 2 - slot / 2)
    run += widths[j]
  }
  return { origins: origins, scales: scales }
}

// ------------------------------------------------------ bundled icon library
// icons/index.json maps an app key (desktop entry id, or its Icon= name) to an
// SVG file that ships with the plugin. A value is either a file name, or — for
// pure black/white artwork that would vanish on the wrong background — a pair:
//   { "icons": {
//       "obsidian": "obsidian.svg",
//       "X": { "onLight": "x-black.svg", "onDark": "x-white.svg" } } }
// "onLight" is the artwork to use when the dock's theme is light (dark art),
// "onDark" when it is dark (light art); if only one is given it's used for both.
// Only plain "name.svg" file names are accepted (no paths), so an index can
// never point outside the icons folder.
function isIconFileName(file) {
  return typeof file === "string" && /^[A-Za-z0-9._-]+\.svg$/.test(file) && file.indexOf("..") === -1
}

function parseIconIndex(text) {
  var out = ({})
  var parsed = null
  try { parsed = JSON.parse(text) } catch (e) { return out }
  var icons = parsed && typeof parsed === "object" ? parsed.icons : null
  if (!icons || typeof icons !== "object") return out
  for (var key in icons) {
    var v = icons[key]
    if (isIconFileName(v)) {
      out[key] = { onLight: v, onDark: v }
    } else if (v && typeof v === "object") {
      var light = isIconFileName(v.onLight) ? v.onLight : ""
      var dark = isIconFileName(v.onDark) ? v.onDark : ""
      if (light || dark) out[key] = { onLight: light || dark, onDark: dark || light }
    }
  }
  return out
}

// First key that has a bundled icon wins (callers pass most specific first).
// `dark` says whether the dock's theme is dark, which picks the artwork variant.
function lookupLibraryIcon(library, keys, dark) {
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    if (k && Object.prototype.hasOwnProperty.call(library, k)) return dark ? library[k].onDark : library[k].onLight
  }
  return ""
}

// ------------------------------------------------------- Omarchy agent window
// Every window opened by Omarchy's agent launcher shares one class, so the dock
// can't tell which agent it is from the window; the agent chosen in Omarchy's
// settings (~/.config/omarchy/defaults/agent) is what was launched.
var AGENT_APP_ID = "org.omarchy.agent"

var AGENT_NAMES = {
  "pi": "Pi", "omp": "Oh My Pi", "opencode": "OpenCode", "claude": "Claude Code",
  "codex": "Codex", "crush": "Crush", "grok": "Grok", "gemini": "Gemini",
  "openclaw": "OpenClaw", "hermes": "Hermes", "copilot": "GitHub Copilot",
  "muse": "Muse Code", "cursor-agent": "Cursor CLI"
}

function agentName(id) {
  return Object.prototype.hasOwnProperty.call(AGENT_NAMES, id) ? AGENT_NAMES[id] : (id || "Agent")
}

// Picks a mark from Omarchy's agents plugin assets by its own convention:
// "<id>.svg" is the white mark for dark surfaces, "<id>-light.svg" (when it
// exists) the dark twin for light surfaces, and a single file works on both.
// `assets` is the list of file names in that folder; returns "" if none fits.
function agentAssetFile(id, assets, dark) {
  if (!/^[A-Za-z0-9._-]+$/.test(String(id || ""))) return ""
  var has = function(f) { return assets.indexOf(f) !== -1 }
  if (!dark && has(id + "-light.svg")) return id + "-light.svg"
  if (has(id + ".svg")) return id + ".svg"
  return ""
}
