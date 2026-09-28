import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// Dockseid: a persistent, macOS-style pill dock. Declared as a keepLoaded
// "panel" plugin so the shell mounts it once at startup and it stays visible
// permanently, rather than being summoned/hidden like a popup.
Item {
  id: root

  property string stateDir: Quickshell.env("HOME") + "/.local/state/dockseid"
  property string statePath: root.stateDir + "/state.json"

  property var pinnedIds: []
  // The user's manual drag order — a flat list of dock-item keys covering
  // pinned and running-unpinned items alike. Empty until they reorder
  // anything, at which point it fully describes the visible arrangement.
  property var iconOrder: []
  property var settings: DockModel.defaultSettings()
  property bool stateLoaded: false
  property var surfaceItems: []

  // -------------------------------------------------------------- state io
  function persist() {
    if (!root.stateLoaded) return
    root.lastWritten = DockModel.serializeState({ pinned: root.pinnedIds, order: root.iconOrder, settings: root.settings })
    stateFile.setText(root.lastWritten)
  }

  // The file watcher also fires for our own writes; reloading those lets a
  // stale echo overwrite newer in-memory changes (e.g. mid slider drag).
  property string lastWritten: ""

  function loadState(text) {
    var state = DockModel.parseState(text)
    root.pinnedIds = state.pinned
    root.iconOrder = state.order
    root.settings = state.settings
    root.stateLoaded = true
    root.rebuildItems()
  }

  function registerSurface(surface) {
    var next = root.surfaceItems.slice()
    if (next.indexOf(surface) < 0) next.push(surface)
    root.surfaceItems = next
  }

  function unregisterSurface(surface) {
    var next = root.surfaceItems.slice()
    var idx = next.indexOf(surface)
    if (idx >= 0) next.splice(idx, 1)
    root.surfaceItems = next
  }

  function surfaceForScreen(screenName) {
    var wanted = String(screenName || "")
    if (wanted.length > 0) {
      for (var i = 0; i < root.surfaceItems.length; i++) {
        var surface = root.surfaceItems[i]
        if (surface && surface.screen && String(surface.screen.name || "") === wanted)
          return surface
      }
    }
    return root.surfaceItems.length > 0 ? root.surfaceItems[0] : null
  }

  function openSettings(screenName) {
    var surface = root.surfaceForScreen(screenName)
    if (!surface) return false
    surface.openSettingsFromExternal()
    return true
  }

  function toggleSettings(screenName) {
    var surface = root.surfaceForScreen(screenName)
    if (!surface) return false
    surface.toggleSettingsFromExternal()
    return true
  }

  IpcHandler {
    target: "io.github.silkvain.dockseid"
    function openSettings(): string { return root.openSettings() ? "ok" : "unknown" }
    function toggleSettings(): string { return root.toggleSettings() ? "ok" : "unknown" }
    function openSettingsOn(screenName: string): string { return root.openSettings(screenName) ? "ok" : "unknown" }
    function toggleSettingsOn(screenName: string): string { return root.toggleSettings(screenName) ? "ok" : "unknown" }
    function settings(): string { return root.openSettings() ? "ok" : "unknown" }
  }

  Process {
    id: ensureStateDir
    command: ["mkdir", "-p", root.stateDir]
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var t = text()
      if (root.stateLoaded && t === root.lastWritten) return
      root.loadState(t)
    }
    onLoadFailed: root.loadState("")
    onFileChanged: reload()
  }

  // ----------------------------------------------------- app/window model
  function resolveEntry(appId) {
    if (!appId) return null
    var byId = DesktopEntries.byId(appId)
    if (byId) return byId
    return DesktopEntries.heuristicLookup(appId)
  }

  // ------------------------------------------------- bundled icon library
  // Vector icons shipped in icons/ take priority over whatever the system icon
  // theme has; anything not in the library falls through to the system icon
  // (drawn as sharply as we can, see DockAppIcon). See icons/README.md.
  readonly property string iconDirUrl: Qt.resolvedUrl("icons/")
  property var iconLibrary: ({})
  onGlassBaseIsDarkChanged: root.rebuildItems()   // theme flipped light/dark: re-pick icon variants

  FileView {
    id: iconIndexFile
    path: decodeURIComponent(Qt.resolvedUrl("icons/index.json").toString().replace(/^file:\/\//, ""))
    printErrors: false
    onLoaded: { root.iconLibrary = DockModel.parseIconIndex(text()); root.rebuildItems() }
    onLoadFailed: root.iconLibrary = ({})
  }

  // ------------------------------------------------- Omarchy agent window
  // Windows from Omarchy's agent launcher all have the class org.omarchy.agent,
  // so which agent it is comes from Omarchy's own setting. The mark comes from
  // (1) this plugin's icon library ("agent-<id>"), then (2) Omarchy's agents
  // plugin assets, then (3) a plain terminal icon.
  readonly property string omarchyBaseDir: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string agentAssetsDir: root.omarchyBaseDir + "/shell/plugins/agents/assets"
  property string defaultAgent: ""
  property var agentAssets: []
  onDefaultAgentChanged: root.rebuildItems()
  onAgentAssetsChanged: root.rebuildItems()

  FileView {
    id: defaultAgentFile
    path: Quickshell.env("HOME") + "/.config/omarchy/defaults/agent"
    watchChanges: true
    printErrors: false
    onLoaded: root.defaultAgent = text().trim()
    onLoadFailed: root.defaultAgent = ""
    onFileChanged: reload()
  }

  Process {
    id: agentAssetsProc
    command: ["ls", "-1", root.agentAssetsDir]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.agentAssets = text.split("\n").filter(function(f) { return f.length > 0 })
    }
  }

  function agentIcon() {
    var id = root.defaultAgent
    var bundled = root.libraryIcon("agent-" + id, null)
    if (bundled.length > 0) return bundled
    var asset = DockModel.agentAssetFile(id, root.agentAssets, root.glassBaseIsDark)
    if (asset.length > 0) return Util.fileUrl(root.agentAssetsDir + "/" + asset)
    return root.freshIcon(Quickshell.iconPath("utilities-terminal", true))
  }

  function libraryIcon(key, entry) {
    // glassBaseIsDark is the dock's own theme brightness (custom background
    // in Custom mode, system background otherwise); pure black/white icons
    // ship in both colours and take the inverse of it.
    var file = DockModel.lookupLibraryIcon(root.iconLibrary, [key, entry ? entry.id : "", entry ? entry.icon : ""], root.glassBaseIsDark)
    return file.length > 0 ? root.iconDirUrl + file : ""
  }

  // ----------------------------------------------- system icon theme changes
  // Omarchy recolours the icon theme (Yaru-*) with `gsettings` on every theme
  // switch. Icons are requested once as image://icon/<name>, and the image cache
  // is keyed by that URL, so without a nudge the dock keeps showing the old
  // theme's icons until the shell restarts. When the setting changes, bump a
  // revision that makes each system icon URL unique so they're all re-requested.
  property int iconThemeRevision: 0
  onIconThemeRevisionChanged: root.rebuildItems()

  Process {
    id: iconThemeMonitor
    command: ["gsettings", "monitor", "org.gnome.desktop.interface", "icon-theme"]
    running: true
    stdout: SplitParser {
      // One line per change ("icon-theme: 'Yaru-red'"). Qt's own theme lookup
      // updates asynchronously, so give it a moment before re-requesting.
      onRead: iconThemeRefresh.restart()
    }
  }
  Timer {
    id: iconThemeRefresh
    interval: 600
    onTriggered: root.iconThemeRevision++
  }

  // `?path=` is Quickshell's optional fallback-directory suffix; it is only used
  // if the theme has no such icon, so here it just makes the URL unique per
  // revision without changing which icon is found.
  function freshIcon(path) {
    if (root.iconThemeRevision === 0 || path.indexOf("image://icon/") !== 0 || path.indexOf("?") !== -1) return path
    return path + "?path=/dockseid/icon-refresh-" + root.iconThemeRevision
  }

  function iconForKey(key, entry) {
    if (key === DockModel.AGENT_APP_ID && root.defaultAgent.length > 0) return root.agentIcon()
    var bundled = root.libraryIcon(key, entry)
    if (bundled.length > 0) return bundled
    var icon = (entry && entry.icon) ? entry.icon : ""
    var path = icon.length > 0 ? Quickshell.iconPath(icon, true) : ""
    if (path.length > 0) return root.freshIcon(path)
    path = Quickshell.iconPath(key, true)
    if (path.length > 0) return root.freshIcon(path)
    return root.freshIcon(Quickshell.iconPath("application-x-executable", true))
  }

  function nameForKey(key, entry) {
    if (key === DockModel.AGENT_APP_ID && root.defaultAgent.length > 0) return DockModel.agentName(root.defaultAgent)
    if (entry && entry.name && String(entry.name).length > 0) return entry.name
    // Chromium --app window with no matching desktop entry: its raw class
    // ("brave-host__path-Default") is unreadable, so show just the host.
    if (String(key).indexOf("__") !== -1) return String(key).split("__")[0].replace(root.browserPrefix, "")
    return key
  }

  // ------------------------------------------------- Chromium web-app windows
  // Web apps launched via Omarchy (omarchy-launch-webapp, or a raw
  // `chromium --app=URL`) open windows whose class is
  // "<browser>-<host>__<path>-<profile>" (leading slash dropped, "/" -> "_",
  // query/fragment dropped) — never the desktop entry's id, so they'd show up
  // as a separate icon. Matching that class back to the entry whose Exec URL
  // produces it lets the window group under the pinned/installed entry.
  readonly property var browserPrefix: /^(?:google-chrome|microsoft-edge|brave|chromium|chrome|opera|vivaldi|helium)-/

  function webAppUrl(entry) {
    var cmd = String(entry.execString || "")
    var m = cmd.match(/omarchy-launch-webapp\s+["']?([^\s"']+)/) || cmd.match(/--app=["']?([^\s"']+)/)
    return m ? m[1] : ""
  }

  function webAppSignature(url) {
    var m = url.match(/^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)([^?#]*)/i)
    if (!m) return null
    var host = m[1].toLowerCase()
    return { host: host, sig: host + "__" + m[2].replace(/^\//, "").replace(/\//g, "_").toLowerCase() }
  }

  function buildWebAppIndex() {
    var out = []
    var apps = DesktopEntries.applications.values || []
    for (var i = 0; i < apps.length; i++) {
      var s = root.webAppSignature(root.webAppUrl(apps[i]))
      if (s) out.push({ entry: apps[i], host: s.host, sig: s.sig })
    }
    return out
  }

  // Exact host+path match wins; otherwise a host-only match is accepted when
  // exactly one entry uses that host (two apps on the same site stay apart).
  function matchWebApp(appId, index) {
    var id = String(appId || "").toLowerCase()
    if (id.indexOf("__") === -1) return null
    var hostMatches = []
    for (var i = 0; i < index.length; i++) {
      if (id.indexOf("-" + index[i].sig + "-") !== -1) return index[i].entry
      if (id.indexOf("-" + index[i].host + "__") !== -1) hostMatches.push(index[i].entry)
    }
    return hostMatches.length === 1 ? hostMatches[0] : null
  }

  // Only apps that explicitly declare an XDG "new window" action get one in
  // the dock's context menu — never a blind re-launch of the app's normal
  // Exec line. That's deliberate: a generic re-launch is exactly what causes
  // trouble for single-instance apps (Steam) or apps with their own internal
  // window management (DaVinci Resolve) that never publish such an action
  // and so are correctly left without the option.
  function findNewWindowAction(entry) {
    if (!entry || !entry.actions) return null
    var actions = entry.actions
    for (var i = 0; i < actions.length; i++) {
      var a = actions[i]
      var id = String(a.id || "").toLowerCase()
      var name = String(a.name || "").toLowerCase()
      var idMatch = id.indexOf("new") !== -1 && id.indexOf("window") !== -1
      var nameMatch = name.indexOf("new") !== -1 && name.indexOf("window") !== -1
      if (idMatch || nameMatch) return a
    }
    return null
  }

  function newWindowForItem(item) {
    if (item && item.newWindowAction) item.newWindowAction.execute()
  }

  property var dockItems: []

  // Pinned apps first (in pin order), then any running-but-unpinned apps in
  // first-seen order — this is just the fallback for anything the user
  // hasn't manually dragged yet; sortByOrder() below applies their actual
  // saved arrangement on top of it. Every open window is grouped under its
  // app's single dock slot instead of getting its own icon.
  function rebuildItems() {
    var groups = ({})
    var discoveryOrder = []
    var toplevels = ToplevelManager.toplevels.values
    var webApps = null // built lazily, only if a Chromium --app window is open

    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      var entry = null
      if (String(t.appId || "").indexOf("__") !== -1) {
        if (!webApps) webApps = root.buildWebAppIndex()
        entry = root.matchWebApp(t.appId, webApps)
      }
      if (!entry) entry = root.resolveEntry(t.appId)
      var key = entry ? entry.id : t.appId
      if (!groups[key]) { groups[key] = { key: key, entry: entry, toplevels: [] }; discoveryOrder.push(key) }
      groups[key].toplevels.push(t)
    }

    var items = []
    var consumed = ({})

    for (var p = 0; p < root.pinnedIds.length; p++) {
      var pid = root.pinnedIds[p]
      var g = groups[pid]
      var entry2 = g ? g.entry : DesktopEntries.byId(pid)
      items.push({
        key: pid,
        name: root.nameForKey(pid, entry2),
        iconSource: root.iconForKey(pid, entry2),
        pinned: true,
        toplevels: g ? g.toplevels : [],
        running: !!g && g.toplevels.length > 0,
        count: g ? g.toplevels.length : 0,
        newWindowAction: root.findNewWindowAction(entry2)
      })
      consumed[pid] = true
    }

    for (var o = 0; o < discoveryOrder.length; o++) {
      var k = discoveryOrder[o]
      if (consumed[k]) continue
      var grp = groups[k]
      items.push({
        key: k,
        name: root.nameForKey(k, grp.entry),
        iconSource: root.iconForKey(k, grp.entry),
        pinned: false,
        toplevels: grp.toplevels,
        running: true,
        count: grp.toplevels.length,
        newWindowAction: root.findNewWindowAction(grp.entry)
      })
    }

    root.dockItems = DockModel.sortByOrder(items, root.iconOrder)
  }

  // Called once a drag-reorder gesture on the dock completes, with the full
  // new key sequence of whatever was visible during the drag.
  function reorderItems(orderKeys) {
    root.iconOrder = orderKeys.slice()
    root.persist()
    root.rebuildItems()
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.rebuildItems() }
  }
  // A window's appId can arrive (or change) after it's first listed, which
  // moves it to a different dock slot without the list itself changing.
  Instantiator {
    model: ToplevelManager.toplevels
    delegate: Connections {
      required property var modelData
      target: modelData
      function onAppIdChanged() { root.rebuildItems() }
    }
  }
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuildItems() }
  }

  // --------------------------------------------------------- pin actions
  function isPinned(key) { return root.pinnedIds.indexOf(key) !== -1 }

  function togglePin(key) {
    var next = root.pinnedIds.slice()
    var idx = next.indexOf(key)
    if (idx === -1) next.push(key)
    else next.splice(idx, 1)
    root.pinnedIds = next
    root.persist()
    root.rebuildItems()
  }

  function pinApp(id) {
    if (root.isPinned(id)) return
    var next = root.pinnedIds.slice()
    next.push(id)
    root.pinnedIds = next
    root.persist()
    root.rebuildItems()
  }

  // ------------------------------------------------------ window actions
  function launchItem(item) {
    var entry = DesktopEntries.byId(item.key) || DesktopEntries.heuristicLookup(item.key)
    if (entry) entry.execute()
  }

  // Click behavior: launch when nothing is open, minimize/restore a single
  // window, or cycle through a group's windows one at a time (the same
  // "click again to get to the next one" grouping Windows uses).
  function cycleOrActivate(item) {
    var list = item.toplevels
    if (list.length === 0) { root.launchItem(item); return }

    if (list.length === 1) {
      var only = list[0]
      if (only.minimized) { only.minimized = false; only.activate() }
      else if (only.activated) { only.minimized = true }
      else { only.activate() }
      return
    }

    var activeIdx = -1
    for (var i = 0; i < list.length; i++) {
      if (list[i].activated) { activeIdx = i; break }
    }
    var nextIdx = (activeIdx + 1) % list.length
    list[nextIdx].minimized = false
    list[nextIdx].activate()
  }

  function activateToplevel(t) {
    t.minimized = false
    t.activate()
  }

  function quitItem(item) {
    for (var i = 0; i < item.toplevels.length; i++) item.toplevels[i].close()
  }

  // ------------------------------------------------------------ settings
  function setShape(value) {
    root.settings = Object.assign({}, root.settings, { shape: DockModel.normalizeShape(value) })
    root.persist()
  }
  function setOpacity(value) {
    root.settings = Object.assign({}, root.settings, { opacity: DockModel.clampOpacity(value) })
    root.persist()
  }
  function setMagnify(value) {
    root.settings = Object.assign({}, root.settings, { magnify: !!value })
    root.persist()
  }
  function setGlass(value) {
    root.settings = Object.assign({}, root.settings, { glass: !!value })
    root.persist()
  }
  function setBlur(value) {
    root.settings = Object.assign({}, root.settings, { blur: DockModel.clampBlur(value) })
    root.persist()
  }
  // Switches one color (background / border / logo) between the system theme and
  // the user's own; the others are untouched.
  function setUseCustom(kind, on) {
    var patch = {}
    if (kind === "background") patch.useCustomBackground = !!on
    else if (kind === "border") patch.useCustomBorder = !!on
    else if (kind === "logo") {
      patch.useCustomLogo = !!on
      // First time custom: start from the color currently shown.
      if (on && root.settings.customLogo === "") {
        var seed = String(root.dockAccent).toLowerCase()
        patch.customLogo = DockModel.isValidHex(seed) ? seed : "#ffffff"
      }
    } else return
    root.settings = Object.assign({}, root.settings, patch)
    root.persist()
  }
  function setCustomColor(kind, hex) {
    var next = Object.assign({}, root.settings)
    if (kind === "background") next.customBackground = DockModel.normalizeHex(hex, next.customBackground)
    else if (kind === "border") next.customBorder = DockModel.normalizeHex(hex, next.customBorder)
    else if (kind === "logo") next.customLogo = DockModel.normalizeHex(hex, next.customLogo)
    root.settings = next
    root.persist()
  }
  function setPosition(value) {
    root.settings = Object.assign({}, root.settings, { position: DockModel.normalizePosition(value) })
    root.persist()
  }
  function setMonitor(value) {
    root.settings = Object.assign({}, root.settings, { monitor: DockModel.normalizeMonitor(value) })
    root.persist()
  }
  function setVisibility(value) {
    root.settings = Object.assign({}, root.settings, { visibility: DockModel.normalizeVisibility(value) })
    root.persist()
  }
  function setSize(value) {
    root.settings = Object.assign({}, root.settings, { size: DockModel.clampSize(value) })
    root.persist()
  }
  // Writes to whichever of edgeGapAutohide/edgeGapAlways matches the current
  // visibility mode, so the other mode's offset is left untouched.
  function setEdgeGap(value) {
    var key = root.settings.visibility === "always" ? "edgeGapAlways" : "edgeGapAutohide"
    var patch = {}
    patch[key] = DockModel.clampEdgeGap(value, root.settings[key])
    root.settings = Object.assign({}, root.settings, patch)
    root.persist()
  }
  function setBorderEnabled(value) {
    root.settings = Object.assign({}, root.settings, { borderEnabled: !!value })
    root.persist()
  }
  function setBorderWidth(value) {
    root.settings = Object.assign({}, root.settings, { borderWidth: DockModel.clampBorderWidth(value) })
    root.persist()
  }
  function setShowInFullscreen(value) {
    root.settings = Object.assign({}, root.settings, { showInFullscreen: !!value })
    root.persist()
  }
  function setShowWhenEmpty(value) {
    root.settings = Object.assign({}, root.settings, { showWhenEmpty: !!value })
    root.persist()
  }

  // ------------------------------------------------------ wallpaper (blur)
  // The dock blurs its own copy of the wallpaper (a compositor can't blur
  // behind a layer surface per-surface with adjustable strength), so it needs
  // the current image's path. Omarchy keeps that as a symlink that changes on
  // theme/background switches; re-resolve it periodically, but only while blur
  // is actually on.
  readonly property string wallpaperLink: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string wallpaperPath: ""
  readonly property string wallpaperUrl: Util.fileUrl(root.wallpaperPath)

  Process {
    id: wallpaperProc
    command: ["readlink", "-f", root.wallpaperLink]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.trim()
        if (p.length > 0 && p !== root.wallpaperPath) root.wallpaperPath = p
      }
    }
  }
  Timer {
    interval: 4000
    repeat: true
    running: root.settings.blur > 0 || root.settings.glass
    triggeredOnStart: true
    onTriggered: if (!wallpaperProc.running) wallpaperProc.running = true
  }

  // Each color follows qs.Commons.Color (and thus the active Omarchy theme)
  // unless the user explicitly opted that one into their own color.
  // Glass mode swaps the user's opacity for a fixed, very light tint so the
  // blurred wallpaper behind reads as frosted glass.
  readonly property color glassBase: root.settings.useCustomBackground ? root.settings.customBackground : Color.background
  readonly property bool glassBaseIsDark: Qt.color(root.glassBase).hslLightness < 0.5
  readonly property real effectiveOpacity: root.settings.glass ? (root.glassBaseIsDark ? 0.10 : 0.14) : root.settings.opacity
  readonly property color dockBackground: root.settings.useCustomBackground
    ? Util.alpha(root.settings.customBackground, root.effectiveOpacity)
    : Util.alpha(Color.background, root.effectiveOpacity)
  // The accent always follows the system theme; only background and outline are customizable.
  readonly property color dockAccent: Color.accent
  readonly property color dockForeground: Color.foreground
  readonly property color dockBorder: root.settings.useCustomBorder ? root.settings.customBorder : Color.popups.border
  // The Omarchy logo button: the system accent, or the user's own color when
  // they've set one (muted theme accents can make it hard to see).
  readonly property color dockLogo: root.settings.useCustomLogo ? root.settings.customLogo : root.dockAccent

  // The pill's fixed cross-axis size, in both the horizontal (top/bottom) and
  // vertical (left/right) orientations — DockSurface swaps which axis this
  // maps to, but the corner radius always derives from it so the pill reads
  // as a stadium shape either way.
  readonly property real thickness: Math.round(Style.space(60) * root.settings.size)
  readonly property real dockRadius: root.settings.shape === "square" ? 0
    : (root.settings.shape === "rounded" ? root.thickness / 4 : root.thickness / 2)

  readonly property var addAppEntries: {
    var out = []
    var apps = DesktopEntries.applications.values || []
    for (var i = 0; i < apps.length; i++) {
      var e = apps[i]
      if (e.noDisplay) continue
      if (root.isPinned(e.id)) continue
      out.push({ id: e.id, name: e.name, iconSource: root.iconForKey(e.id, e) })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return out
  }

  // Which screen(s) to mount a dock surface on: every screen, just the first
  // one, or a specific screen by name (falling back to the first screen if
  // that one was unplugged).
  readonly property var activeScreens: {
    var all = Quickshell.screens || []
    if (root.settings.monitor === "all") return all
    if (root.settings.monitor === "primary") return all.length > 0 ? [all[0]] : []
    for (var i = 0; i < all.length; i++) {
      if (all[i].name === root.settings.monitor) return [all[i]]
    }
    return all.length > 0 ? [all[0]] : []
  }

  // No "Primary"/"Default" entry here on purpose — with every real display
  // listed, the user can just pick the one they mean.
  readonly property var monitorOptions: {
    var out = [{ value: "all", label: "All monitors" }]
    var all = Quickshell.screens || []
    for (var i = 0; i < all.length; i++) out.push({ value: all[i].name, label: all[i].name })
    return out
  }

  Component.onCompleted: {
    ensureStateDir.running = true
    root.rebuildItems()
  }

  Variants {
    model: root.activeScreens

    DockSurface {
      required property var modelData
      screen: modelData
      controller: root
    }
  }
}
