import QtQuick
import Quickshell
import Quickshell.Io

// Data layer. Owns exactly two things: the state file the daemon publishes and
// the CLI that sends commands back to it. No Google logic lives here — the
// daemon is the only thing that ever talks to Google.
Item {
  id: root

  property var settings: ({})

  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || `${Quickshell.env("HOME")}/.local/share`) + "/agenda-flutuante"
  readonly property string statePath: `${dataDir}/state.json`
  readonly property string ctlPath: `${Quickshell.env("HOME")}/Projects/02 - GITHUB/AGENDA_FLUTUANTE/daemon/agenda-ctl.cjs`

  // Whole published document, straight from the daemon.
  property var state: ({})

  readonly property bool daemonAlive: !!state && state.updatedAt !== undefined
  readonly property bool connected: !!state && state.connected === true
  readonly property string syncStatus: state && state.syncStatus ? state.syncStatus : "Aguardando o daemon"
  readonly property var current: state && state.current ? state.current : null
  readonly property var counts: state && state.counts ? state.counts : ({ pending: 0, done: 0, overdue: 0, events: 0 })

  property bool busy: false
  property string lastError: ""

  // Priority and category tables for the quick task form, owned by the daemon.
  readonly property var quickOptions: state && state.quickOptions ? state.quickOptions : ({ priorities: [], categories: [] })

  // Tells the panel how a command ended, so the quick task form knows when to
  // close. `op` is the first CLI argument.
  signal finished(string op, bool ok)
  property string runningOp: ""
  // A create sent while a sync is running waits here instead of being dropped;
  // opening the panel starts a sync, so that collision is the common case.
  property var queuedArgs: null

  // The daemon publishes everything; the widget's settings decide what is worth
  // showing. Filtering here keeps Panel.qml free of policy.
  readonly property var items: {
    var all = (state && state.items) ? state.items : []
    var showEvents = setting("showEvents", true)
    var hideCompleted = setting("hideCompleted", false)
    var out = []
    for (var i = 0; i < all.length; i++) {
      var item = all[i]
      if (!showEvents && item.kind === "event") continue
      if (hideCompleted && item.completed) continue
      out.push(item)
    }
    return out
  }

  // The day is what the panel is for. Everything that fell off it is a
  // backlog, and a backlog 30 items deep would bury today under itself, so the
  // two are kept apart and the panel reveals the second on request.
  readonly property var todayItems: splitItems(false)
  readonly property var overdueItems: splitItems(true)

  function splitItems(overdue) {
    var out = []
    for (var i = 0; i < items.length; i++) {
      var isOverdue = items[i].overdueDays > 0
      if (isOverdue === overdue) out.push(items[i])
    }
    return out
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: root.state = root.parseState(text())
    // A missing file is the normal state before the daemon's first run, not an
    // error worth surfacing: daemonAlive stays false and the panel says so.
    onLoadFailed: root.state = ({})
  }

  function parseState(raw) {
    try {
      return JSON.parse(String(raw || "{}")) || ({})
    } catch (e) {
      return ({})
    }
  }

  Process {
    id: ctl
    running: false
    onExited: function(code) {
      root.busy = false
      // The daemon rewrites state.json on every successful command, so a
      // success needs no reload here; FileView already saw it.
      if (code !== 0 && root.lastError === "") root.lastError = "Falha ao executar o comando."
      var op = root.runningOp
      root.runningOp = ""
      root.finished(op, code === 0)
      if (root.queuedArgs) {
        var next = root.queuedArgs
        root.queuedArgs = null
        root.run(next)
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var message = String(text || "").trim()
        root.lastError = message
        if (message !== "") console.warn("agenda/ctl", message)
      }
    }
  }

  function run(args) {
    if (ctl.running) {
      if (args[0] === "create") {
        root.queuedArgs = args
        return true
      }
      console.warn("agenda/run", "ignorado, ctl ocupado:", args.join(" "))
      return false
    }
    root.lastError = ""
    root.busy = true
    root.runningOp = args[0]
    ctl.command = ["node", root.ctlPath].concat(args)
    console.warn("agenda/run", ctl.command.join(" "))
    ctl.running = true
    return true
  }

  function refresh() { return run(["sync"]) }
  function connect() { return run(["connect"]) }
  function setCompleted(id, completed) { return run([completed ? "done" : "undone", id]) }
  function pinNow(id) { return run(["now", id]) }
  function clearNow() { return run(["clear-now"]) }
  function createTask(priority, category, title) { return run(["create", priority, category, title]) }
}
