import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons

// Idle screensaver: the cover art large on black with the halo aura reacting to
// the music, title and progress underneath. Without music, a large clock. The
// whole composition drifts slowly so nothing stays burnt into one spot.
Rectangle {
  id: saver

  property bool active: false
  property string timeFormat: "hh:mm AP"
  property string dateFormat: "dddd, MMMM d"
  property real intensity: 1
  property real audioBass: -1
  property real audioHigh: 0

  color: "black"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = players || [];
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying && (list[i].trackTitle || list[i].trackArtist))
        return list[i];
    for (var j = 0; j < list.length; j++)
      if (list[j] && (list[j].trackTitle || list[j].trackArtist))
        return list[j];
    return null;
  }
  readonly property bool hasMedia: player !== null
  readonly property bool playing: hasMedia && player.isPlaying
  readonly property string artUrl: hasMedia ? (player.trackArtUrl || "") : ""
  readonly property bool hasArt: cover.status === Image.Ready && artUrl !== ""
  readonly property real progress: hasMedia && player.lengthSupported && player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : 0

  property string timeText: ""
  property string dateText: ""
  function tick() {
    var now = new Date();
    timeText = Qt.formatDateTime(now, timeFormat);
    dateText = Qt.formatDateTime(now, dateFormat);
  }

  Timer {
    interval: 1000
    repeat: true
    running: saver.active
    triggeredOnStart: true
    onTriggered: {
      saver.tick();
      if (saver.playing && saver.player.positionSupported)
        saver.player.positionChanged();
    }
  }

  CoverPalette {
    id: coverColors
    artUrl: saver.artUrl
    artReady: saver.hasArt
    opacity: 0
  }

  // Slow drift of everything, ±40px over about a minute.
  property real driftX: 0
  property real driftY: 0
  SequentialAnimation on driftX {
    running: saver.active && !Style.reduceMotion
    loops: Animation.Infinite
    NumberAnimation { from: -40; to: 40; duration: 37000; easing.type: Easing.InOutSine }
    NumberAnimation { from: 40; to: -40; duration: 37000; easing.type: Easing.InOutSine }
  }
  SequentialAnimation on driftY {
    running: saver.active && !Style.reduceMotion
    loops: Animation.Infinite
    NumberAnimation { from: -30; to: 30; duration: 29000; easing.type: Easing.InOutSine }
    NumberAnimation { from: 30; to: -30; duration: 29000; easing.type: Easing.InOutSine }
  }

  readonly property int coverSize: Math.round(Math.min(width, height) * 0.36)

  Item {
    id: stage
    width: parent.width
    height: parent.height
    x: saver.driftX
    y: saver.driftY

    Aura {
      anchors.fill: parent
      style: "halo"
      intensity: saver.intensity * 1.2
      cardX: focusBox.x
      cardY: focusBox.y
      cardWidth: focusBox.width
      cardHeight: focusBox.height
      colors: coverColors.colors
      present: saver.active
      playing: saver.playing
      animate: saver.active
      level: saver.audioBass
      high: saver.audioHigh
    }

    // What the halo wraps: the cover with music, the clock without.
    Item {
      id: focusBox
      width: saver.hasMedia ? saver.coverSize : clockText.implicitWidth + 80
      height: saver.hasMedia ? saver.coverSize : clockText.implicitHeight + 40
      x: (stage.width - width) / 2
      y: saver.hasMedia ? stage.height * 0.42 - height / 2 : stage.height / 2 - height / 2 - 30
    }

    Item {
      id: coverFrame
      visible: saver.hasMedia
      anchors.fill: focusBox
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.6
        shadowBlur: 1.0
        shadowVerticalOffset: 12
        autoPaddingEnabled: true
      }

      Rectangle {
        id: coverMask
        anchors.fill: parent
        radius: Style.cornerRadius + 4
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
          color: coverColors.colors[0]
        }

        Image {
          id: cover
          anchors.fill: parent
          source: saver.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 600
          sourceSize.height: 600
        }
      }
    }

    Column {
      visible: saver.hasMedia
      anchors.horizontalCenter: focusBox.horizontalCenter
      y: focusBox.y + focusBox.height + 48
      spacing: 10
      width: Math.min(stage.width - 120, 720)

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: saver.hasMedia ? (saver.player.trackTitle || "") : ""
        color: "#f0f0f0"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.6)
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: {
          if (!saver.hasMedia)
            return "";
          var a = saver.player.trackArtist || "", b = saver.player.trackAlbum || "";
          return a && b ? a + " — " + b : a + b;
        }
        color: Qt.rgba(1, 1, 1, 0.6)
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.05)
        elide: Text.ElideRight
      }

      Item { width: 1; height: 8 }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle {
          width: parent.width * saver.progress
          height: parent.height
          radius: 2
          color: coverColors.colors[0]
        }
      }
    }

    Column {
      visible: !saver.hasMedia
      anchors.centerIn: focusBox
      spacing: 6
      Text {
        id: clockText
        anchors.horizontalCenter: parent.horizontalCenter
        text: saver.timeText
        color: "#f0f0f0"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 5)
        font.weight: Font.Light
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: saver.dateText
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.25)
      }
    }

    // Small clock in the corner while music shows.
    Text {
      visible: saver.hasMedia
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 48
      text: saver.timeText
      color: Qt.rgba(1, 1, 1, 0.4)
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.heading * 1.25)
      font.weight: Font.Light
    }
  }
}
