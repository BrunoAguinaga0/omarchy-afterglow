import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
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
  Component.onCompleted: recentlyPlaying = playing
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

  Rectangle {
    id: pill
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    height: Math.round(root.implicitHeight * 0.82)
    width: row.implicitWidth + Style.space(14)
    radius: height / 2
    color: Util.alpha(root.tones[0], hover.hovered || root.opened ? 0.3 : 0.18)
    border.width: 1
    border.color: Util.alpha(root.tones[0], 0.6)
    Behavior on color { ColorAnimation { duration: Style.duration(150) } }

    Row {
      id: row
      anchors.verticalCenter: parent.verticalCenter
      x: Style.space(3)
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
        else root.toggle()
      }
      onWheel: function(wheel) {
        if (!root.player) return
        if (wheel.angleDelta.y > 0 && root.player.canGoPrevious) root.player.previous()
        else if (wheel.angleDelta.y < 0 && root.player.canGoNext) root.player.next()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened && root.musicOn
    focusTarget: panel.loadedContent
    contentWidth: Style.space(420)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: card.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.player) return
        if (dx < 0 && root.player.canGoPrevious) root.player.previous()
        else if (dx > 0 && root.player.canGoNext) root.player.next()
      }
      onActivateRequested: if (root.player) root.player.togglePlaying()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      MediaCard {
        id: card
        width: parent.width
        height: implicitHeight
        player: root.player
        showStyleButton: false
        onPreviousRequested: if (root.player && root.player.canGoPrevious) root.player.previous()
        onPlayPauseRequested: if (root.player) root.player.togglePlaying()
        onNextRequested: if (root.player && root.player.canGoNext) root.player.next()
      }
    }
  }
}
