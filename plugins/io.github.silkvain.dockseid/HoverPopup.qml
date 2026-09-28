import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

// Single shared hover preview, reused for every dock slot (mirrors how the
// bar owns one tooltip window instead of one per widget). Shows the app name
// for a single instance, or a Windows-taskbar-style window list with a count
// when an app has more than one open window.
PopupWindow {
  id: popup

  property QtObject hostWindow: null
  // dockWindow (the surface anchorItem actually lives in) and its computed
  // on-screen origin — see DockSurface.qml's dockOriginX/Y comment. Wayland
  // gives no way to map a point from dockWindow straight into hostWindow
  // (a separate top-level surface), so the two are combined manually below
  // instead of mapping directly into hostWindow.
  property QtObject dockWindow: null
  property real originX: 0
  property real originY: 0
  property Item anchorItem: null
  property string dockPosition: "bottom"
  property string appName: ""
  property var toplevels: []

  signal activateInstance(var toplevel)

  // Whether the pointer is currently over this popup's own surface — DockSurface
  // watches this so leaving the trigger icon for the popup (to pick a window
  // from the list) doesn't immediately start the close countdown.
  property bool hovered: false

  readonly property int instanceCount: toplevels.length
  readonly property bool multiInstance: instanceCount > 1

  // Browser / web-app windows get a short site label ("apple.com", or "New
  // Window" when empty) instead of their full page title or URL.
  function windowLabel(t) {
    if (DockModel.isBrowserWindow(t.appId)) return DockModel.shortWindowLabel(t.title)
    return t.title || t.appId || ""
  }
  readonly property string singleLabel: (instanceCount === 1 && DockModel.isBrowserWindow(toplevels[0].appId))
    ? DockModel.shortWindowLabel(toplevels[0].title) : appName

  color: "transparent"
  visible: false
  implicitWidth: Math.ceil(card.implicitWidth)
  implicitHeight: Math.ceil(card.implicitHeight)

  anchor {
    window: popup.hostWindow
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    adjustment: PopupAdjustment.Slide
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!popup.anchorItem || !popup.dockWindow) return
      var off = DockModel.anchorOffset(popup.dockPosition, popup.anchorItem.width, popup.anchorItem.height,
        popup.implicitWidth, popup.implicitHeight, Style.space(4))
      var local = popup.dockWindow.contentItem.mapFromItem(popup.anchorItem, off.x, off.y)
      anchor.rect.x = Math.round(popup.originX + local.x)
      anchor.rect.y = Math.round(popup.originY + local.y)
    }
  }

  // macOS-style speech bubble: a pill (a rounded rectangle for the taller
  // window list) with a small tail on the side facing the dock, so it reads as
  // pointing at the icon. The popup's own size includes the tail, which is why
  // the anchor gap above is small.
  Item {
    id: card

    readonly property string tailSide: popup.dockPosition   // dock edge == side the tail points to
    readonly property bool tailOnSides: tailSide === "left" || tailSide === "right"
    readonly property real tailW: Style.space(14)
    readonly property real tailH: Style.space(7)
    readonly property real hPad: popup.multiInstance ? Style.space(10) : Style.space(16)
    readonly property real vPad: Style.space(8)
    readonly property real bodyW: content.implicitWidth + hPad * 2
    readonly property real bodyH: content.implicitHeight + vPad * 2
    readonly property real bodyX: tailSide === "left" ? tailH : 0
    readonly property real bodyY: tailSide === "top" ? tailH : 0

    implicitWidth: bodyW + (tailOnSides ? tailH : 0)
    implicitHeight: bodyH + (tailOnSides ? 0 : tailH)

    HoverHandler {
      onHoveredChanged: popup.hovered = hovered
    }

    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: Color.tooltip.background
        strokeColor: "transparent"
        strokeWidth: -1 // never an outline; the bubble is just its fill

        PathSvg {
          path: DockModel.bubblePath(card.bodyX, card.bodyY, card.bodyW, card.bodyH,
            Math.min(card.bodyH / 2, Style.space(18)), card.tailW, card.tailH, card.tailSide)
        }
      }
    }

    ColumnLayout {
      id: content
      x: card.bodyX + card.hPad
      y: card.bodyY + card.vPad
      width: implicitWidth
      spacing: Style.space(6)

      Text {
        id: nameLabel
        visible: !popup.multiInstance
        textFormat: Text.PlainText
        text: popup.singleLabel
        color: Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      ColumnLayout {
        id: instanceColumn
        visible: popup.multiInstance
        spacing: Style.space(2)
        Layout.fillWidth: true

        Repeater {
          model: popup.multiInstance ? popup.toplevels : []

          Rectangle {
            id: row
            required property var modelData
            Layout.fillWidth: true
            implicitWidth: rowLabel.implicitWidth + Style.space(12)
            implicitHeight: Style.space(22)
            radius: Style.space(5)
            color: rowArea.containsMouse ? Util.alpha(Color.tooltip.text, 0.1) : "transparent"

            Text {
              id: rowLabel
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: popup.windowLabel(row.modelData)
              color: Color.tooltip.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: popup.activateInstance(row.modelData)
            }
          }
        }
      }
    }
  }
}
