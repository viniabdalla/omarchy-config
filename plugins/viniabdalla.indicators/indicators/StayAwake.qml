import QtQuick
import qs.Commons
import qs.Ui
import ".."

BarIndicator {
  id: root

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("omarchy.idle")

  // The shell hands cloned widgets no idle service; fall back to the shared
  // ToggleState then.
  active: idleService ? idleService.stayAwake : ToggleState.stayAwake
  // A mug without a saucer, which drew a line under the cup.
  activeText: ""
  inactiveText: ""
  activeTooltipText: I18n.t("bar.allowIdleLock")
  inactiveTooltipText: I18n.t("bar.stayAwake")

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.active)
    else ToggleState.toggleStayAwake()
  }

  onPressed: function() { root.toggle() }
  onInactiveRevealedChanged: if (inactiveRevealed && !idleService) ToggleState.refresh()
}
