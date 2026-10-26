import QtQuick
import qs.Commons
import qs.Ui
import ".."

BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")

  // The shell hands cloned widgets no nightlight service; fall back to the
  // shared ToggleState then.
  active: nightlightService ? nightlightService.enabled : ToggleState.nightlight
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: I18n.t("bar.dayLight")
  inactiveTooltipText: I18n.t("bar.nightLight")

  function toggle() {
    if (root.nightlightService) root.nightlightService.setNightlight(!root.active)
    else ToggleState.toggleNightlight()
  }

  onPressed: function() { root.toggle() }
  onInactiveRevealedChanged: if (inactiveRevealed && !nightlightService) ToggleState.refresh()
}
