pragma Singleton
import QtQuick
import Quickshell.Io

// One shared `voxtype status --follow` for every Dictation indicator instance
// (the widget is instantiated per monitor and per orientation).
QtObject {
  property string raw: ""

  property Process follower: Process {
    command: ["bash", "-c", "omarchy-voxtype-status"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { DictationState.raw = data }
    }
  }
}
