import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Now-playing pill for the bar: tiny cover, bouncing bars and a scrolling
// title, tinted from the cover art. Click it for the full card with controls
// (the same card as the lock screen). Hidden when nothing is playing.
Panel {
  id: root
  moduleName: "bruno.music"
  ipcTarget: "bruno.music"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = players || []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying && (list[i].trackTitle || list[i].trackArtist)) return list[i]
    for (var j = 0; j < list.length; j++)
      if (list[j] && (list[j].trackTitle || list[j].trackArtist)) return list[j]
    return null
  }
  readonly property bool hasMedia: player !== null
  readonly property bool playing: hasMedia && player.isPlaying
  readonly property string title: hasMedia ? (player.trackTitle || "") : ""
  readonly property string artist: hasMedia ? (player.trackArtist || "") : ""
  readonly property string artUrl: hasMedia ? (player.trackArtUrl || "") : ""
  readonly property string label: artist !== "" ? title + " — " + artist : title
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property bool vertical: bar ? bar.vertical === true : false

  // Shown while something plays, and for a minute after it stops, so a quick
  // pause does not make the bar jump. The clock uses the same rule.
  property bool recentlyPlaying: false
  onPlayingChanged: {
    if (playing) { recentlyPlaying = true; lingerTimer.stop() }
    else lingerTimer.restart()
  }
  Component.onCompleted: { recentlyPlaying = playing; cava.running = audioWanted }
  Timer { id: lingerTimer; interval: 60000; onTriggered: root.recentlyPlaying = root.playing }
  readonly property bool musicOn: hasMedia && (playing || recentlyPlaying)
  onMusicOnChanged: if (!musicOn) close()

  property real reveal: musicOn && !vertical ? 1 : 0
  Behavior on reveal {
    NumberAnimation { duration: Style.duration(260); easing.type: Easing.OutCubic }
  }

  CoverPalette {
    id: coverColors
    artUrl: root.artUrl
    artReady: pillCover.status === Image.Ready
    opacity: 0
  }
  readonly property var tones: coverColors.colors

  visible: reveal > 0.01
  opacity: reveal
  implicitWidth: Math.round((pill.width + Style.space(4)) * reveal)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  // On the island bar the pill becomes the center island itself: same height
  // and corners as the other islands, and the island behind it is hidden.
  readonly property bool fillIsland: bar ? bar.islands === true : false
  readonly property bool yieldIsland: fillIsland && musicOn
  function syncIsland() {
    if (bar && typeof bar.setCenterIslandYielded === "function") bar.setCenterIslandYielded(yieldIsland)
  }
  onYieldIslandChanged: syncIsland()
  onBarChanged: syncIsland()
  Component.onDestruction: if (bar && typeof bar.setCenterIslandYielded === "function") bar.setCenterIslandYielded(false)

  // Aura in the cover's colors behind the pill, like the "now playing" notice.
  Rectangle {
    id: pillAura
    visible: root.lightsOn
    anchors.centerIn: pill
    width: pill.width + Style.space(16)
    height: pill.height + Style.space(11)
    radius: height / 2
    // Follows the music's bass; steady when there is no audio feed.
    opacity: root.audioLevel < 0 ? 0.75 : 0.35 + 0.65 * root.audioLevel
    Behavior on opacity { NumberAnimation { duration: 90 } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: root.tones[0] }
      GradientStop { position: 0.5; color: root.tones[1] }
      GradientStop { position: 1.0; color: root.tones[2] }
    }
    layer.enabled: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 32
      autoPaddingEnabled: true
    }
  }

  Rectangle {
    id: pill
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    height: root.fillIsland ? root.bar.islandHeight : Math.round(root.implicitHeight * 0.82)
    width: row.implicitWidth + Style.space(root.fillIsland ? 20 : 14)
    radius: root.fillIsland ? Math.min(height / 2, Style.cornerRadius) : height / 2
    // Island glass underneath, tinted from the cover on top.
    color: root.fillIsland ? root.bar.islandColor : "transparent"

    Rectangle {
      id: tint
      anchors.fill: parent
      radius: parent.radius
      // The cover's colors run softly across the pill.
      readonly property real strength: hover.hovered || root.opened ? 1.35 : 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Util.alpha(root.tones[0], 0.30 * tint.strength) }
        GradientStop { position: 0.55; color: Util.alpha(root.tones[1], 0.20 * tint.strength) }
        GradientStop { position: 1.0; color: Util.alpha(root.tones[2], 0.28 * tint.strength) }
      }
      border.width: 1
      border.color: Util.alpha(root.tones[0], 0.6)
      Behavior on color { ColorAnimation { duration: Style.duration(150) } }
    }

    Row {
      id: row
      anchors.verticalCenter: parent.verticalCenter
      x: Style.space(root.fillIsland ? 5 : 3)
      spacing: Style.space(7)

      // Round cover thumbnail.
      Item {
        width: pill.height - Style.space(6)
        height: width
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          id: coverMask
          anchors.fill: parent
          radius: width / 2
          visible: false
          layer.enabled: true
        }

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: coverMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.tones[0] }
              GradientStop { position: 1.0; color: root.tones[2] }
            }
          }
          Image {
            id: pillCover
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 64
            sourceSize.height: 64
          }
        }
      }

      // Three bouncing bars; still while paused.
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        height: Math.round(pill.height * 0.5)
        Repeater {
          model: 3
          Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: 2
            radius: 1
            color: root.tones[index]
            property real level: 0.4
            height: Math.max(2, parent.height * level)
            SequentialAnimation on level {
              running: root.playing && !Style.reduceMotion
              loops: Animation.Infinite
              NumberAnimation { to: 1; duration: 260 + index * 90; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.25; duration: 300 + index * 70; easing.type: Easing.InOutSine }
            }
          }
        }
      }

      // Title that scrolls back and forth when it does not fit.
      Item {
        id: marquee
        width: Math.min(Style.space(160), label.implicitWidth)
        height: pill.height
        clip: true
        anchors.verticalCenter: parent.verticalCenter
        readonly property real overflow: Math.max(0, label.implicitWidth - width)

        Text {
          id: label
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.label
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          opacity: root.playing ? 1 : 0.65

          SequentialAnimation on x {
            running: marquee.overflow > 0 && !Style.reduceMotion && root.hasMedia
            loops: Animation.Infinite
            PauseAnimation { duration: 1500 }
            NumberAnimation { from: 0; to: -marquee.overflow; duration: marquee.overflow * 30; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1500 }
            NumberAnimation { from: -marquee.overflow; to: 0; duration: marquee.overflow * 30; easing.type: Easing.InOutSine }
          }
        }
      }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) { if (root.player) root.player.togglePlaying() }
        else if (mouse.button === Qt.RightButton) { if (root.player && root.player.canGoNext) root.player.next() }
        else if (root.hoverOpen) root.hoverOpen = false
        else root.toggle()
      }
      onWheel: function(wheel) {
        if (!root.player) return
        if (wheel.angleDelta.y > 0 && root.player.canGoPrevious) root.player.previous()
        else if (wheel.angleDelta.y < 0 && root.player.canGoNext) root.player.next()
      }
    }
  }

  // Track changes made from the menu are not announced by the lock screen's
  // "now playing" pill (bibek.lock).
  function quietAnnounce() {
    if (bar && typeof bar.run === "function") bar.run("omarchy-shell -q lock quietNowPlaying 5000")
  }
  function previous() { if (player && player.canGoPrevious) { quietAnnounce(); player.previous() } }
  function next() { if (player && player.canGoNext) { quietAnnounce(); player.next() } }

  // ── "Luces de música" switch ──
  // Turns off the light frame around the windows and the pill's beating halo
  // (cava stops too). Saved in a state file so it survives restarts; the
  // control center toggles it with: omarchy-shell bruno.lights toggle
  property bool lightsOn: true
  FileView {
    id: lightsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/bruno-music-lights"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.lightsOn = String(text()).trim() !== "off"
    onLoadFailed: root.lightsOn = true
  }
  function setLights(on) {
    root.lightsOn = on
    lightsFile.setText(on ? "on\n" : "off\n")
  }
  IpcHandler {
    target: "bruno.lights"
    function status(): string { return root.lightsOn ? "on" : "off" }
    function toggle(): string { root.setLights(!root.lightsOn); return root.lightsOn ? "on" : "off" }
    function on(): string { root.setLights(true); return "on" }
    function off(): string { root.setLights(false); return "off" }
  }

  // Live audio level (0-1) for the auras, from cava while music plays;
  // -1 means no feed. Low bands weigh most, so the glow beats with the bass.
  property real audioLevel: -1
  readonly property bool audioWanted: playing && !vertical && !Style.reduceMotion && lightsOn
  property int cavaFailures: 0
  onAudioWantedChanged: {
    if (!audioWanted) { audioLevel = -1; cavaFailures = 0 }
    cava.running = audioWanted && cavaFailures < 3
  }

  function handleCavaFrame(line) {
    var parts = String(line).split(";")
    var v = []
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] === "") continue
      if (!/^[0-9]{1,3}$/.test(parts[i])) return
      v.push(Math.min(100, parseInt(parts[i], 10)) / 100)
    }
    if (v.length < 3) return
    audioLevel = Math.min(1, 0.65 * v[0] + 0.25 * v[1] + 0.1 * v[2])
  }

  Process {
    id: cava
    command: ["/usr/bin/stdbuf", "-oL", "/usr/bin/cava", "-p",
      decodeURIComponent(String(Qt.resolvedUrl("cava.conf")).replace(/^file:\/\//, ""))]
    stdout: SplitParser { onRead: function(data) { root.handleCavaFrame(data) } }
    onExited: function(exitCode) {
      root.audioLevel = -1
      if (root.audioWanted) { root.cavaFailures += 1; cavaRetry.restart() }
    }
  }
  Timer {
    id: cavaRetry
    interval: 2000
    onTriggered: cava.running = root.audioWanted && root.cavaFailures < 3
  }

  // Hover: the menu opens while the pointer rests on the pill and closes once
  // it has left both the pill and the menu. A click pins it open.
  property bool hoverOpen: false
  property bool cardHovered: false
  property bool pillShadowHovered: false
  // While the menu is open by hover, the pointer is also tracked by asking
  // Hyprland where it is: with the panel's full-screen surface mapped over the
  // bar, hover events over the pill are unreliable.
  property bool polledInside: false
  readonly property bool polling: hoverOpen && opened
  onPollingChanged: if (!polling) polledInside = false
  Timer {
    interval: 50
    repeat: true
    running: root.polling
    triggeredOnStart: true
    onTriggered: if (!cursorProc.running) cursorProc.running = true
  }
  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = String(text).match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/)
        if (!m || !root.polling) return
        var x = parseFloat(m[1]), y = parseFloat(m[2])
        var pp = pill.mapToGlobal(0, 0)
        var m1 = Style.space(6), m2 = Style.space(10)
        var inPill = x >= pp.x - m1 && x <= pp.x + pill.width + m1 && y >= 0 && y <= pp.y + pill.height + m1
        var cx = panel.cardOrigin.x, cy = panel.cardOrigin.y
        var inCard = x >= cx - m2 && x <= cx + panel.contentWidth + m2 && y >= cy - m2 && y <= cy + panel.drawnHeight + m2
        var left = Math.max(pp.x, cx), right = Math.min(pp.x + pill.width, cx + panel.contentWidth)
        var inGap = x >= left && x <= right && y >= pp.y && y <= cy
        root.polledInside = inPill || inCard || inGap
      }
    }
  }
  readonly property bool pointerInside: hover.hovered || cardHovered || pillShadowHovered || polledInside
  onOpenedChanged: { if (!opened) { pillShadowHovered = false; hoverOpen = false } }
  onPointerInsideChanged: {
    if (pointerInside) { closeDelay.stop(); if (!opened && musicOn) openDelay.restart() }
    else { openDelay.stop(); if (hoverOpen) closeDelay.restart() }
  }
  Timer {
    id: openDelay
    interval: 180
    onTriggered: if (root.pointerInside && !root.opened && root.musicOn) { root.hoverOpen = true; root.open() }
  }
  Timer {
    id: closeDelay
    interval: 120
    onTriggered: if (root.hoverOpen && !root.pointerInside) root.close()
  }

  MusicPanel {
    id: panel
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened && root.musicOn
    focusTarget: panel.loadedContent
    contentWidth: Style.space(420)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)
    // The music card is the whole menu: no frame or padding around it.
    padding: 0
    borderSpec: ({ color: "transparent", widths: { top: 0, right: 0, bottom: 0, left: 0 }, gradient: null })
    // Opened by hover it must not steal the keyboard from the app in use.
    WlrLayershell.keyboardFocus: panel.open && !root.hoverOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // The panel's full-screen surface sits over the pill too, so once it is
    // open the pill stops feeling the pointer. This invisible patch over the
    // pill, inside the panel, keeps the pointer counted as "on the pill";
    // a click there behaves like a click on the pill.
    Item {
      readonly property point pillPos: pill.mapToGlobal(0, 0)
      x: pillPos.x - Style.space(4)
      y: 0
      width: pill.width + Style.space(8)
      height: pillPos.y + pill.height + Style.space(4)
      visible: panel.open
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.pillShadowHovered = containsMouse
        onClicked: { if (root.hoverOpen) root.hoverOpen = false; else root.close() }
      }
    }

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: card.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.player) return
        if (dx < 0) root.previous()
        else if (dx > 0) root.next()
      }
      onActivateRequested: if (root.player) root.player.togglePlaying()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // Aura in the cover's colors behind the menu, like the "now playing" notice.
      Rectangle {
        id: menuAura
        anchors.fill: parent
        anchors.margins: -Style.space(10)
        radius: Style.cornerRadius + Style.space(10)
        // Softer than the pill's, and following the music's bass.
        opacity: root.audioLevel < 0 ? 0.45 : 0.22 + 0.43 * root.audioLevel
        Behavior on opacity { NumberAnimation { duration: 90 } }
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.tones[0] }
          GradientStop { position: 0.5; color: root.tones[1] }
          GradientStop { position: 1.0; color: root.tones[2] }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1.0
          blurMax: 32
          autoPaddingEnabled: true
        }
      }

      HoverHandler {
        onHoveredChanged: root.cardHovered = hovered
        Component.onDestruction: root.cardHovered = false
      }

      MediaCard {
        id: card
        width: parent.width
        height: implicitHeight
        player: root.player
        showStyleButton: false
        vivid: true
        onBodyClicked: {
          if (root.player && root.player.canRaise) root.player.raise()
          root.close()
        }
        onPreviousRequested: root.previous()
        onPlayPauseRequested: if (root.player) root.player.togglePlaying()
        onNextRequested: root.next()
      }
    }
  }

  // ── Light frame around the open apps ──
  // While music plays, the tiled windows of the active workspace are taken as
  // one block, and a glow in the cover's colors frames its four outer walls,
  // beating with the bass like the pill. It sits under the windows, so it only
  // shows in the gaps around the block.
  property rect appsBlock: Qt.rect(0, 0, 0, 0)
  readonly property bool frameWanted: playing && !vertical && lightsOn

  function refreshBlock() {
    if (frameWanted && !blockQuery.running) blockQuery.running = true
  }
  onFrameWantedChanged: refreshBlock()

  Process {
    id: blockQuery
    command: ["sh", "-c", "hyprctl -j activeworkspace; echo '\u001e'; hyprctl -j clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parts = text.split("\u001e")
          var ws = JSON.parse(parts[0])
          var clients = JSON.parse(parts[1])
          if (ws.hasfullscreen) { root.appsBlock = Qt.rect(0, 0, 0, 0); return }
          var x1 = 1e9, y1 = 1e9, x2 = -1e9, y2 = -1e9, n = 0
          for (var i = 0; i < clients.length; i++) {
            var c = clients[i]
            if (!c.mapped || c.hidden || c.floating || c.workspace.id !== ws.id) continue
            x1 = Math.min(x1, c.at[0]); y1 = Math.min(y1, c.at[1])
            x2 = Math.max(x2, c.at[0] + c.size[0]); y2 = Math.max(y2, c.at[1] + c.size[1])
            n++
          }
          root.appsBlock = n > 0 ? Qt.rect(x1, y1, x2 - x1, y2 - y1) : Qt.rect(0, 0, 0, 0)
        } catch (e) {
          root.appsBlock = Qt.rect(0, 0, 0, 0)
        }
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event.name
      if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
          || n === "workspace" || n === "workspacev2" || n === "fullscreen" || n === "changefloatingmode"
          || n === "focusedmon" || n === "activewindowv2")
        blockRefresh.restart()
    }
  }
  // Events arrive before the layout settles; ask a moment later. A slow poll
  // catches resizes, which Hyprland does not announce.
  Timer { id: blockRefresh; interval: 160; onTriggered: root.refreshBlock() }
  Timer { interval: 1500; repeat: true; running: root.frameWanted; onTriggered: root.refreshBlock() }

  PanelWindow {
    id: frameLayer
    readonly property bool on: root.frameWanted && root.appsBlock.width > 0
    property real shown: on ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    visible: shown > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "bruno-music-frame"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // Cached blur: it is redrawn only when the block or the colors change;
    // the beat only moves the opacity.
    Item {
      id: frameGlow
      readonly property int ring: Style.space(10)
      x: root.appsBlock.x - ring
      y: root.appsBlock.y - ring
      width: root.appsBlock.width + ring * 2
      height: root.appsBlock.height + ring * 2
      Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      opacity: frameLayer.shown * (root.audioLevel < 0 ? 0.7 : 0.3 + 0.7 * root.audioLevel)
      Behavior on opacity { NumberAnimation { duration: 90 } }
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        autoPaddingEnabled: true
      }

      // Four walls drawn separately so the top one can stay faint: the
      // pill keeps the spotlight up there. The blur rounds the corners.
      readonly property int wall: ring * 2
      Rectangle {
        x: 0; y: 0; width: parent.width; height: frameGlow.wall
        radius: height / 2
        opacity: 0.3
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.tones[0] }
          GradientStop { position: 0.5; color: root.tones[1] }
          GradientStop { position: 1.0; color: root.tones[2] }
        }
      }
      Rectangle {
        x: 0; y: parent.height - height; width: parent.width; height: frameGlow.wall
        radius: height / 2
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.tones[0] }
          GradientStop { position: 0.5; color: root.tones[1] }
          GradientStop { position: 1.0; color: root.tones[2] }
        }
      }
      Rectangle {
        x: 0; y: frameGlow.wall / 2; width: frameGlow.wall; height: parent.height - frameGlow.wall
        radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0.0; color: Util.alpha(root.tones[0], 0.4) }
          GradientStop { position: 0.35; color: root.tones[0] }
          GradientStop { position: 1.0; color: root.tones[0] }
        }
      }
      Rectangle {
        x: parent.width - width; y: frameGlow.wall / 2; width: frameGlow.wall; height: parent.height - frameGlow.wall
        radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0.0; color: Util.alpha(root.tones[2], 0.4) }
          GradientStop { position: 0.35; color: root.tones[2] }
          GradientStop { position: 1.0; color: root.tones[2] }
        }
      }
    }
  }
}
