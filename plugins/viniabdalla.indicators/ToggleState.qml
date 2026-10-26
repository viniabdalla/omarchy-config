pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared fallback state for the indicators whose first-party service the shell
// withholds from cloned bar widgets (nightlight, notifications, idle). Every
// indicator instance (active and inactive block, per monitor) reads this one
// copy, so they cannot disagree about what is on.
QtObject {
  id: state

  property bool nightlight: false
  property bool dnd: false
  property bool stayAwake: false

  function refresh() {
    if (!nightlightProc.running) nightlightProc.running = true
    if (!dndProc.running) dndProc.running = true
    if (!idleProc.running) idleProc.running = true
  }

  // Flip optimistically, run the command, then read back the real state.
  function toggleNightlight() {
    state.nightlight = !state.nightlight
    Quickshell.execDetached(["omarchy-shell", "nightlight", "toggle"])
    recheck.restart()
  }

  function toggleDnd() {
    state.dnd = !state.dnd
    Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"])
    recheck.restart()
  }

  function toggleStayAwake() {
    state.stayAwake = !state.stayAwake
    Quickshell.execDetached(["omarchy-shell", "idle", "toggle"])
    recheck.restart()
  }

  property Process nightlightProc: Process {
    command: ["omarchy-shell", "nightlight", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { state.nightlight = JSON.parse(text).enabled === true } catch (e) {}
      }
    }
  }

  property Process dndProc: Process {
    command: ["omarchy-shell", "notifications", "dndState"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: state.dnd = text.trim() === "on"
    }
  }

  property Process idleProc: Process {
    command: ["omarchy-shell", "idle", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { state.stayAwake = JSON.parse(text).stayAwake === true } catch (e) {}
      }
    }
  }

  property Timer recheck: Timer {
    interval: 1500
    onTriggered: state.refresh()
  }

  Component.onCompleted: refresh()
}
