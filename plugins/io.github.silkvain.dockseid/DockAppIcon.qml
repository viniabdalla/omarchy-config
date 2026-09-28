import QtQuick
import qs.Commons

// One dock slot: icon image, hover highlight, and running dot. All popups
// (hover preview, context menu) are owned by Dock.qml and positioned against
// this item, so only one popup surface exists at a time no matter how many
// apps are pinned/running.
Item {
  id: root

  required property var modelData
  property color foreground: Color.foreground
  property color accent: Color.accent
  property real sizeScale: 1.0
  // Whole pixels only: the icon is requested from the image provider at exactly
  // the size it's drawn, so it maps 1:1 to screen pixels instead of being
  // stretched by a fractional factor (the cause of the blur). The icon's size
  // takes the same parity as the slot so centring it never lands on a half pixel.
  // DockSurface.slotSize must round the same way.
  property int slotSize: Math.round(Style.space(54) * sizeScale)
  property int iconSize: {
    var s = Math.round(Style.space(42) * sizeScale)
    return ((root.slotSize - s) % 2 === 0) ? s : s + 1
  }
  property bool menuOpen: false
  // Fisheye magnification, driven by DockSurface. Applied to the icon image
  // only (not the hover highlight or dot), so it stays inside the dock's
  // bounds; renderScale is the largest magnification, so the icon is decoded
  // at a size that stays sharp when scaled up.
  property real magnification: 1.0
  property real renderScale: 1.0

  signal hoverEntered()
  signal hoverExited()
  signal primaryClicked()
  signal middleClicked()
  signal rightClicked()
  // Raw pointer signals for drag-to-reorder — DockSurface owns the actual
  // reordering logic and this icon's position while dragging; this just
  // reports the gesture. dragMoved's (dx, dy) is the total offset from the
  // press point, not a per-event delta.
  signal dragStarted()
  signal dragMoved(real dx, real dy)
  signal dragFinished()

  implicitWidth: slotSize
  implicitHeight: slotSize
  z: mouseArea.dragging ? 10 : 0

  readonly property bool running: modelData.running === true
  readonly property bool dragging: mouseArea.dragging
  readonly property bool hot: mouseArea.containsMouse || root.menuOpen

  Rectangle {
    id: hoverBg
    anchors.centerIn: parent
    width: root.iconSize + Style.space(14) * root.sizeScale
    height: root.iconSize + Style.space(14) * root.sizeScale
    radius: width / 2
    color: Util.alpha(root.foreground, root.hot ? 0.12 : 0)
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Image {
    id: iconImage
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: root.renderScale > 1   // only downscaled (magnification) needs it
    sourceSize.width: width * Screen.devicePixelRatio * root.renderScale
    sourceSize.height: height * Screen.devicePixelRatio * root.renderScale
    source: root.modelData.iconSource || ""
    // The press/drag feedback animates; magnification does not, because it
    // follows the pointer every event and an animation would restart each time.
    property real pressScale: mouseArea.dragging ? 1.1 : (mouseArea.pressed ? 0.92 : 1.0)
    Behavior on pressScale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    scale: pressScale * root.magnification
  }

  // macOS-style running indicator.
  Rectangle {
    visible: root.running
    width: Style.space(5) * root.sizeScale
    height: Style.space(5) * root.sizeScale
    radius: width / 2
    color: root.accent
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(2)
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    property real pressX: 0
    property real pressY: 0
    property bool dragging: false
    readonly property real dragThreshold: 6

    onEntered: root.hoverEntered()
    onExited: root.hoverExited()

    // mouse.x/mouse.y are local to this MouseArea, which moves every time a
    // drag repositions the icon — using them directly would measure each
    // delta against a reference frame that just shifted under it, feeding
    // back into visible jitter. Mapping through to scene coordinates (a
    // frame that doesn't move with the icon) keeps the delta stable.
    function scenePos(mouse) {
      return mouseArea.mapToItem(null, mouse.x, mouse.y)
    }

    onPressed: function(mouse) {
      var p = scenePos(mouse)
      pressX = p.x
      pressY = p.y
      dragging = false
    }

    // Only a left-button press can turn into a drag; middle/right stay
    // immediate actions. Threshold avoids treating a plain click as a
    // micro-drag.
    onPositionChanged: function(mouse) {
      if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) return
      var p = scenePos(mouse)
      var dx = p.x - pressX
      var dy = p.y - pressY
      if (!dragging && (Math.abs(dx) > dragThreshold || Math.abs(dy) > dragThreshold)) {
        dragging = true
        root.dragStarted()
      }
      if (dragging) root.dragMoved(dx, dy)
    }

    onReleased: function(mouse) {
      if (dragging) {
        dragging = false
        root.dragFinished()
        return
      }
      if (mouse.button === Qt.LeftButton) root.primaryClicked()
      else if (mouse.button === Qt.MiddleButton) root.middleClicked()
      else if (mouse.button === Qt.RightButton) root.rightClicked()
    }
  }
}
