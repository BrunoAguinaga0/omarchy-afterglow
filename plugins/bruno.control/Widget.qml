import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Control center: one pill (network, sound, battery) that opens a panel with
// quick toggles and sliders. Tiles only appear for hardware that exists.
Panel {
  id: root
  moduleName: "bruno.control"
  ipcTarget: "bruno.control"

  function glyph(cp) { return String.fromCodePoint(cp) }
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property bool vertical: bar ? bar.vertical === true : false

  // ── Network (nmcli: cheap, polled) ──
  property string netType: ""      // "wifi" | "ethernet" | ""
  property string netName: ""
  property bool hasWifiDevice: false
  readonly property bool wifiOn: Networking.wifiEnabled

  function parseDevices(text) {
    var type = "", name = "", wifi = false
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length && i < 64; i++) {
      var f = lines[i].split(":")
      if (f.length < 3) continue
      if (f[0] === "wifi") wifi = true
      if (f[1] === "connected" && (f[0] === "ethernet" || f[0] === "wifi") && type === "") {
        type = f[0]
        name = f.slice(2).join(":").slice(0, 40)
      }
    }
    netType = type
    netName = name
    hasWifiDevice = wifi
  }

  Process {
    id: netProc
    command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseDevices(text) }
  }
  Timer {
    interval: root.opened ? 4000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!netProc.running) netProc.running = true
  }

  readonly property string netGlyph: netType === "ethernet" ? glyph(0xf0200) : (netType === "wifi" ? glyph(0xf05a9) : glyph(0xf05aa))

  // ── Bluetooth ──
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool hasBluetooth: btAdapter !== null
  readonly property string btDevice: {
    var list = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].connected) return list[i].name || ""
    return ""
  }

  // ── Sound ──
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.sink, root.source].filter(function(o) { return !!o }) }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  readonly property real micVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool micMuted: source && source.audio ? source.audio.muted : false
  readonly property string volumeGlyph: muted || volume <= 0.001 ? glyph(0xf075f) : (volume < 0.34 ? glyph(0xf057f) : (volume < 0.67 ? glyph(0xf0580) : glyph(0xf057e)))

  // ── Battery ──
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!(battery && battery.isPresent)
  readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * (battery.percentage <= 1 ? 100 : 1)) : 0

  // ── Night light / do not disturb (polled while open) ──
  property bool nightLight: false
  property bool dnd: false
  Process {
    id: nightProc
    command: ["omarchy", "toggle", "nightlight", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.nightLight = JSON.parse(text).enabled === true } catch (e) {}
      }
    }
  }
  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.dnd = String(text).trim() === "on" }
  }
  // Music lights (frame around the windows and the pill's halo), owned by bruno.music.
  property bool musicLights: true
  Process {
    id: lightsProc
    command: ["omarchy-shell", "bruno.lights", "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.musicLights = String(text).trim() !== "off" }
  }
  Process { id: actionProc; onExited: root.refreshToggles() }
  function refreshToggles() {
    if (!nightProc.running) nightProc.running = true
    if (!dndProc.running) dndProc.running = true
    if (!lightsProc.running) lightsProc.running = true
  }
  function run(cmd) {
    if (actionProc.running) return
    actionProc.command = cmd
    actionProc.running = true
  }
  onOpenedChanged: if (opened) { refreshToggles(); if (!netProc.running) netProc.running = true }

  // Colours: volume follows the playing cover, like the new OSD.
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var playingPlayer: {
    for (var i = 0; i < players.length; i++) if (players[i] && players[i].isPlaying) return players[i]
    return null
  }
  CoverPalette {
    id: coverColors
    artUrl: root.playingPlayer ? (root.playingPlayer.trackArtUrl || "") : ""
    opacity: 0
  }

  // ── Pill ──
  visible: !vertical
  implicitWidth: visible ? pill.width + Style.space(4) : 0
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Rectangle {
    id: pill
    anchors.centerIn: parent
    height: Math.round(root.implicitHeight * 0.82)
    width: pillRow.implicitWidth + Style.space(18)
    radius: height / 2
    // Neutral like the other islands; the accent is kept for what is active.
    color: Util.alpha(root.fg, hover.hovered || root.opened ? 0.14 : 0.07)
    border.width: 1
    border.color: Util.alpha(root.fg, hover.hovered || root.opened ? 0.25 : 0.14)
    Behavior on color { ColorAnimation { duration: Style.duration(150) } }

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: Style.space(9)

      PillText { text: root.netGlyph; opacity: root.netType === "" ? 0.5 : 1 }
      PillText { visible: root.hasBluetooth; text: root.glyph(0xf00af); opacity: root.btAdapter && root.btAdapter.enabled ? 1 : 0.5 }
      PillText { text: root.volumeGlyph }
      PillText {
        text: root.hasBattery ? Commons.I18n.formatNumber(root.batteryPercent) + "%" : Commons.I18n.formatNumber(Math.round(root.volume * 100)) + "%"
        font.pixelSize: Style.font.bodySmall
      }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
        else root.toggle()
      }
      onWheel: function(wheel) {
        if (!root.sink || !root.sink.audio) return
        var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
        root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step))
      }
    }
  }

  component PillText: Text {
    textFormat: Text.PlainText
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: root.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  // ── Panel ──
  KeyboardPanel {
    id: panel
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: Style.space(380)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        Grid {
          id: tiles
          width: parent.width
          columns: 2
          spacing: Style.space(10)
          readonly property real tileWidth: (width - spacing) / 2

          Tile {
            title: "Red"
            subtitle: root.netType === "ethernet" ? "Cable · " + root.netName : (root.netType === "wifi" ? root.netName : "Sin conexión")
            icon: root.netGlyph
            active: root.netType !== ""
            onClicked: root.run(["omarchy-shell", "omarchy.network", "open"])
          }
          Tile {
            visible: root.hasWifiDevice
            title: "Wi‑Fi"
            subtitle: root.wifiOn ? (root.netType === "wifi" ? root.netName : "Encendido") : "Apagado"
            icon: root.glyph(root.wifiOn ? 0xf05a9 : 0xf05aa)
            active: root.wifiOn
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
          }
          Tile {
            visible: root.hasBluetooth
            title: "Bluetooth"
            subtitle: root.btAdapter && root.btAdapter.enabled ? (root.btDevice || "Encendido") : "Apagado"
            icon: root.glyph(0xf00af)
            active: root.btAdapter && root.btAdapter.enabled
            onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
          }
          Tile {
            title: "No molestar"
            subtitle: root.dnd ? "Activado" : "Apagado"
            icon: root.glyph(root.dnd ? 0xf009b : 0xf009a)
            active: root.dnd
            onClicked: root.run(["omarchy-toggle-notification-silencing"])
          }
          Tile {
            title: "Luz nocturna"
            subtitle: root.nightLight ? "Encendida" : "Apagada"
            icon: root.glyph(0xf0594)
            active: root.nightLight
            onClicked: root.run(["omarchy", "toggle", "nightlight"])
          }
          Tile {
            title: "Micrófono"
            subtitle: root.micMuted ? "Silenciado" : "Activo"
            icon: root.glyph(root.micMuted ? 0xf036d : 0xf036c)
            active: !root.micMuted
            onClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
          }
          Tile {
            title: "Luces de música"
            subtitle: root.musicLights ? "Encendidas" : "Apagadas"
            icon: root.glyph(root.musicLights ? 0xf075a : 0xf075b)
            active: root.musicLights
            onClicked: root.run(["omarchy-shell", "bruno.lights", "toggle"])
          }
        }

        SliderRow {
          label: "Volumen"
          icon: root.volumeGlyph
          value: root.volume
          tones: coverColors.colors
          onMoved: function(v) { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
          onIconClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
        }

        SliderRow {
          label: "Micrófono"
          icon: root.glyph(root.micMuted ? 0xf036d : 0xf036c)
          value: root.micMuted ? 0 : root.micVolume
          tones: [Commons.Color.accent, Commons.Color.accent, Commons.Color.accent]
          onMoved: function(v) { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v } }
          onIconClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            visible: root.hasBattery
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "Batería " + Commons.I18n.formatNumber(root.batteryPercent) + "%"
            color: Util.alpha(root.fg, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Item { width: 1; height: 1 }
          Button {
            text: "Audio…"
            onClicked: { root.close(); root.run(["omarchy-shell", "omarchy.audio", "open"]) }
          }
          Button {
            text: "Pantalla…"
            onClicked: { root.close(); root.run(["omarchy-shell", "omarchy.monitor", "open"]) }
          }
        }
      }
    }
  }

  // Big rounded toggle tile.
  component Tile: Rectangle {
    id: tile
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool active: false
    signal clicked()

    width: tiles.tileWidth
    height: Style.space(58)
    radius: Math.min(Style.cornerRadius, height / 2)
    color: active ? Commons.Color.accent : Util.alpha(root.fg, tileHover.hovered ? 0.12 : 0.07)
    Behavior on color { ColorAnimation { duration: Style.duration(150) } }
    readonly property color ink: active ? ((0.2126 * Commons.Color.accent.r + 0.7152 * Commons.Color.accent.g + 0.0722 * Commons.Color.accent.b) > 0.55 ? "#151515" : "#ffffff") : root.fg

    Row {
      anchors.verticalCenter: parent.verticalCenter
      x: Style.space(12)
      spacing: Style.space(10)
      width: parent.width - Style.space(24)

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: tile.icon
        color: tile.ink
        font.family: Style.font.family
        font.pixelSize: Style.font.title
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(34)
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: tile.title
          color: tile.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: tile.subtitle
          color: Util.alpha(tile.ink, 0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: tile.clicked() }
  }

  // Label, icon (click to mute) and a rounded gradient slider.
  component SliderRow: Item {
    id: sliderRow
    property string label: ""
    property string icon: ""
    property real value: 0
    property var tones: [Commons.Color.accent, Commons.Color.accent, Commons.Color.accent]
    signal moved(real v)
    signal iconClicked()

    width: parent ? parent.width : 0
    height: Style.space(30)

    Text {
      id: sliderIcon
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(26)
      text: sliderRow.icon
      color: root.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sliderRow.iconClicked() }
    }

    Item {
      id: track
      anchors.left: sliderIcon.right
      anchors.leftMargin: Style.space(8)
      anchors.right: pct.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Style.space(12)

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Util.alpha(root.fg, 0.12)
      }
      Rectangle {
        height: parent.height
        radius: height / 2
        width: Math.max(sliderRow.value > 0 ? height : 0, parent.width * Math.max(0, Math.min(1, sliderRow.value)))
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: sliderRow.tones[0] }
          GradientStop { position: 0.5; color: sliderRow.tones[1 % sliderRow.tones.length] }
          GradientStop { position: 1.0; color: sliderRow.tones[2 % sliderRow.tones.length] }
        }
      }
      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(8)
        cursorShape: Qt.PointingHandCursor
        function set(mx) { sliderRow.moved(Math.max(0, Math.min(1, (mx - Style.space(8)) / track.width))) }
        onPressed: function(mouse) { set(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) set(mouse.x) }
      }
    }

    Text {
      id: pct
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(40)
      horizontalAlignment: Text.AlignRight
      text: Commons.I18n.formatNumber(Math.round(sliderRow.value * 100)) + "%"
      color: root.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }
}
