import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "viniabdalla.agenda"
  ipcTarget: "viniabdalla.agenda"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Everything that renders a clock reads this instead of Date.now(), so a
  // panel left open keeps telling the truth as the day moves.
  property double nowMs: Date.now()

  // Folded by default; opening the panel should show today, not the backlog.
  property bool showOverdue: false

  // Which card is expanded, and which one has its actions revealed.
  property string openId: ""
  property string actionsId: ""

  // Quick task form, closed until the + button opens it.
  property bool quickOpen: false
  property string quickPriority: ""
  property string quickCategory: ""
  property bool quickSending: false
  readonly property bool quickReady: quickPriority !== "" && quickCategory !== ""
    && quickField.text.trim() !== "" && !quickSending

  readonly property var current: agenda.current
  readonly property bool hasOverdue: agenda.counts.overdue > 0

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ------------------------------------------------------------------ text

  function timeOf(iso) {
    if (!iso) return ""
    return Qt.formatTime(new Date(iso), "HH:mm")
  }

  function truncate(text, max) {
    var value = String(text || "")
    return value.length <= max ? value : value.slice(0, Math.max(1, max - 1)) + "…"
  }

  function dateOf(isoDate) {
    if (!isoDate) return ""
    var parts = String(isoDate).split("-")
    return parts.length === 3 ? `${parts[2]}/${parts[1]}` : isoDate
  }

  // "Terça-feira, 25 de agosto", as the Google Agenda card writes it. A bare
  // YYYY-MM-DD is a local calendar date; parsing it as ISO would shift it to UTC.
  function longDate(value) {
    if (!value) return ""
    var parts = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value))
    var date = parts ? new Date(+parts[1], +parts[2] - 1, +parts[3]) : new Date(value)
    var text = date.toLocaleDateString(Qt.locale("pt_BR"), "dddd, d 'de' MMMM")
    return text.charAt(0).toUpperCase() + text.slice(1)
  }

  function whenOf(item) {
    if (!item) return ""
    var day = longDate(item.start || item.due)
    var time = item.start && item.end ? `${timeOf(item.start)}–${timeOf(item.end)}` : timeOf(item.start)
    var text = time ? `${day}  \u00b7  ${time}` : day
    if (item.overdueDays > 0) text += `  \u00b7  ${itemMeta(item)}`
    return text
  }

  function itemMeta(item) {
    if (!item) return ""
    if (item.overdueDays > 0)
      return item.overdueDays === 1 ? "atrasada 1 dia" : `atrasada ${item.overdueDays} dias`
    if (item.start && item.end) return `${timeOf(item.start)}–${timeOf(item.end)}`
    if (item.start) return timeOf(item.start)
    return item.kind === "event" ? "compromisso" : (item.listTitle || "tarefa")
  }

  readonly property string barLabelText: {
    if (!agenda.daemonAlive) return "Agenda"
    if (!agenda.connected) return "Conectar Google"
    if (!current) return "Sem tarefas hoje"
    var max = agenda.setting("maxPillChars", 34)
    var time = current.start ? `${timeOf(current.start)}  ` : ""
    return time + truncate(current.title, Math.max(8, max - time.length))
  }

  readonly property string barTooltipText: {
    if (!agenda.daemonAlive) return "Agenda — daemon parado"
    if (!agenda.connected) return "Agenda — clique para conectar o Google"
    var c = agenda.counts
    var parts = [`${c.pending} pendentes`, `${c.done} concluidas`]
    if (c.overdue > 0) parts.push(`${c.overdue} atrasadas`)
    if (c.events > 0) parts.push(`${c.events} compromissos`)
    return `${parts.join(" · ")}\n${agenda.syncStatus}`
  }

  // ---------------------------------------------------------------- actions

  function toggleCompleted(item) {
    if (!item || item.kind !== "task") return
    agenda.setCompleted(item.id, !item.completed)
  }

  function togglePin(item) {
    if (!item) return
    if (current && current.id === item.id && current.pinned) agenda.clearNow()
    else agenda.pinNow(item.id)
  }

  function openQuick() {
    quickOpen = true
    agenda.lastError = ""
    Qt.callLater(function() { quickField.forceActiveFocus() })
  }

  function closeQuick() {
    quickOpen = false
    quickPriority = ""
    quickCategory = ""
    quickSending = false
    quickField.text = ""
    keyCatcher.forceActiveFocus()
  }

  function submitQuick() {
    if (!quickReady) return
    quickSending = true
    agenda.createTask(quickPriority, quickCategory, quickField.text.trim())
  }

  Connections {
    target: agenda
    function onFinished(op, ok) {
      if (op !== "create") return
      if (ok) root.closeQuick()
      else root.quickSending = false
    }
  }

  function primaryAction() {
    if (!agenda.connected) agenda.connect()
    else agenda.refresh()
  }

  // ------------------------------------------------------------------ wiring

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: console.warn("agenda/loaded", "0.4.0")

  onOpenedChanged: if (!opened) {
    openId = ""
    actionsId = ""
    if (quickOpen && !quickSending) closeQuick()
  } else {
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    if (agenda.connected) agenda.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: agenda
    settings: root.settings
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barLabelText
    tooltipText: root.barTooltipText
    active: root.hasOverdue || !agenda.connected
    dimmed: !agenda.daemonAlive
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) agenda.refresh()
      else root.toggle()
    }
  }

  // One card, shared by the day list and the backlog list.
  //
  // Tapping the card opens it to the full detail. The box on the right is the
  // task's checkbox; clicking it reveals Fixar and Concluir under the row.
  // The box sits after the card's MouseArea, so it takes its own clicks.
  Component {
    id: agendaRow

    Rectangle {
      id: row
      required property var modelData

      readonly property bool isTask: modelData.kind === "task"
      readonly property bool isCurrent: !!root.current && root.current.id === modelData.id
      readonly property bool pinnedHere: isCurrent && root.current.pinned
      readonly property bool open: root.openId === modelData.id
      readonly property bool showActions: root.actionsId === modelData.id

      width: column.width
      height: content.implicitHeight + Style.spacing.sm * 2
      radius: Style.space(6)
      color: row.open
        ? Qt.lighter(root.surface, 1.35)
        : (face.containsMouse || row.isCurrent
            ? root.alpha(root.foreground, row.isCurrent ? 0.12 : 0.06)
            : root.surface)

      MouseArea {
        id: face
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openId = row.open ? "" : row.modelData.id
      }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.sm
        spacing: Style.space(8)

        Row {
          id: body
          width: parent.width
          spacing: Style.space(10)

          Column {
            width: body.width - box.width - body.spacing
            spacing: Style.space(3)

            Text {
              width: parent.width
              text: row.modelData.title
              color: row.modelData.completed ? root.dim : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.strikeout: row.modelData.completed
              font.bold: row.open
              elide: row.open ? Text.ElideNone : Text.ElideRight
              wrapMode: row.open ? Text.Wrap : Text.NoWrap
              maximumLineCount: row.open ? 1000 : 1
            }

            Text {
              width: parent.width
              visible: !row.open
              text: root.itemMeta(row.modelData) + (row.pinnedHere ? "  \u00b7  fixado" : "")
              color: row.modelData.overdueDays > 0 ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            // ---- detail, only on the open card: what Google Agenda shows
            Text {
              width: parent.width
              visible: row.open
              topPadding: Style.space(2)
              text: root.whenOf(row.modelData) + (row.pinnedHere ? "  \u00b7  fixado" : "")
              color: row.modelData.overdueDays > 0 ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Text {
              width: parent.width
              visible: row.open && row.modelData.completed && !!row.modelData.completedAt
              text: "Conclusão: " + root.longDate(row.modelData.completedAt)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Text {
              width: parent.width
              visible: row.open && !!row.modelData.notes
              topPadding: Style.space(6)
              text: row.modelData.notes || ""
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Text {
              width: parent.width
              visible: row.open && row.isTask && !!row.modelData.listTitle
              topPadding: Style.space(6)
              text: row.modelData.listTitle || ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }

          PanelActionButton {
            id: box
            iconText: row.isTask
              ? (row.modelData.completed ? "󰄲" : "󰄱")
              : "󰃭"
            tooltipText: row.isTask ? "Fixar ou concluir" : "Fixar"
            foreground: row.isTask
              ? (row.modelData.completed ? root.dim : root.foreground)
              : (row.modelData.color || root.foreground)
            fontFamily: root.fontFamily
            bordered: true
            onClicked: {
              console.warn("agenda/box", row.showActions ? "close" : "open", row.modelData.id)
              root.actionsId = row.showActions ? "" : row.modelData.id
            }
          }
        }

        Row {
          anchors.right: parent.right
          visible: row.showActions
          spacing: Style.space(6)

          Button {
            text: row.pinnedHere ? "Soltar" : "Fixar"
            foreground: row.pinnedHere ? root.urgent : root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: {
              console.warn("agenda/action", "pin", row.modelData.id)
              root.togglePin(row.modelData)
              root.actionsId = ""
            }
          }

          Button {
            visible: row.isTask
            text: row.modelData.completed ? "Reabrir" : "Concluir"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: {
              console.warn("agenda/action", "done", row.modelData.id)
              root.toggleCompleted(row.modelData)
              root.actionsId = ""
            }
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentY + dy * Style.space(56),
                                                     Math.max(0, panelFlick.contentHeight - panelFlick.height)))
      }
      onActivateRequested: root.primaryAction()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") agenda.refresh() }
      // The name field needs its keys; without this "r" would sync and Esc
      // would close the whole panel mid-typing.
      blocked: quickField.activeFocus

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          // ------------------------------------------------- hero: o AGORA
          PanelHero {
            width: parent.width
            title: root.current ? root.current.title : (agenda.connected ? "Sem tarefas hoje" : "Google desconectado")
            meta: root.current
              ? root.itemMeta(root.current) + (root.current.pinned ? "  ·  fixado" : "")
              : agenda.syncStatus
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // -------------------------------------------------------- acoes
          Row {
            width: parent.width
            spacing: Style.space(8)

            PanelActionButton {
              iconText: agenda.connected ? "󰑐" : "󰊭"
              tooltipText: agenda.connected ? "Sincronizar agora (R)" : "Conectar o Google"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !agenda.busy
              bordered: true
              onClicked: root.primaryAction()
            }

            PanelActionButton {
              visible: agenda.connected
              iconText: root.quickOpen ? "󰅖" : "󰐕"
              tooltipText: root.quickOpen ? "Fechar tarefa rápida" : "Tarefa rápida"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.quickOpen ? root.closeQuick() : root.openQuick()
            }

            PanelActionButton {
              visible: !!root.current && root.current.pinned
              iconText: "󰐃"
              tooltipText: "Soltar o AGORA (volta ao automatico)"
              foreground: root.urgent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: agenda.clearNow()
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: agenda.lastError !== "" ? agenda.lastError : agenda.syncStatus
              color: agenda.lastError !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: Math.max(0, column.width - Style.space(130))
            }
          }

          // --------------------------------------------------- tarefa rapida
          Column {
            width: parent.width
            visible: root.quickOpen
            spacing: Style.space(8)

            Text {
              text: "PRIORIDADE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: agenda.quickOptions.priorities
                delegate: Button {
                  required property var modelData
                  text: `${modelData.emoji} ${modelData.label}`
                  tooltipText: modelData.tooltip || ""
                  selected: root.quickPriority === modelData.value
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !root.quickSending
                  onClicked: root.quickPriority = modelData.value
                }
              }
            }

            Text {
              text: "CATEGORIA"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: agenda.quickOptions.categories
                delegate: Button {
                  required property var modelData
                  text: `${modelData.emoji} ${modelData.label}`
                  selected: root.quickCategory === modelData.value
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !root.quickSending
                  onClicked: root.quickCategory = modelData.value
                }
              }
            }

            TextField {
              id: quickField
              width: parent.width
              placeholderText: "Nome da tarefa..."
              foreground: root.foreground
              font.family: root.fontFamily
              enabled: !root.quickSending
              onAccepted: root.submitQuick()
              Keys.onEscapePressed: root.closeQuick()
            }

            Text {
              width: parent.width
              visible: agenda.lastError !== "" && !root.quickSending
              text: agenda.lastError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(6)

              Button {
                text: "Cancelar"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.quickSending
                onClicked: root.closeQuick()
              }

              Button {
                text: root.quickSending ? "Criando…" : "Criar"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: root.quickReady
                opacity: enabled || root.quickSending ? 1 : 0.45
                onClicked: root.submitQuick()
              }
            }
          }

          PanelSeparator {
            width: parent.width
            visible: agenda.items.length > 0
          }


          // ------------------------------------------------------ hoje
          PanelSectionHeader {
            width: parent.width
            text: "HOJE"
            foreground: root.foreground
            fontFamily: root.fontFamily
            visible: agenda.daemonAlive && agenda.connected
          }

          Repeater {
            model: agenda.todayItems
            delegate: agendaRow
          }

          Text {
            width: parent.width
            visible: agenda.connected && agenda.todayItems.length === 0
            text: "Nada na agenda de hoje."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          // -------------------------------------------------- atrasadas
          PanelSeparator {
            width: parent.width
            visible: agenda.overdueItems.length > 0
          }

          // The backlog stays folded: it is reference, not the day's plan.
          Rectangle {
            id: overdueToggle
            width: parent.width
            visible: agenda.overdueItems.length > 0
            implicitHeight: overdueRow.implicitHeight + Style.spacing.sm * 2
            radius: Style.space(6)
            color: overdueHover.containsMouse
              ? root.alpha(root.foreground, 0.06)
              : "transparent"

            MouseArea {
              id: overdueHover
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
              cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: root.showOverdue = !root.showOverdue
            }

            Row {
              id: overdueRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.sm
              anchors.rightMargin: Style.spacing.sm
              spacing: Style.space(10)

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.showOverdue ? "󰅀" : "󰅂"
                tooltipText: root.showOverdue ? "Recolher atrasadas" : "Mostrar atrasadas"
                foreground: root.urgent
                hoverColor: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.showOverdue = !root.showOverdue
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: agenda.overdueItems.length === 1
                  ? "1 tarefa atrasada"
                  : agenda.overdueItems.length + " tarefas atrasadas"
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.showOverdue

            Repeater {
              model: agenda.overdueItems
              delegate: agendaRow
            }
          }

          // ------------------------------------------------- estados vazios
          Text {
            width: parent.width
            visible: !agenda.daemonAlive || !agenda.connected
            text: !agenda.daemonAlive
              ? "O daemon nao esta rodando.\nsystemctl --user start agenda-flutuante"
              : "Conecte o Google para ver a agenda."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
