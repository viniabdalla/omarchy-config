import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

// Dock customization popover, as two tabs:
//  - Settings: fields grouped under GroupHeaders — Placement (screen,
//    position, visibility, edge offset, fullscreen behavior), Appearance
//    (shape, size, opacity, outline), and Theme.
//  - Add App: the search-and-pin picker for adding an app that isn't
//    currently running — the only path to pin one that's never been opened,
//    folded in here instead of a permanent second dock icon.
// When "Match system theme" is on, the dock rides qs.Commons.Color the same
// as every other Omarchy surface, so switching the OS theme (e.g. to Osaka
// Jade) re-themes it automatically. Switching to "Custom" freezes it to
// user-picked colors regardless of OS theme.
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
  property bool topBarAnchor: false
  property int activeTab: 0 // 0 = Settings, 1 = Add App

  property string shape: "pill"
  property real opacityValue: 0.85
  property real blurValue: 0
  property bool glass: false
  property bool magnify: false
  // Per color: follow the system theme (false) or use the user's own (true).
  property bool useCustomBackground: false
  property bool useCustomBorder: false
  property bool useCustomLogo: false
  property string customBackground: "#1e1e2e"
  property string customBorder: "#8aadf4"
  property string customLogo: "#ffffff"
  property string customTarget: "background" // which colour the System/Custom switch and wheel edit
  readonly property bool targetCustom: customTarget === "background" ? useCustomBackground
    : (customTarget === "border" ? useCustomBorder : useCustomLogo)
  property string monitor: "primary"
  // Named visibilityMode (not "visibility") because PopupWindow already has
  // its own inherited Qt Window.visibility property.
  property string visibilityMode: "autohide"
  property real size: 1.0
  property real edgeGap: 14
  property bool borderEnabled: true
  property real borderWidth: 1
  property bool showInFullscreen: false
  property bool showWhenEmpty: false
  // [{value, label}], the currently connected screens plus "all".
  property var monitorOptions: []

  // ------------------------------------------------------- Add App tab
  // [{id, name, iconSource}], unfiltered, already excludes already-pinned ids.
  property var allEntries: []
  property string filterText: ""

  signal shapePicked(string value)
  signal opacityPicked(real value)
  signal blurPicked(real value)
  signal glassPicked(bool value)
  signal magnifyPicked(bool value)
  signal customEnabledPicked(string kind, bool on)
  signal customColorPicked(string kind, string hex)
  signal positionPicked(string value)
  signal monitorPicked(string value)
  signal visibilityPicked(string value)
  signal sizePicked(real value)
  signal edgeGapPicked(real value)
  signal borderEnabledPicked(bool value)
  signal borderWidthPicked(real value)
  signal showInFullscreenPicked(bool value)
  signal showWhenEmptyPicked(bool value)
  signal appPicked(string id)
  signal dismissed()

  function matches(entry, needle) {
    if (needle.length === 0) return true
    return String(entry.name || entry.id || "").toLowerCase().indexOf(needle) !== -1
  }

  readonly property var filteredEntries: {
    var needle = filterText.toLowerCase()
    var out = []
    for (var i = 0; i < allEntries.length; i++) {
      if (matches(allEntries[i], needle)) out.push(allEntries[i])
    }
    return out
  }

  // Keyboard selection in the list below the search field — kept in sync
  // with mouse hover too, so switching between keyboard and mouse mid-pick
  // never leaves a stale highlight. Resets to the top match whenever the
  // filtered set changes, matching typical type-ahead search behavior.
  property int selectedIndex: 0
  onFilteredEntriesChanged: popup.selectedIndex = popup.filteredEntries.length > 0 ? 0 : -1
  onSelectedIndexChanged: if (popup.selectedIndex >= 0 && popup.activeTab === 1) appList.positionViewAtIndex(popup.selectedIndex, ListView.Contain)

  function activateSelected() {
    if (popup.selectedIndex < 0 || popup.selectedIndex >= popup.filteredEntries.length) return
    // Pinning grows the pill, but this popup now anchors to a stable
    // screen-spanning window that doesn't track the pill's own surface, so
    // it can stay open through the resize without leaving a render artifact.
    var id = popup.filteredEntries[popup.selectedIndex].id
    popup.appPicked(id)
  }

  onActiveTabChanged: {
    if (activeTab === 1) {
      filterText = ""
      appSearchField.text = ""
      appSearchField.forceActiveFocus()
    }
  }

  color: "transparent"
  visible: false
  grabFocus: true
  implicitWidth: Math.ceil(card.implicitWidth)
  implicitHeight: Math.ceil(card.implicitHeight)

  onVisibleChanged: if (!visible) popup.dismissed()

  anchor {
    window: popup.hostWindow
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    adjustment: PopupAdjustment.Slide
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (popup.topBarAnchor && popup.hostWindow) {
        anchor.rect.x = Math.round((popup.hostWindow.width - popup.implicitWidth) / 2)
        anchor.rect.y = Style.space(34)
        return
      }
      if (!popup.anchorItem || !popup.dockWindow) return
      var off = DockModel.anchorOffset(popup.dockPosition, popup.anchorItem.width, popup.anchorItem.height,
        popup.implicitWidth, popup.implicitHeight, Style.space(8))
      var local = popup.dockWindow.contentItem.mapFromItem(popup.anchorItem, off.x, off.y)
      anchor.rect.x = Math.round(popup.originX + local.x)
      anchor.rect.y = Math.round(popup.originY + local.y)
    }
  }

  // Field-level label, e.g. "Position" or "Opacity — 85%" — one per control.
  component SectionLabel: Text {
    textFormat: Text.PlainText
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    opacity: 0.7
  }

  // Group-level heading, e.g. "Placement" or "Appearance" — one per cluster
  // of related fields. Deliberately louder than SectionLabel (accent color,
  // uppercase, letter-spaced) so the two tiers read as distinct levels
  // instead of one long flat list of equally-weighted labels.
  component GroupHeader: Text {
    textFormat: Text.PlainText
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1
  }

  component ShapeButton: Rectangle {
    id: shapeBtn
    property string value: ""
    property string label: ""
    property bool selected: false
    signal picked()
    Layout.fillWidth: true
    implicitHeight: Style.space(30)
    radius: shapeBtn.value === "pill" ? height / 2 : (shapeBtn.value === "rounded" ? Style.space(8) : 0)
    color: shapeBtn.selected ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text, shapeArea.containsMouse ? 0.1 : 0)
    border.width: shapeBtn.selected ? Math.max(1, Style.space(1)) : 0
    border.color: Color.accent

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: shapeBtn.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: shapeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: shapeBtn.picked()
    }
  }

  // Underline-indicator style for the Settings/Add App switcher at the top,
  // kept visually distinct from ModeButton (a filled pill) so it reads as
  // "which page am I on" rather than another in-page toggle.
  component TabButton: Item {
    id: tabBtn
    property string label: ""
    property bool selected: false
    signal picked()
    Layout.fillWidth: true
    implicitHeight: Style.space(30)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tabBtn.label
      color: tabBtn.selected ? Color.accent : Util.alpha(Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: tabBtn.selected
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.6
      height: Math.max(2, Style.space(2))
      radius: height / 2
      color: Color.accent
      visible: tabBtn.selected
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tabBtn.picked()
    }
  }

  // Selector chip for the custom-color wheel: shows the color it currently
  // holds, and highlights when it's the one being edited.
  component ColorTarget: Rectangle {
    id: target
    property string kind: ""
    property string label: ""
    property color swatch: "transparent"
    readonly property bool selected: popup.customTarget === target.kind
    Layout.fillWidth: true
    implicitHeight: Style.space(28)
    radius: Style.space(6)
    color: target.selected ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text, targetArea.containsMouse ? 0.1 : 0)

    Row {
      anchors.centerIn: parent
      spacing: Style.space(6)
      Rectangle {
        width: Style.space(14)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: target.swatch
        border.width: Math.max(1, Style.space(1))
        border.color: Util.alpha(Color.popups.text, 0.4)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: target.label
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    MouseArea {
      id: targetArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: popup.customTarget = target.kind
    }
  }

  component ModeButton: Rectangle {
    id: modeBtn
    property string value: ""
    property string label: ""
    property bool selected: false
    signal picked()
    Layout.fillWidth: true
    implicitHeight: Style.space(26)
    radius: Style.space(6)
    color: modeBtn.selected ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.popups.text, modeArea.containsMouse ? 0.1 : 0)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: modeBtn.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: modeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: modeBtn.picked()
    }
  }

  BorderSurface {
    id: card
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
    radius: popup.shape === "square" ? 0 : Math.max(Style.cornerRadius, Style.space(14))
    // Wide enough for the Settings tab's two side-by-side columns; the
    // narrower Add App tab just sits centered within the same width.
    implicitWidth: Style.space(540)
    implicitHeight: content.implicitHeight + Style.space(24)

    ColumnLayout {
      id: content
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        TabButton { label: "Settings"; selected: popup.activeTab === 0; onPicked: popup.activeTab = 0 }
        TabButton { label: "Add App"; selected: popup.activeTab === 1; onPicked: popup.activeTab = 1 }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(1, Style.space(1))
        color: Util.alpha(Color.popups.text, 0.12)
      }

      // Holds both tabs' content stacked in the same space. A plain Item
      // (not a Layout) so its implicitWidth/Height — bound to the max of
      // both tabs below — stay constant no matter which tab is showing.
      // Layouts skip invisible children when sizing themselves, which is
      // exactly what made the popover resize on every tab switch before:
      // each tab's real size only counted while it was the visible one.
      Item {
        id: tabBody
        Layout.fillWidth: true
        implicitWidth: Math.max(settingsTab.implicitWidth, addAppTab.implicitWidth)
        implicitHeight: Math.max(settingsTab.implicitHeight, addAppTab.implicitHeight)

      // ------------------------------------------------------- Settings tab
      // Two columns side by side — Placement on its own on the left (it's
      // the tallest group), Appearance + Theme stacked on the right — so
      // the popover reads as two short scans instead of one long one.
      RowLayout {
        id: settingsTab
        visible: popup.activeTab === 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(20)

        // ----- Placement: where and when the dock shows itself -----
        ColumnLayout {
          id: leftColumn
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          spacing: Style.space(10)

          GroupHeader { text: "Placement" }

          SectionLabel { text: "Screen" }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
              model: popup.monitorOptions

              ModeButton {
                required property var modelData
                Layout.fillWidth: true
                value: modelData.value
                label: modelData.label
                selected: popup.monitor === modelData.value
                onPicked: popup.monitorPicked(modelData.value)
              }
            }
          }

          SectionLabel { text: "Position" }
          GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Style.space(6)
            columnSpacing: Style.space(6)
            ModeButton { value: "bottom"; label: "Bottom"; selected: popup.dockPosition === "bottom"; onPicked: popup.positionPicked("bottom") }
            ModeButton { value: "top"; label: "Top"; selected: popup.dockPosition === "top"; onPicked: popup.positionPicked("top") }
            ModeButton { value: "left"; label: "Left"; selected: popup.dockPosition === "left"; onPicked: popup.positionPicked("left") }
            ModeButton { value: "right"; label: "Right"; selected: popup.dockPosition === "right"; onPicked: popup.positionPicked("right") }
          }

          SectionLabel { text: "Visibility" }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ModeButton { value: "autohide"; label: "Auto-hide"; selected: popup.visibilityMode === "autohide"; onPicked: popup.visibilityPicked("autohide") }
            ModeButton { value: "always"; label: "Always visible"; selected: popup.visibilityMode === "always"; onPicked: popup.visibilityPicked("always") }
          }

          // Only meaningful with auto-hide (an always-visible dock never hides, so
          // there is nothing to keep visible on an empty screen). Made invisible
          // rather than removed, so the layout below doesn't shift or resize.
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)
            opacity: popup.visibilityMode === "autohide" ? 1 : 0
            enabled: popup.visibilityMode === "autohide"

            SectionLabel { text: "When Workspace Is Empty" }
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              ModeButton {
                value: "off"; label: "Hide as Usual"
                selected: !popup.showWhenEmpty
                onPicked: popup.showWhenEmptyPicked(false)
              }
              ModeButton {
                value: "on"; label: "Stay Visible"
                selected: popup.showWhenEmpty
                onPicked: popup.showWhenEmptyPicked(true)
              }
            }
          }

          // Tracked separately per visibility mode (see Dock.qml/DockSurface.qml)
          // so the label makes clear which one this slider is currently editing.
          SectionLabel {
            text: "Edge Offset (" + (popup.visibilityMode === "always" ? "Always Visible" : "Auto-hide")
              + ") — " + Math.round(edgeGapSlider.liveValue) + "px"
          }
          PanelSlider {
            id: edgeGapSlider
            Layout.fillWidth: true
            minimum: 0
            maximum: 48
            step: 1
            integer: true
            value: popup.edgeGap
            trackColor: Util.alpha(Color.popups.text, 0.15)
            fillColor: Color.accent
            knobColor: Color.accent
            // Moves the dock window itself — see Size below for why that
            // means committing on release instead of live.
            onReleased: function(v) { popup.edgeGapPicked(v) }
          }

          SectionLabel { text: "Over Fullscreen Apps" }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ModeButton {
              value: "off"; label: "Stay Hidden"
              selected: !popup.showInFullscreen
              onPicked: popup.showInFullscreenPicked(false)
            }
            ModeButton {
              value: "on"; label: "Reveal on Hover"
              selected: popup.showInFullscreen
              onPicked: popup.showInFullscreenPicked(true)
            }
          }

          // Colour wheel for whichever colour is selected under Theme (right
          // column). It sits here, in the space under Placement, rather than
          // under the Theme switch: this column is shorter than the right one, so
          // showing it never makes the window taller when a colour goes Custom.
          ColumnLayout {
            visible: popup.targetCustom
            Layout.fillWidth: true
            spacing: Style.space(6)

            SectionLabel { text: "Custom " + (popup.customTarget === "background" ? "background" : (popup.customTarget === "border" ? "outline" : "logo")) + " colour" }
            ColorPicker {
              Layout.fillWidth: true
              value: popup.customTarget === "background" ? popup.customBackground
                : (popup.customTarget === "border" ? popup.customBorder : popup.customLogo)
              onPicked: function(hex) { popup.customColorPicked(popup.customTarget, hex) }
            }
          }
        }

        // ----- Right column: Appearance, then Theme, stacked -----
        ColumnLayout {
          id: rightColumn
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          spacing: Style.space(18)

        // ----- Appearance: what the dock looks like -----
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          GroupHeader { text: "Appearance" }

          SectionLabel { text: "Shape" }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ShapeButton { value: "square"; label: "Square"; selected: popup.shape === "square"; onPicked: popup.shapePicked("square") }
            ShapeButton { value: "rounded"; label: "Rounded"; selected: popup.shape === "rounded"; onPicked: popup.shapePicked("rounded") }
            ShapeButton { value: "pill"; label: "Pill"; selected: popup.shape === "pill"; onPicked: popup.shapePicked("pill") }
          }

          // The label reads the slider's own liveValue (which tracks the drag
          // in real time) rather than popup.size, so the number keeps up while
          // dragging even though the actual resize is still deferred to release.
          SectionLabel { text: "Size — " + Math.round(sizeSlider.liveValue * 100) + "%" }
          PanelSlider {
            id: sizeSlider
            Layout.fillWidth: true
            minimum: 0.7
            maximum: 1.6
            step: 0.05
            value: popup.size
            trackColor: Util.alpha(Color.popups.text, 0.15)
            fillColor: Color.accent
            knobColor: Color.accent
            // Committed on release rather than live on every drag tick: unlike
            // opacity, size resizes the dock's actual window, and this popup is
            // anchored to a button inside it.
            onReleased: function(v) { popup.sizePicked(v) }
          }

          SectionLabel { text: "Icon Magnification" }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ModeButton { value: "off"; label: "Off"; selected: !popup.magnify; onPicked: popup.magnifyPicked(false) }
            ModeButton { value: "on"; label: "On"; selected: popup.magnify; onPicked: popup.magnifyPicked(true) }
          }

          SectionLabel { text: "Glass Effect" }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ModeButton { value: "off"; label: "Off"; selected: !popup.glass; onPicked: popup.glassPicked(false) }
            ModeButton { value: "on"; label: "On"; selected: popup.glass; onPicked: popup.glassPicked(true) }
          }
          Text {
            visible: popup.glass
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Glass sets its own opacity, blur and outline."
            color: Color.popups.text
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          // Controls that glass overrides — dimmed and inert while it's on.
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)
            enabled: !popup.glass
            opacity: popup.glass ? 0.35 : 1

            SectionLabel { text: "Opacity — " + Math.round(popup.opacityValue * 100) + "%" }
            PanelSlider {
              Layout.fillWidth: true
              minimum: 0.35
              maximum: 1.0
              step: 0.05
              value: popup.opacityValue
              trackColor: Util.alpha(Color.popups.text, 0.15)
              fillColor: Color.accent
              knobColor: Color.accent
              onMoved: function(v) { popup.opacityPicked(v) }
            }

            SectionLabel { text: "Background blur — " + (popup.blurValue <= 0 ? "Off" : Math.round(popup.blurValue * 100) + "%") }
            PanelSlider {
              Layout.fillWidth: true
              minimum: 0
              maximum: 1.0
              step: 0.05
              value: popup.blurValue
              trackColor: Util.alpha(Color.popups.text, 0.15)
              fillColor: Color.accent
              knobColor: Color.accent
              onMoved: function(v) { popup.blurPicked(v) }
            }
            Text {
              visible: popup.blurValue > 0 && popup.opacityValue > 0.9
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: "Lower Opacity to see the blur through the dock."
              color: Color.popups.text
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            SectionLabel { text: "Outline" }
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              ModeButton { value: "on"; label: "Show"; selected: popup.borderEnabled; onPicked: popup.borderEnabledPicked(true) }
              ModeButton { value: "off"; label: "Hide"; selected: !popup.borderEnabled; onPicked: popup.borderEnabledPicked(false) }
            }

            ColumnLayout {
              visible: popup.borderEnabled
              Layout.fillWidth: true
              spacing: Style.space(4)

              SectionLabel { text: "Outline Width — " + Math.round(borderWidthSlider.liveValue) + "px" }
              PanelSlider {
                id: borderWidthSlider
                Layout.fillWidth: true
                minimum: 1
                maximum: 6
                step: 1
                integer: true
                value: popup.borderWidth
                trackColor: Util.alpha(Color.popups.text, 0.15)
                fillColor: Color.accent
                knobColor: Color.accent
                // Unlike size/edge offset this never resizes or moves the dock's
                // window — border width is purely cosmetic — so it's safe to
                // preview live on every drag tick like opacity.
                onMoved: function(v) { popup.borderWidthPicked(v) }
              }
            }
          }
        }

        // ----- Theme: color source -----
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          GroupHeader { text: "Theme" }

          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Each colour follows your system theme unless you set it to Custom."
            color: Color.popups.text
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          // Which colour is being edited; each one is its own System/Custom choice.
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ColorTarget { kind: "background"; label: "Background"; swatch: popup.useCustomBackground ? popup.customBackground : Color.background }
            ColorTarget { kind: "border"; label: "Outline"; swatch: popup.useCustomBorder ? popup.customBorder : Color.popups.border }
            ColorTarget { kind: "logo"; label: "Logo"; swatch: popup.useCustomLogo ? popup.customLogo : Color.accent }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ModeButton { value: "system"; label: "System"; selected: !popup.targetCustom; onPicked: popup.customEnabledPicked(popup.customTarget, false) }
            ModeButton { value: "custom"; label: "Custom"; selected: popup.targetCustom; onPicked: popup.customEnabledPicked(popup.customTarget, true) }
          }
        }
        } // end right column

      }

      // ------------------------------------------------------- Add App tab
      ColumnLayout {
        id: addAppTab
        visible: popup.activeTab === 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Settings tab is the taller of the two (see tabBody above), so the
        // popup's actual height is set by it. Anchoring bottom here too lets
        // this tab's ListView stretch down to fill that same height instead
        // of stopping at a fixed size partway down the box.
        anchors.bottom: parent.bottom
        spacing: Style.space(8)

        TextField {
          id: appSearchField
          Layout.fillWidth: true
          text: popup.filterText
          placeholderText: "Search apps…"
          onTextChanged: popup.filterText = text

          // Arrow keys move the selection in the list below without leaving
          // the search field, so picking a result never needs the mouse.
          Keys.onDownPressed: function(event) {
            if (popup.filteredEntries.length === 0) return
            popup.selectedIndex = Math.min(popup.filteredEntries.length - 1, popup.selectedIndex + 1)
            event.accepted = true
          }
          Keys.onUpPressed: function(event) {
            if (popup.filteredEntries.length === 0) return
            popup.selectedIndex = Math.max(0, popup.selectedIndex - 1)
            event.accepted = true
          }
          Keys.onReturnPressed: function(event) { popup.activateSelected(); event.accepted = true }
          Keys.onEnterPressed: function(event) { popup.activateSelected(); event.accepted = true }
          Keys.onEscapePressed: function(event) { popup.visible = false; event.accepted = true }
        }

        ListView {
          id: appList
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: Style.space(280)
          clip: true
          model: popup.filteredEntries
          spacing: Style.space(2)

          delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: appList.width
            height: Style.space(34)
            radius: Style.space(6)
            color: (popup.selectedIndex === row.index || rowArea.containsMouse) ? Util.alpha(Color.popups.text, 0.1) : "transparent"

            // Plain anchors, not a RowLayout — see AddAppPopup's former
            // history: a Layout sized via anchors.fill inside a ListView
            // delegate that gets repositioned on every keyboard/hover
            // selection change is a known way to trigger a
            // QQuickItem::polish() loop.
            Image {
              id: rowIcon
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(20)
              height: Style.space(20)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              source: row.modelData.iconSource || ""
            }

            Text {
              anchors.left: rowIcon.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: row.modelData.name || row.modelData.id
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: popup.selectedIndex = row.index
              onClicked: popup.appPicked(row.modelData.id)
            }
          }

          Text {
            visible: appList.count === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "No matching apps"
            color: Util.alpha(Color.popups.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
      } // end tabBody

    }
  }
}
