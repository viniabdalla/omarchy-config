import QtQuick
import qs.Commons

// Round glyph button for the dock's leading controls (add app, settings).
Item {
  id: root

  property string glyph: "+"
  property string fontFamily: Style.font.family
  property real glyphScale: 1.0   // multiplies the glyph's font size
  property color glyphColor: Color.foreground
  property real glyphOpacity: 0.75
  property real sizeScale: 1.0
  property real diameter: Style.space(34) * sizeScale

  signal clicked()

  implicitWidth: diameter
  implicitHeight: diameter

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Util.alpha(Color.foreground, area.containsMouse ? 0.12 : 0)
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.glyph
    color: root.glyphColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.heading * root.sizeScale * root.glyphScale
    opacity: root.glyphOpacity
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
