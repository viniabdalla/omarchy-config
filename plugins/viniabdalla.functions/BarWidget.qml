import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "viniabdalla.functions"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "ƒ"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "Functions/Skills"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton && root.bar)
        root.bar.run("omarchy-menu toggle personal")
    }
  }
}
