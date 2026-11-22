import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
  // block of ten per monitor: 1-10, 11-20, and so on (see
  // default/hypr/monitor-workspaces.lua). Each bar shows its own monitor's block,
  // numbered 1-10, and the one that monitor shows, whichever monitor has focus.
  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // The first five of the monitor's own, and any of the rest that exist. After
  // them come workspaces that are only visiting: those of a monitor that is
  // unplugged, which had no room to join this one's.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  // A wheel notch moves one entry along the row, and a touchpad adds up its
  // smaller deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    // Holds at either end rather than wrapping, so a touchpad swipe that runs
    // long stops on the last workspace.
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // The workspace each monitor shows carries its layout: a square tiles, a
  // circle scrolls, and a triangle floats. Clicking it cycles to the next one,
  // as Super + L does.
  property string activeMode: "dwindle"
  property bool modeStale: false

  function modeGlyph(mode) {
    if (mode === "scrolling") return "󰝥"
    if (mode === "floating") return "󰔶"
    return "󱓻"
  }

  // A layout only changes through the layout commands, which ask for a refresh,
  // or a config reload, so each workspace's mode is read once and cached rather
  // than running the script on every workspace switch.
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0

  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId()]
    if (mode !== undefined) root.activeMode = mode
    else readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.activeWorkspaceId()
    if (id === -1) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }

  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    readMode()
  }

  // The layout commands act on the focused workspace, so a click on another
  // monitor's bar focuses that monitor first.
  function cycleLayout() {
    if (!root.bar) return
    var command = "omarchy-hyprland-workspace-layout-toggle"
    if (root.monitor && !root.monitor.focused) {
      command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + root.monitorName + "\" })") + " >/dev/null && " + command
    }
    root.bar.run(command)
  }

  Component.onCompleted: refresh()
  onMonitorChanged: root.showActiveMode()

  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        // A read that started before a refresh may predate the change.
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId()) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      // Deferred: the process still reports running while it signals exit.
      Qt.callLater(root.showActiveMode)
    }
  }

  // Super + L and the default layout change the mode without a focus change,
  // so they ask every bar to read it again.
  ShellIpc {
    target: "omarchy.workspaces"

    function refresh(): void { root.broadcast("refresh") }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground

  // Up to three app icons per workspace, then a "+n".
  function appIds(ws) {
    if (!ws || !ws.toplevels) return []
    var list = ws.toplevels.values
    var seen = []
    for (var i = 0; i < list.length; i++) {
      var t = list[i]
      var id = t && t.wayland ? String(t.wayland.appId || "") : (t && t.lastIpcObject ? String(t.lastIpcObject["class"] || "") : "")
      if (id !== "" && seen.indexOf(id) === -1) seen.push(id)
    }
    return seen
  }

  // Windows with no desktop entry of their own, mapped to a fitting icon.
  // org.omarchy.agent is Omarchy's agent console, which runs Claude Code.
  readonly property var iconOverrides: ({
    "org.omarchy.agent": "claude-desktop"
  })

  function iconFor(appId) {
    if (iconOverrides[appId]) return Quickshell.iconPath(iconOverrides[appId], "application-x-executable")
    var entry = DesktopEntries.heuristicLookup(appId)
    var icon = entry && entry.icon ? entry.icon : appId
    return Quickshell.iconPath(icon, "application-x-executable")
  }

  implicitWidth: root.vertical ? grid.implicitWidth : wsRow.implicitWidth + trailingGap
  implicitHeight: root.vertical ? grid.implicitHeight : root.barSize

  // ── Horizontal: sliding active pill and app icons per workspace ──
  Item {
    id: wsRow
    visible: !root.vertical
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    height: root.barSize

    // The pill's two edges move at different speeds, so it stretches toward
    // the new workspace and then catches up.
    property real pillLeft: 0
    property real pillRight: 0
    property bool movingRight: true
    property bool placed: false

    function updatePill() {
      var item = null
      for (var i = 0; i < wsRepeater.count; i++) {
        var it = wsRepeater.itemAt(i)
        if (it && it.shown) { item = it; break }
      }
      if (!item) return
      var left = item.x, right = item.x + item.width
      if (!placed) {
        pillAnimLeft.enabled = false
        pillAnimRight.enabled = false
      }
      movingRight = left >= pillLeft
      pillLeft = left
      pillRight = right
      if (!placed) {
        placed = true
        pillAnimLeft.enabled = true
        pillAnimRight.enabled = true
      }
    }

    Behavior on pillLeft {
      id: pillAnimLeft
      NumberAnimation { duration: Style.duration(wsRow.movingRight ? 300 : 170); easing.type: Easing.OutCubic }
    }
    Behavior on pillRight {
      id: pillAnimRight
      NumberAnimation { duration: Style.duration(wsRow.movingRight ? 170 : 300); easing.type: Easing.OutCubic }
    }

    Rectangle {
      visible: wsRow.placed
      x: wsRow.pillLeft
      width: Math.max(0, wsRow.pillRight - wsRow.pillLeft)
      height: Math.round(root.barSize * 0.8)
      anchors.verticalCenter: parent.verticalCenter
      radius: height / 2
      color: Util.alpha(Color.accent, 0.22)
      border.width: 1
      border.color: Util.alpha(Color.accent, 0.6)
    }

    Row {
      id: row
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      onWidthChanged: Qt.callLater(wsRow.updatePill)

      Repeater {
        id: wsRepeater
        model: root.workspaceIds()
        onItemAdded: Qt.callLater(wsRow.updatePill)

        Item {
          id: cell
          required property int modelData
          required property int index
          readonly property var workspace: root.workspaceById(modelData)
          readonly property var apps: root.appIds(workspace)
          readonly property bool occupied: apps.length > 0
          readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
          readonly property int slot: root.slotOf(modelData)
          readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block

          onShownChanged: if (shown) Qt.callLater(wsRow.updatePill)
          onWidthChanged: if (shown) Qt.callLater(wsRow.updatePill)
          onXChanged: if (shown) Qt.callLater(wsRow.updatePill)

          width: content.implicitWidth + Style.space(16) + (firstGuest ? Style.space(6) : 0)
          height: root.barSize

          Rectangle {
            anchors.fill: parent
            anchors.leftMargin: cell.firstGuest ? Style.space(6) : 0
            anchors.topMargin: Math.round(root.barSize * 0.1)
            anchors.bottomMargin: Math.round(root.barSize * 0.1)
            radius: height / 2
            color: Util.alpha(root.fg, hover.hovered && !cell.shown ? 0.08 : 0)
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          }

          Row {
            id: content
            x: (cell.firstGuest ? Style.space(6) : 0) + Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: cell.slot === root.slots ? "0" : String(cell.slot)
              color: root.fg
              opacity: cell.occupied || cell.shown ? 1 : 0.5
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: cell.shown
            }

            Repeater {
              model: cell.apps.slice(0, 3)
              Image {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(root.barSize * 0.55)
                height: width
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                source: root.iconFor(modelData)
                asynchronous: true
                smooth: true
                opacity: cell.shown ? 1 : 0.75
              }
            }

            Text {
              visible: cell.apps.length > 3
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "+" + (cell.apps.length - 3)
              color: root.fg
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
              if (cell.shown) root.cycleLayout()
              else root.focusWorkspace(cell.modelData)
            }
            onWheel: function(wheel) { root.scrollWorkspaces(wheel.angleDelta.y) }
          }
        }
      }
    }
  }

  GridLayout {
    id: grid
    visible: root.vertical
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: 1
    columnSpacing: 0
    rowSpacing: Style.space(2)

    Repeater {
      model: root.vertical ? root.workspaceIds() : []

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property int slot: root.slotOf(modelData)
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block
        required property int index

        Layout.topMargin: firstGuest ? Style.space(6) : 0

        bar: root.bar
        text: shown ? root.modeGlyph(root.activeMode) : (slot === root.slots ? "0" : String(slot))
        opacity: occupied || shown ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.barSize
        fixedHeight: root.barSize
        onPressed: function() {
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }
      }
    }
  }
}
