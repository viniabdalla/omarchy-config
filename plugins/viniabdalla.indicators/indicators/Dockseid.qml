import QtQuick
import qs.Ui
import qs.Commons

BarIndicator {
  id: root

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

  active: false
  activeText: "▣"
  inactiveText: "▣"
  activeTooltipText: "Dock settings"
  inactiveTooltipText: "Dock settings"
  fontSize: Style.font.caption * 1.5

  onPressed: function() {
    if (root.bar) root.bar.run("bash -lc " + Util.shellQuote(root.openAtCursorCommand))
  }
}
