import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "OsdModel.js" as OsdModel

Item {
  id: root

  property bool opened: false
  property string icon: ""
  property string message: ""
  property string iconKey: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1200

  readonly property bool mediaOsd: iconKey.indexOf("media") === 0 || iconKey.indexOf("player") === 0

  // The card is built out of measured columns instead of fixed widths, so it
  // keeps exactly `pad` between border and content on every side whatever
  // glyph or message it carries. Messages grow with their text up to
  // `maxMessageWidth` and elide beyond it.
  readonly property int pad: Style.space(16)
  readonly property int gap: Style.space(16)
  // A glyph next to a message reads airier than it measures: the icon outline
  // and the letterforms both fall away from their ink extremes, so the space
  // between them opens up well past the nominal gap. Text takes two thirds of
  // it; the progress bar's hard edge keeps the full gap.
  readonly property int messageGap: Math.round(root.gap * 2 / 3)
  readonly property int barWidth: Style.space(142)
  readonly property int maxMessageWidth: root.mediaOsd ? Style.space(325) : Style.space(190)

  // Nerd Font glyphs draw well outside their monospace cell, so the icon
  // column is measured by ink rather than by advance width. Progress OSDs pin
  // it to the widest glyph the model can return, so the bar doesn't shift when
  // volume crosses an icon threshold.
  readonly property int iconInkWidth: Math.ceil(iconMetrics.tightBoundingRect.width)
  readonly property int iconWidth: root.hasProgress
    ? Math.max(root.iconInkWidth, Math.ceil(widestIconMetrics.tightBoundingRect.width))
    : root.iconInkWidth
  // Same idea for the readout: it is as wide as the longest percentage so the
  // digits don't jitter between 9% and 100%.
  readonly property int valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth, messageMetrics.advanceWidth))
  readonly property int messageWidth: Math.min(Math.ceil(messageMetrics.advanceWidth), root.maxMessageWidth)
  readonly property int contentWidth: root.hasProgress
    ? root.iconWidth + root.gap + root.barWidth + root.gap + root.valueWidth
    : (root.message === "" ? root.iconWidth : root.iconWidth + root.messageGap + root.messageWidth)

  function iconFor(name, percent) {
    return OsdModel.iconFor(name, percent)
  }

  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var next = OsdModel.stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration, Commons.I18n.formatNumber)
    // Update before opening so a fresh OSD starts at its new value; only
    // subsequent updates while it remains open animate the progress bar.
    iconKey = next.iconKey
    maxValue = next.maxValue
    hasProgress = next.hasProgress
    value = next.value
    message = next.message
    icon = next.icon
    duration = next.duration
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value), p.max === undefined ? "100" : String(p.max), p.progressText || "", p.duration === undefined ? "1200" : String(p.duration))
    } catch (e) {}
  }

  function close() { opened = false }

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  TextMetrics {
    id: messageMetrics
    font.family: Style.font.family
    font.bold: true
    font.pixelSize: Style.font.title
    text: root.message
  }

  TextMetrics {
    id: valueMetrics
    font: messageMetrics.font
    text: Commons.I18n.formatNumber(100) + "%"
  }

  TextMetrics {
    id: iconMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.displayLarge
    text: root.icon
  }

  TextMetrics {
    id: widestIconMetrics
    font: iconMetrics.font
    text: OsdModel.widestIcon
  }

  ShellIpc {
    target: "osd"
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  // ── Look ──
  // Volume takes the colours of the cover that is playing (theme accent when
  // nothing plays); brightness uses warm fixed tones; the rest the accent.
  readonly property bool volumeOsd: iconKey.indexOf("volume") === 0 || iconKey === "muted" || iconKey === "mute"
  readonly property bool brightnessOsd: iconKey === "brightness" || iconKey === "display" || iconKey === "keyboard"
  readonly property bool volumeMuted: iconKey === "volume-muted" || iconKey === "volume-mute" || iconKey === "muted" || iconKey === "mute"

  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var playingPlayer: {
    var list = mprisPlayers || []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying) return list[i]
    return null
  }

  CoverPalette {
    id: coverColors
    artUrl: root.volumeOsd && root.playingPlayer ? (root.playingPlayer.trackArtUrl || "") : ""
    opacity: 0
  }

  readonly property var warmColors: [Commons.Color.accent, Qt.hsla(0.12, 0.92, 0.68, 1), Qt.hsla(0.08, 0.9, 0.66, 1)]
  readonly property var tones: root.brightnessOsd ? root.warmColors : coverColors.colors
  readonly property color tone0: root.volumeMuted ? Util.alpha(Commons.Color.popups.text, 0.5) : root.tones[0]
  readonly property color tone1: root.volumeMuted ? Util.alpha(Commons.Color.popups.text, 0.5) : root.tones[1]
  readonly property color tone2: root.volumeMuted ? Util.alpha(Commons.Color.popups.text, 0.5) : root.tones[2]

  // Volume icon follows the level (low / medium / high) unless muted.
  readonly property string shownIcon: root.volumeOsd && root.hasProgress && !root.volumeMuted
    ? OsdModel.iconFor("", Math.round(root.value * 100 / root.maxValue))
    : root.icon

  readonly property int inner: Style.space(10)
  readonly property int badge: Style.font.displayLarge + Style.space(14)
  readonly property int barHeight: Style.space(10)
  readonly property int pillWidth: root.inner + root.badge + (root.hasProgress ? root.gap + root.barWidth + root.gap + root.valueWidth : (root.message === "" ? 0 : root.messageGap + root.messageWidth)) + root.pad
  readonly property int pillHeight: root.badge + root.inner * 2

  // A small "pop" every time the value changes while open.
  property real pop: 1
  onValueChanged: if (root.opened && !Style.reduceMotion) popAnim.restart()
  SequentialAnimation {
    id: popAnim
    NumberAnimation { target: root; property: "pop"; to: 1.04; duration: Style.duration(70); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "pop"; to: 1; duration: Style.duration(180); easing.type: Easing.OutBack }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-osd"
    // Visual-only surface: keep the layer-shell input region empty so the OSD
    // never blocks clicks to the desktop below it.
    mask: Region {}

    Item {
      id: card
      width: root.pillWidth
      height: root.pillHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(67) + (root.opened ? 0 : -Style.space(16))
      opacity: root.opened ? 1 : 0
      scale: root.pop
      Behavior on anchors.bottomMargin {
        NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
      }
      Behavior on opacity {
        NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
      }

      // Glow behind the pill in the same colours as the bar.
      Rectangle {
        x: Style.space(28)
        y: Style.space(4)
        width: parent.width - Style.space(56)
        height: parent.height - Style.space(8)
        radius: height / 2
        opacity: root.volumeMuted ? 0.2 : 0.7
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.tone0 }
          GradientStop { position: 0.5; color: root.tone1 }
          GradientStop { position: 1.0; color: root.tone2 }
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
        anchors.fill: parent
        radius: height / 2
        color: Util.alpha(Commons.Color.background, 0.86)
        border.width: 1
        border.color: Util.alpha(root.tone0, 0.6)

        Row {
          anchors.fill: parent
          anchors.leftMargin: root.inner
          anchors.rightMargin: root.pad
          spacing: root.hasProgress ? root.gap : root.messageGap

          Rectangle {
            width: root.badge
            height: root.badge
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(root.tone0, 0.22)

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.shownIcon
              font: iconMetrics.font
              color: Commons.Color.popups.text
            }
          }

          Rectangle {
            visible: root.hasProgress
            width: root.barWidth
            height: root.barHeight
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(Commons.Color.popups.text, 0.12)

            Rectangle {
              // Anchored so a right-to-left layout fills from the right.
              anchors.left: parent.left
              height: parent.height
              radius: height / 2
              width: Math.max(root.value > 0 ? height : 0, parent.width * (root.hasProgress ? root.value / root.maxValue : 0))
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.tone0 }
                GradientStop { position: 0.5; color: root.tone1 }
                GradientStop { position: 1.0; color: root.tone2 }
              }

              Behavior on width {
                enabled: root.opened
                NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.message !== ""
            width: root.hasProgress ? root.valueWidth : root.messageWidth
            horizontalAlignment: root.hasProgress ? Text.AlignRight : Text.AlignLeft
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            font: messageMetrics.font
            color: Commons.Color.popups.text
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }
      }
    }
  }
}
