import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// Always-visible now-playing card for the lock screen: blurred album art
// backdrop, large cover, scrolling title/artist, live equalizer, seekable
// progress with timestamps and an accent play button tinted from the cover.
Item {
  id: card

  property var player: null
  property bool prevCursor: false
  property bool playCursor: false
  property bool nextCursor: false
  property bool styleCursor: false

  property bool showStyleButton: true
  // Stronger cover colors (bar menu); the lock screen keeps the quiet look.
  property bool vivid: false
  signal interacted
  signal bodyClicked
  signal previousRequested
  signal playPauseRequested
  signal nextRequested
  signal styleRequested

  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property bool playing: player ? player.isPlaying : false
  readonly property bool hasArt: artImage.status === Image.Ready && artUrl !== ""
  readonly property bool hasLength: player !== null && player.lengthSupported && player.length > 0
  readonly property real progress: hasLength ? Math.max(0, Math.min(1, player.position / player.length)) : 0

  readonly property int padding: 14
  readonly property int artSize: 116
  readonly property color textColor: Color.lock.text
  readonly property color subtleColor: Color.lock.placeholder

  // Accent colour sampled from the cover art; falls back to the theme accent.
  // coverPalette holds four colours: [0] is the dominant one (used as the accent),
  // the rest are other distinct hues from the cover, or variations of [0] when the
  // cover has few colours. Without usable art it is derived from the theme accent.
  CoverPalette {
    id: coverSampler
    z: -10
    artUrl: card.artUrl
    artReady: card.hasArt
  }
  readonly property var coverPalette: coverSampler.colors
  readonly property color accent: coverPalette[0]
  readonly property color onAccent: (0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b) > 0.6 ? "#111111" : "#ffffff"

  implicitWidth: 400
  implicitHeight: artSize + padding * 2

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0)
      seconds = 0;
    var s = Math.floor(seconds);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var ss = sec < 10 ? "0" + sec : String(sec);
    if (h > 0)
      return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;
    return m + ":" + ss;
  }

  // MPRIS does not push position updates; poke it while playing.
  Timer {
    interval: 1000
    repeat: true
    running: card.visible && card.playing && card.player !== null && card.player.positionSupported
    onTriggered: card.player.positionChanged()
  }


  // Rounded mask shared by the card backdrop.
  Rectangle {
    id: cardMask
    anchors.fill: parent
    radius: Style.cornerRadius
    visible: false
    layer.enabled: true
  }

  Item {
    id: backdrop
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: cardMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }

    Rectangle {
      anchors.fill: parent
      color: Color.lock.background
    }

    Image {
      id: backdropArt
      anchors.fill: parent
      anchors.margins: -40
      source: card.artUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 256
      sourceSize.height: 256
      visible: false
    }

    MultiEffect {
      anchors.fill: backdropArt
      source: backdropArt
      visible: card.hasArt
      autoPaddingEnabled: false
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      saturation: card.vivid ? 0.9 : 0.25
    }

    // Theme-coloured veil keeps text legible on any cover.
    Rectangle {
      anchors.fill: parent
      visible: card.hasArt
      color: Util.alpha(Color.lock.background, card.vivid ? 0.5 : 0.72)
    }

    // Soft accent glow from the left edge.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Util.alpha(card.coverPalette[0], card.vivid ? 0.4 : 0.22) }
        GradientStop { position: 0.5; color: Util.alpha(card.coverPalette[2], card.vivid ? 0.12 : 0.0) }
        GradientStop { position: 1.0; color: Util.alpha(card.coverPalette[1], card.vivid ? 0.34 : 0.16) }
      }
    }
  }

  BorderSurface {
    anchors.fill: parent
    color: "transparent"
    borderSpec: Border.surfaceSpec("lock", "media-border", Util.alpha(card.accent, 0.7), 1, "border-alpha")
    radius: Style.cornerRadius
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: card.interacted()
    cursorShape: card.vivid ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: { card.interacted(); card.bodyClicked() }
  }

  Row {
    x: card.padding
    y: card.padding
    width: card.width - card.padding * 2
    height: card.artSize
    spacing: 16

    // Cover art with drop shadow.
    Item {
      id: artFrame
      width: card.artSize
      height: card.artSize
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.45
        shadowBlur: 0.8
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
      }

      Rectangle {
        id: artMask
        anchors.fill: parent
        radius: Style.cornerRadius
        visible: false
        layer.enabled: true
      }

      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: artMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }

        Rectangle {
          anchors.fill: parent
          color: Util.alpha(card.accent, 0.25)
        }

        Text {
          anchors.centerIn: parent
          visible: !card.hasArt
          text: "󰝚"
          textFormat: Text.PlainText
          color: card.textColor
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 2)
        }

        Image {
          id: artImage
          anchors.fill: parent
          source: card.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: card.artSize * 2
          sourceSize.height: card.artSize * 2
          visible: card.hasArt
        }
      }
    }

    Column {
      id: info
      width: parent.width - card.artSize - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Row {
        width: info.width
        spacing: 8

        Equalizer {
          id: eq
          anchors.verticalCenter: parent.verticalCenter
          playing: card.playing
          active: card.visible
          color: card.accent
        }

        Marquee {
          width: info.width - eq.width - 8 - (card.showStyleButton ? 26 : 0)
          text: card.title
          textColor: card.textColor
          pixelSize: Math.round(Style.font.body * 1.15)
          bold: true
          active: card.visible
        }
      }

      Marquee {
        width: info.width
        visible: card.artist.length > 0
        text: card.artist
        textColor: card.subtleColor
        pixelSize: Style.font.bodySmall
        active: card.visible
      }

      Item { width: 1; height: 4 }

      // Seekable progress bar.
      Item {
        id: progressTrack
        width: info.width
        height: 10
        visible: card.hasLength

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: progressMouse.containsMouse ? 6 : 4
          radius: height / 2
          color: Util.alpha(card.textColor, 0.18)

          Rectangle {
            width: parent.width * card.progress
            height: parent.height
            radius: parent.radius
            color: card.accent
            Behavior on width {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
            }
          }
        }

        MouseArea {
          id: progressMouse
          anchors.fill: parent
          anchors.topMargin: -4
          anchors.bottomMargin: -4
          hoverEnabled: true
          enabled: card.player !== null && card.player.canSeek && card.player.positionSupported
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: function (mouse) {
            card.interacted();
            var ratio = Math.max(0, Math.min(1, mouse.x / width));
            card.player.position = ratio * card.player.length;
          }
        }
      }

      Item {
        width: info.width
        height: elapsedText.implicitHeight
        visible: card.hasLength

        Text {
          id: elapsedText
          anchors.left: parent.left
          text: card.formatTime(card.player ? card.player.position : 0)
          textFormat: Text.PlainText
          color: card.subtleColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.features: { "tnum": 1 }
        }

        Text {
          anchors.right: parent.right
          text: card.formatTime(card.player ? card.player.length : 0)
          textFormat: Text.PlainText
          color: card.subtleColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.features: { "tnum": 1 }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: card.player ? card.player.canGoPrevious : false
          implicitWidth: 34
          implicitHeight: 34
          iconSize: Style.font.iconLarge
          background: "transparent"
          foreground: card.textColor
          accent: card.accent
          horizontalPadding: 0
          verticalPadding: 0
          hasCursor: card.prevCursor
          iconText: ""
          onClicked: card.previousRequested()
        }

        // Accent play / pause button.
        Rectangle {
          id: playBtn
          anchors.verticalCenter: parent.verticalCenter
          visible: card.player ? (card.player.canPlay || card.player.canPause || card.player.canTogglePlaying) : false
          width: 42
          height: 42
          radius: width / 2
          color: card.accent
          scale: playMouse.pressed ? 0.95 : (playMouse.containsMouse ? 1.05 : 1)
          border.width: card.playCursor ? 2 : 0
          border.color: card.textColor

          Behavior on scale {
            NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
          }
          Behavior on color {
            ColorAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
          }

          Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: card.playing ? 0 : 1
            text: card.playing ? "󰏤" : "󰐊"
            textFormat: Text.PlainText
            color: card.onAccent
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.playPauseRequested()
          }
        }

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: card.player ? card.player.canGoNext : false
          implicitWidth: 34
          implicitHeight: 34
          iconSize: Style.font.iconLarge
          background: "transparent"
          foreground: card.textColor
          accent: card.accent
          horizontalPadding: 0
          verticalPadding: 0
          hasCursor: card.nextCursor
          iconText: ""
          onClicked: card.nextRequested()
        }
      }
    }
  }

  // Cycles the aura style behind the card.
  Button {
    visible: card.showStyleButton
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 6
    anchors.rightMargin: 6
    implicitWidth: 28
    implicitHeight: 28
    iconSize: Style.font.icon
    background: "transparent"
    foreground: card.subtleColor
    accent: card.accent
    horizontalPadding: 0
    verticalPadding: 0
    hasCursor: card.styleCursor
    iconText: "󰏘"
    tooltipText: "Aura style"
    onClicked: card.styleRequested()
  }

  // Single line of text that scrolls back and forth when it does not fit.
  component Marquee: Item {
    id: marquee
    property string text: ""
    property color textColor: "white"
    property int pixelSize: Style.font.body
    property bool bold: false
    property bool active: true
    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    readonly property bool scrolling: overflow > 0 && !Style.reduceMotion && marquee.active

    height: label.implicitHeight
    clip: true

    onTextChanged: label.x = 0

    Text {
      id: label
      width: marquee.scrolling ? implicitWidth : marquee.width
      text: marquee.text
      textFormat: Text.PlainText
      color: marquee.textColor
      font.family: Style.font.family
      font.pixelSize: marquee.pixelSize
      font.bold: marquee.bold
      elide: marquee.scrolling ? Text.ElideNone : Text.ElideRight
    }

    SequentialAnimation {
      running: marquee.scrolling
      loops: Animation.Infinite
      onRunningChanged: if (!running) label.x = 0

      PauseAnimation { duration: 2200 }
      NumberAnimation {
        target: label
        property: "x"
        from: 0
        to: -marquee.overflow
        duration: Math.max(800, marquee.overflow * 35)
        easing.type: Easing.InOutSine
      }
      PauseAnimation { duration: 1600 }
      NumberAnimation {
        target: label
        property: "x"
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
      }
    }
  }

  // Four bars that bounce while music plays and rest when paused.
  component Equalizer: Row {
    id: eqRow
    property bool playing: false
    property color color: "white"
    property bool active: true
    readonly property int barHeight: 14
    readonly property bool animating: playing && !Style.reduceMotion && eqRow.active

    spacing: 2
    height: barHeight

    Repeater {
      model: [
        { "dur": 420, "rest": 5 },
        { "dur": 560, "rest": 9 },
        { "dur": 360, "rest": 6 },
        { "dur": 490, "rest": 8 }
      ]

      Rectangle {
        id: bar
        required property var modelData
        width: 3
        radius: 1.5
        anchors.bottom: parent.bottom
        color: eqRow.color
        opacity: eqRow.playing ? 1 : 0.5
        height: eqRow.playing ? modelData.rest : 3

        SequentialAnimation on height {
          running: eqRow.animating
          loops: Animation.Infinite
          NumberAnimation { to: eqRow.barHeight; duration: bar.modelData.dur; easing.type: Easing.InOutSine }
          NumberAnimation { to: 3; duration: bar.modelData.dur; easing.type: Easing.InOutSine }
          onRunningChanged: if (!running) bar.height = Qt.binding(function () { return eqRow.playing ? bar.modelData.rest : 3; })
        }
      }
    }
  }
}
