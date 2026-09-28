import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.silkvain.dockseid"

  readonly property bool opened: false
  readonly property string openAtCursorCommand: [
    "pos=$(hyprctl cursorpos 2>/dev/null) || exit 0",
    "x=${pos%%,*}",
    "y=${pos#*,}",
    "x=${x//[[:space:]]/}",
    "y=${y//[[:space:]]/}",
    "monitor=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson x \"$x\" --argjson y \"$y\" '.[] | select($x >= .x and $x < (.x + .width) and $y >= .y and $y < (.y + .height)) | .name' | head -n1)",
    "if [ -n \"$monitor\" ]; then",
    "  omarchy-shell io.github.silkvain.dockseid toggleSettingsOn \"$monitor\"",
    "else",
    "  omarchy-shell io.github.silkvain.dockseid toggleSettings",
    "fi"
  ].join("\n")

  function open() {
    if (root.bar) root.bar.run("bash -lc " + Util.shellQuote(root.openAtCursorCommand))
  }

  function close() {}

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "▣"
    fontFamily: Style.font.family
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption * 1.5
    tooltipText: "Dock settings"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.open()
    }
  }
}
