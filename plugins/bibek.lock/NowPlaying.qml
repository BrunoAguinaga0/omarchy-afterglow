import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Commons

// "Now playing" pill that drops from under the bar, centred, for a few seconds
// whenever the track changes. Its glow uses the cover's colours. Clicking it
// raises the player.
PanelWindow {
  id: win

  property bool suppressed: false
  // Until this time (ms since epoch) track changes are not announced; set over
  // IPC by bruno.music when the track is changed from its own menu.
  property double quietUntil: 0
  property int holdMs: 4000

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = players || [];
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying && (list[i].trackTitle || list[i].trackArtist))
        return list[i];
    return null;
  }
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property string trackKey: title + "\u0001" + artist

  // Snapshot shown in the pill, so it does not change while leaving.
  property string shownTitle: ""
  property string shownArtist: ""
  property string shownArt: ""
  property var shownPlayer: null
  property string lastKey: ""
  property bool showing: false
  property bool ready: false

  function announce() {
    if (!player || title === "")
      return;
    shownTitle = title;
    shownArtist = artist;
    shownArt = artUrl;
    shownPlayer = player;
    showing = true;
    hideTimer.restart();
  }

  // Ignore whatever is playing when the shell starts; announce real changes.
  Timer {
    interval: 3000
    running: true
    onTriggered: {
      win.lastKey = win.trackKey;
      win.ready = true;
    }
  }

  // Players often send title and artist in separate updates; settle first.
  onTrackKeyChanged: settleTimer.restart()
  Timer {
    id: settleTimer
    interval: 350
    onTriggered: {
      if (!win.ready || win.trackKey === win.lastKey || win.title === "")
        return;
      win.lastKey = win.trackKey;
      if (!win.suppressed && Date.now() >= win.quietUntil)
        win.announce();
    }
  }

  // The art URL can arrive after the title.
  onArtUrlChanged: if (showing && player === shownPlayer) shownArt = artUrl

  Timer {
    id: hideTimer
    interval: win.holdMs
    onTriggered: if (!pillArea.containsMouse) win.showing = false; else restart()
  }

  onSuppressedChanged: if (suppressed) showing = false

  visible: showing || stage.opacity > 0
  anchors.top: true
  margins.top: 8
  implicitWidth: 580
  implicitHeight: 150
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.namespace: "omarchy-now-playing"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { item: pill }

  CoverPalette {
    id: coverColors
    artUrl: win.shownArt
    artReady: cover.status === Image.Ready
    opacity: 0
  }

  Item {
    id: stage
    anchors.fill: parent
    opacity: win.showing ? 1 : 0
    Behavior on opacity {
      NumberAnimation { duration: Style.duration(win.showing ? 220 : 260); easing.type: Easing.OutCubic }
    }

    property real drop: win.showing ? 0 : -40
    Behavior on drop {
      NumberAnimation { duration: Style.duration(win.showing ? 420 : 260); easing.type: win.showing ? Easing.OutBack : Easing.InCubic }
    }

    // Soft glow in the cover's colours, breathing gently.
    Rectangle {
      id: glow
      x: pill.x - 6
      y: pill.y + stage.drop - 2
      width: pill.width + 12
      height: pill.height + 4
      radius: height / 2
      property real pulse: 0.7
      opacity: pulse
      SequentialAnimation on pulse {
        running: win.showing && !Style.reduceMotion
        loops: Animation.Infinite
        NumberAnimation { from: 0.75; to: 1; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0.75; duration: 900; easing.type: Easing.InOutSine }
      }
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: coverColors.colors[0] }
        GradientStop { position: 0.5; color: coverColors.colors[1] }
        GradientStop { position: 1.0; color: coverColors.colors[2] }
      }
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        autoPaddingEnabled: true
      }
    }

    MouseArea {
      id: pillArea
      anchors.fill: pill
      anchors.topMargin: -stage.drop
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (win.shownPlayer && win.shownPlayer.canRaise)
          win.shownPlayer.raise();
        win.showing = false;
      }
    }

    Rectangle {
      id: pill
      width: 500
      height: 96
      x: (parent.width - width) / 2
      y: 14
      transform: Translate { y: stage.drop }
      radius: Style.cornerRadius + 2
      color: Util.alpha(Color.notifications.background, 0.92)
      border.width: 1
      border.color: Util.alpha(coverColors.colors[0], 0.9)

      // The cover's colors wash across the pill.
      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Util.alpha(coverColors.colors[0], 0.34) }
          GradientStop { position: 0.5; color: Util.alpha(coverColors.colors[1], 0.18) }
          GradientStop { position: 1.0; color: Util.alpha(coverColors.colors[2], 0.30) }
        }
      }

      Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        Item {
          width: 68
          height: 68
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: Math.max(4, Style.cornerRadius - 6)
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
                GradientStop { position: 0.0; color: coverColors.colors[0] }
                GradientStop { position: 1.0; color: coverColors.colors[2] }
              }
            }
            Image {
              id: cover
              anchors.fill: parent
              source: win.shownArt
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 136
              sourceSize.height: 136
            }
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 68 - 16 - eq.width - 16
          spacing: 3

          Text {
            text: "AHORA SUENA"
            color: coverColors.colors[0]
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
            font.weight: Font.DemiBold
          }
          Text {
            width: parent.width
            text: win.shownTitle
            color: Color.notifications.text
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.body * 1.2)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            visible: text !== ""
            text: win.shownArtist
            color: Util.alpha(Color.notifications.text, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
        }

        // Three small bouncing bars.
        Row {
          id: eq
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          height: 26
          Repeater {
            model: 3
            Rectangle {
              required property int index
              anchors.bottom: parent.bottom
              width: 4
              radius: 2
              color: coverColors.colors[index]
              property real level: 0.5
              height: 5 + 21 * level
              SequentialAnimation on level {
                running: win.showing && !Style.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 280 + index * 90; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.25; duration: 320 + index * 70; easing.type: Easing.InOutSine }
              }
            }
          }
        }
      }
    }
  }
}
