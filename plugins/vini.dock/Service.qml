import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property int iconSize: Style.space(34)
  readonly property int itemSize: Style.space(50)
  readonly property int dockPadding: Style.space(7)
  readonly property int dockGap: Style.space(4)
  readonly property int dockMargin: Style.space(10)
  readonly property int dockHeight: itemSize + dockPadding * 2
  readonly property int revealHandle: Style.space(5)
  readonly property int triggerHeight: Style.space(18)
  readonly property int maxDockWidth: Math.min(panel.width - Style.space(24), Style.space(560))
  property bool dockHovered: false
  readonly property var pinnedCandidates: [
    ["com.google.Chrome", "google-chrome", "chromium"],
    ["foot", "footclient", "foot-server"],
    ["org.gnome.Nautilus"],
    ["steam"],
    ["obsidian"],
    ["Discord"],
    ["WhatsApp"],
    ["YouTube"]
  ]
  property var pinnedApps: []

  function appLibrary() {
    return shell && shell.appLibrary ? shell.appLibrary : null
  }

  function allApps() {
    var library = appLibrary()
    var rows = library ? library.sortedEntries("") : []
    var entries = []
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i] && rows[i].entry ? rows[i].entry : rows[i]
      if (entry) entries.push(entry)
    }
    return entries
  }

  function appName(entry) {
    var library = appLibrary()
    return library ? library.entryName(entry) : String((entry && entry.name) || "")
  }

  function appIcon(entry) {
    var library = appLibrary()
    return library ? library.iconSource(entry ? entry.icon : "") : ""
  }

  function launch(entry) {
    if (!entry) return
    var library = appLibrary()
    if (library) library.launch(entry.id, appName(entry))
  }

  function resolvePinnedApps() {
    var entries = allApps()
    var byId = ({})
    var result = []

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (entry && entry.id) byId[String(entry.id)] = entry
    }

    for (var group = 0; group < pinnedCandidates.length; group++) {
      var candidates = pinnedCandidates[group]
      for (var c = 0; c < candidates.length; c++) {
        var match = byId[candidates[c]]
        if (match) {
          result.push(match)
          break
        }
      }
    }

    return result
  }

  function refreshPinnedApps() {
    var next = resolvePinnedApps()
    pinnedApps = next
    if (next.length > 0) retryTimer.stop()
  }

  onShellChanged: {
    var library = appLibrary()
    if (library) library.refreshIcons()
    refreshPinnedApps()
    retryTimer.start()
  }

  Connections {
    target: appLibrary()
    function onAppsChanged() {
      root.refreshPinnedApps()
    }
  }

  Component.onCompleted: {
    var library = appLibrary()
    if (library) library.refreshIcons()
    refreshPinnedApps()
    retryTimer.start()
  }

  Timer {
    id: retryTimer
    interval: 500
    repeat: true
    running: false
    onTriggered: root.refreshPinnedApps()
  }

  PanelWindow {
    id: panel
    visible: root.pinnedApps.length > 0
    anchors {
      left: true
      right: true
      bottom: true
    }
    implicitHeight: root.dockHeight + root.dockMargin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vini-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: inputRegion }

    Item {
      id: inputRegion
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }
      height: root.dockHovered ? panel.height : root.triggerHeight

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.dockHovered = true
        onExited: root.dockHovered = false
      }
    }

    Rectangle {
      id: dock
      width: Math.min(root.maxDockWidth, content.implicitWidth + root.dockPadding * 2)
      height: root.dockHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.dockHovered ? root.dockMargin : -(root.dockHeight - root.revealHandle)
      radius: Math.max(Style.cornerRadius, Style.space(8))
      color: Util.alpha(Color.popups.background, 0.94)
      border.width: Math.max(1, Style.space(1))
      border.color: Color.popups.border

      Behavior on anchors.bottomMargin {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
      }

      Row {
        id: content
        anchors.centerIn: parent
        spacing: root.dockGap

        Repeater {
          model: root.pinnedApps

          delegate: Item {
            id: launcher
            required property var modelData

            width: root.itemSize
            height: root.itemSize

            Rectangle {
              anchors.fill: parent
              radius: Math.max(Style.cornerRadius, Style.space(7))
              color: mouse.containsMouse ? Style.hoverFill : "transparent"

              Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
              }
            }

            Image {
              anchors.centerIn: parent
              width: root.iconSize
              height: root.iconSize
              source: root.appIcon(launcher.modelData)
              sourceSize.width: root.iconSize
              sourceSize.height: root.iconSize
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: root.launch(launcher.modelData)
            }
          }
        }
      }
    }
  }
}
