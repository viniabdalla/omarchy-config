import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Hue/saturation wheel + brightness bar + hex field for one color. The wheel
// is painted once on a Canvas (as wedges, so hue direction is explicit rather
// than depending on a conical gradient's winding); brightness is a dark
// overlay on top, so dragging the brightness bar never repaints it.
RowLayout {
  id: picker

  // "#rrggbb" — the color currently applied. Changes from outside (switching
  // target, typing a hex) are pulled into hue/sat/value unless the user is
  // mid-drag here.
  property string value: "#ffffff"
  signal picked(string hex)

  property real hue: 0
  property real sat: 0
  property real val: 1
  property bool interacting: false

  spacing: Style.space(12)

  function toHex(h, s, v) {
    var c = Qt.hsva(h, s, v, 1)
    function part(x) {
      var n = Math.max(0, Math.min(255, Math.round(x * 255))).toString(16)
      return n.length < 2 ? "0" + n : n
    }
    return "#" + part(c.r) + part(c.g) + part(c.b)
  }

  function syncFromValue() {
    if (picker.interacting) return
    if (picker.toHex(picker.hue, picker.sat, picker.val) === String(picker.value).toLowerCase()) return
    var c = Qt.color(picker.value)
    // A gray/black color has no defined hue; keep the current one so the
    // wheel handle doesn't snap back to red.
    if (c.hsvSaturation > 0 && c.hsvValue > 0) picker.hue = c.hsvHue
    picker.sat = c.hsvSaturation
    picker.val = c.hsvValue
  }
  onValueChanged: syncFromValue()
  Component.onCompleted: {
    var c = Qt.color(picker.value)
    picker.hue = Math.max(0, c.hsvHue)
    picker.sat = c.hsvSaturation
    picker.val = c.hsvValue
  }

  function emitPicked() { picker.picked(picker.toHex(picker.hue, picker.sat, picker.val)) }

  // ------------------------------------------------------------ the wheel
  Item {
    id: wheel
    readonly property real diameter: Style.space(112)
    readonly property real radius: diameter / 2
    Layout.preferredWidth: diameter
    Layout.preferredHeight: diameter
    Layout.alignment: Qt.AlignTop

    Canvas {
      anchors.fill: parent
      antialiasing: true
      onPaint: {
        var ctx = getContext("2d")
        var r = width / 2
        ctx.reset()
        for (var i = 0; i < 360; i++) {
          ctx.beginPath()
          ctx.moveTo(r, r)
          // Slight overlap between wedges hides hairline seams.
          ctx.arc(r, r, r, (i - 0.6) * Math.PI / 180, (i + 1.6) * Math.PI / 180, false)
          ctx.closePath()
          ctx.fillStyle = Qt.hsva(i / 360, 1, 1, 1)
          ctx.fill()
        }
        var g = ctx.createRadialGradient(r, r, 0, r, r, r)
        g.addColorStop(0, "rgba(255,255,255,1)")
        g.addColorStop(1, "rgba(255,255,255,0)")
        ctx.beginPath()
        ctx.arc(r, r, r, 0, Math.PI * 2, false)
        ctx.fillStyle = g
        ctx.fill()
      }
    }

    // Brightness: darkens the whole wheel as value drops.
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "black"
      opacity: 1 - picker.val
    }

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.popups.text, 0.25)
    }

    // Handle
    Rectangle {
      width: Style.space(14)
      height: width
      radius: width / 2
      x: wheel.radius + Math.cos(picker.hue * 2 * Math.PI) * picker.sat * wheel.radius - width / 2
      y: wheel.radius + Math.sin(picker.hue * 2 * Math.PI) * picker.sat * wheel.radius - height / 2
      color: picker.toHex(picker.hue, picker.sat, picker.val)
      border.width: Math.max(2, Style.space(2))
      border.color: "white"
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.CrossCursor
      function pick(mouse) {
        var dx = mouse.x - wheel.radius
        var dy = mouse.y - wheel.radius
        var dist = Math.sqrt(dx * dx + dy * dy)
        var a = Math.atan2(dy, dx) / (2 * Math.PI)
        picker.hue = a < 0 ? a + 1 : a
        picker.sat = Math.min(1, dist / wheel.radius)
        picker.emitPicked()
      }
      onPressed: function(mouse) { picker.interacting = true; pick(mouse) }
      onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
      onReleased: { picker.interacting = false; picker.syncFromValue() }
      onCanceled: { picker.interacting = false; picker.syncFromValue() }
    }
  }

  // ------------------------------------------------- brightness + hex field
  ColumnLayout {
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: "Brightness"
      color: Color.popups.text
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Rectangle {
      id: bar
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(18)
      radius: height / 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "black" }
        GradientStop { position: 1; color: Qt.hsva(picker.hue, picker.sat, 1, 1) }
      }
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.popups.text, 0.25)

      Rectangle {
        width: Style.space(14)
        height: parent.height + Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        x: picker.val * (bar.width - width)
        radius: width / 2
        color: picker.toHex(picker.hue, picker.sat, picker.val)
        border.width: Math.max(2, Style.space(2))
        border.color: "white"
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function pick(mouse) {
          var knob = Style.space(14)
          picker.val = Math.max(0, Math.min(1, (mouse.x - knob / 2) / (bar.width - knob)))
          picker.emitPicked()
        }
        onPressed: function(mouse) { picker.interacting = true; pick(mouse) }
        onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
        onReleased: { picker.interacting = false; picker.syncFromValue() }
        onCanceled: { picker.interacting = false; picker.syncFromValue() }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: "Hex"
      color: Color.popups.text
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    TextField {
      id: hexField
      Layout.fillWidth: true
      text: picker.value
      onEditingFinished: {
        picker.picked(text)
        // Re-bind so an invalid entry snaps back to the applied color.
        text = Qt.binding(function() { return picker.value })
      }
    }
  }
}
