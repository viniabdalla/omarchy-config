import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Ui.BarWidget {
  id: root

  moduleName: "viniabdalla.peripheral-battery"

  property string label: ""
  property string tooltip: "Peripheral batteries"
  property var items: []
  property bool hasData: items.length > 0
  readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/viniabdalla.peripheral-battery/peripheral-battery-status"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  implicitWidth: root.hasData ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight
  visible: root.hasData

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    tooltipText: root.tooltip
    fontSize: Commons.Style.font.caption
    fixedWidth: root.vertical ? -1 : Math.max(Commons.Style.space(42), root.label.length * Commons.Style.space(7))
    fixedHeight: root.vertical ? Commons.Style.space(42) : -1
    labelVisible: true
    hasVisualContent: true
    dimmed: !root.hasData

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton || mouseButton === Qt.RightButton) root.refresh()
    }
  }

  Process {
    id: statusProc
    command: [root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.label = data.label || ""
          root.tooltip = data.tooltip || "Peripheral batteries"
          root.items = data.items || []
        } catch (e) {
          root.label = ""
          root.tooltip = "Peripheral battery data unavailable"
          root.items = []
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "peripheral-battery"
    function refresh(): void { root.broadcast("refresh") }
  }
}
