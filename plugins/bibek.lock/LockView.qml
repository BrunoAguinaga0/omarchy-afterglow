import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
  property string timeFormat: "hh:mm AP"
  property string dateFormat: "dddd, MMMM d"
  property int focusIndex: 0
  property real audioBass: -1
  property real audioHigh: 0
  property var audioBands: []
  property string auraStyle: "horizon"
  property real auraIntensity: 1
  property bool styleToastPending: false
  property var weather: null
  readonly property var auraStyleNames: ({
      "horizon": "Horizon",
      "halo": "Halo",
      "spectrum": "Spectrum",
      "cloud": "Cloud",
      "orbs": "Orbs"
    })

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0 ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth) : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha") : (passwordInput.activeFocus ? Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha") : Border.surfaceSpec("lock", "border", Color.lock.border, 1, "border-alpha"))

  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activeMprisPlayer: {
    if (!mprisPlayers)
      return null;
    for (var i = 0; i < mprisPlayers.length; i++) {
      var p = mprisPlayers[i];
      if (p && p.isPlaying && (p.trackTitle || p.trackArtist))
        return p;
    }
    for (var j = 0; j < mprisPlayers.length; j++) {
      var p2 = mprisPlayers[j];
      if (p2 && (p2.trackTitle || p2.trackArtist))
        return p2;
    }
    return null;
  }
  readonly property bool hasMedia: activeMprisPlayer !== null && (activeMprisPlayer.trackTitle || activeMprisPlayer.trackArtist)
  readonly property string mediaTitle: activeMprisPlayer ? (activeMprisPlayer.trackTitle || "") : ""
  readonly property string mediaArtist: activeMprisPlayer ? (activeMprisPlayer.trackArtist || "") : ""
  readonly property string mediaArtUrl: activeMprisPlayer ? (activeMprisPlayer.trackArtUrl || "") : ""
  readonly property bool isMediaPlaying: activeMprisPlayer ? activeMprisPlayer.isPlaying : false
  // False while this view sits in a hidden window (e.g. the closed preview), so
  // the media animations do not keep ticking off-screen.
  readonly property bool shown: Window.window !== null && Window.window.visible

  property string currentTimeString: ""
  property string currentDateString: ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested
  signal wakeRequested
  signal sleepRequested
  signal shutdownRequested
  signal rebootRequested
  signal suspendRequested
  signal auraStyleCycleRequested

  function activeIndices() {
    var list = [0];
    if (hasMedia && activeMprisPlayer) {
      if (activeMprisPlayer.canGoPrevious)
        list.push(3);
      if (activeMprisPlayer.canPlay || activeMprisPlayer.canPause || activeMprisPlayer.canTogglePlaying)
        list.push(4);
      if (activeMprisPlayer.canGoNext)
        list.push(5);
      list.push(9);
    }
    list.push(6, 7, 8);
    return list;
  }

  function moveFocus(delta) {
    var list = activeIndices();
    var currentPos = list.indexOf(focusIndex);
    if (currentPos === -1)
      currentPos = 0;
    var nextPos = (currentPos + delta + list.length) % list.length;
    focusIndex = list[nextPos];
    if (focusIndex === 0) {
      forcePasswordFocus();
    }
  }

  function activateFocused() {
    if (focusIndex === 0) {
      var submitted = root.passwordText;
      root.passwordTextEdited("");
      if (submitted.length > 0)
        root.submitPassword(submitted);
    } else if (focusIndex === 3) {
      if (root.activeMprisPlayer && root.activeMprisPlayer.canGoPrevious)
        root.activeMprisPlayer.previous();
      root.wakeRequested();
    } else if (focusIndex === 4) {
      if (!root.activeMprisPlayer)
        return;
      if (root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPause)
        root.activeMprisPlayer.pause();
      else if (!root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPlay)
        root.activeMprisPlayer.play();
      else if (root.activeMprisPlayer.canTogglePlaying)
        root.activeMprisPlayer.togglePlaying();
      root.wakeRequested();
    } else if (focusIndex === 5) {
      if (root.activeMprisPlayer && root.activeMprisPlayer.canGoNext)
        root.activeMprisPlayer.next();
      root.wakeRequested();
    } else if (focusIndex === 9) {
      root.styleToastPending = true;
      root.auraStyleCycleRequested();
      root.wakeRequested();
    } else if (focusIndex === 6) {
      root.suspendRequested();
    } else if (focusIndex === 7) {
      root.shutdownRequested();
    } else if (focusIndex === 8) {
      root.rebootRequested();
    }
  }

  function fileUrl(path) {
    if (!path)
      return "";
    var encoded = String(path).split("/").map(encodeURIComponent).join("/");
    return "file://" + encoded + "?v=" + backgroundVersion;
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus();
  }

  function clearPassword() {
    passwordTextEdited("");
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText)
      return;
    syncingPasswordText = true;
    passwordInput.text = passwordText;
    syncingPasswordText = false;
  }

  function ensureFocusValid() {
    if (activeIndices().indexOf(focusIndex) === -1)
      focusIndex = 0;
  }

  onPasswordTextChanged: syncPasswordText()
  onAuraStyleChanged: {
    if (!styleToastPending)
      return;
    styleToastPending = false;
    styleToast.opacity = 1;
    styleToastTimer.restart();
  }
  onActiveMprisPlayerChanged: ensureFocusValid()
  onHasMediaChanged: ensureFocusValid()
  onInputEnabledChanged: {
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus);
  }
  Component.onCompleted: {
    syncPasswordText();
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus);
  }

  Component.onDestruction: {
    dateTimeTimer.stop();
  }

  Timer {
    id: dateTimeTimer
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var now = new Date();
      currentTimeString = Qt.formatDateTime(now, root.timeFormat);
      currentDateString = Qt.formatDateTime(now, root.dateFormat);
    }
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
    focus: true

    Keys.onPressed: function (event) {
      root.wakeRequested();
      if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
        root.moveFocus(1);
        event.accepted = true;
      } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
        root.moveFocus(-1);
        event.accepted = true;
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        root.activateFocused();
        event.accepted = true;
      } else if (event.key === Qt.Key_Escape) {
        root.focusIndex = 0;
        root.forcePasswordFocus();
        event.accepted = true;
      } else if (event.text.length > 0) {
        root.focusIndex = 0;
        root.forcePasswordFocus();
      }
    }

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      id: wallpaperBlur
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.6
      contrast: -0.10
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.35)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.wakeRequested();
        root.forcePasswordFocus();
      }
      onPositionChanged: root.wakeRequested()
    }

    Aura {
      id: aura
      anchors.fill: parent
      backdrop: wallpaperBlur
      style: root.auraStyle
      intensity: root.auraIntensity
      cardX: mediaCard.x
      cardY: mediaCard.y
      cardWidth: mediaCard.width
      cardHeight: mediaCard.height
      bands: root.audioBands
      colors: mediaCard.coverPalette
      present: root.hasMedia && root.shown
      playing: root.isMediaPlaying
      animate: root.shown
      level: root.audioBass
      high: root.audioHigh
    }

    MediaCard {
      id: mediaCard
      width: Math.min(400, root.width - 80)
      height: implicitHeight
      // Centred in the gap between the password field and the power buttons.
      anchors.horizontalCenter: parent.horizontalCenter
      y: {
        var top = inputField.y + inputField.height + 24;
        var bottom = powerControls.y - 24;
        return Math.max(top, top + (bottom - top - height) / 2);
      }
      player: root.activeMprisPlayer
      visible: (root.hasMedia || opacity > 0) && root.shown
      opacity: root.hasMedia ? 1 : 0
      scale: root.hasMedia ? 1 : 0.97
      prevCursor: root.focusIndex === 3
      playCursor: root.focusIndex === 4
      nextCursor: root.focusIndex === 5
      styleCursor: root.focusIndex === 9
      onInteracted: root.wakeRequested()
      onPreviousRequested: {
        root.focusIndex = 3;
        root.activateFocused();
      }
      onPlayPauseRequested: {
        root.focusIndex = 4;
        root.activateFocused();
      }
      onNextRequested: {
        root.focusIndex = 5;
        root.activateFocused();
      }
      onStyleRequested: {
        root.focusIndex = 9;
        root.activateFocused();
      }

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(root.hasMedia ? 180 : 120); easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: Style.duration(root.hasMedia ? 180 : 120); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
      }
    }

    // Brief "Aura: <style>" label above the card after switching styles.
    Text {
      id: styleToast
      anchors.horizontalCenter: mediaCard.horizontalCenter
      anchors.bottom: mediaCard.top
      anchors.bottomMargin: 10
      visible: opacity > 0 && mediaCard.visible
      opacity: 0
      text: "Aura: " + (root.auraStyleNames[root.auraStyle] || root.auraStyle)
      textFormat: Text.PlainText
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(styleToast.opacity > 0.5 ? 120 : 180); easing.type: Easing.OutCubic }
      }

      Timer {
        id: styleToastTimer
        interval: 1400
        onTriggered: styleToast.opacity = 0
      }
    }

    Column {
      id: timeDateColumn
      anchors.bottom: inputField.top
      anchors.bottomMargin: 48
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentTimeString
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 3.2)
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
      }

      Row {
        id: dateRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        readonly property int textSize: Math.round(Style.font.heading * 1.25)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.currentDateString
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: dateRow.textSize
        }

        Rectangle {
          visible: root.weather !== null
          anchors.verticalCenter: parent.verticalCenter
          width: 5
          height: 5
          radius: 2.5
          color: Util.alpha(Color.lock.placeholder, 0.6)
        }

        Row {
          visible: root.weather !== null
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.weather ? root.weather.icon : ""
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: Math.round(dateRow.textSize * 1.1)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.weather ? root.weather.temp : ""
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: dateRow.textSize
            font.weight: Font.DemiBold
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text.length > 0
            text: {
              if (!root.weather)
                return "";
              var parts = [];
              if (root.weather.desc)
                parts.push(root.weather.desc);
              if (root.weather.place)
                parts.push(root.weather.place);
              return parts.join(" · ");
            }
            color: Util.alpha(Color.lock.placeholder, 0.8)
            font.family: Style.font.family
            font.pixelSize: Math.round(dateRow.textSize * 0.8)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 420)
          }
        }
      }
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText)
            root.passwordTextEdited(text);
          if (text.length > 0) {
            root.wakeRequested();
            root.focusIndex = 0;
          }
          if (text.length > 0 && root.failureMessage.length > 0)
            root.clearFailureRequested();
        }

        onAccepted: {
          var submitted = root.passwordText;
          root.passwordTextEdited("");
          if (submitted.length > 0)
            root.submitPassword(submitted);
        }

        Keys.onPressed: function (event) {
          root.wakeRequested();
          if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
            root.moveFocus(1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
            root.moveFocus(-1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Escape) {
            root.passwordTextEdited("");
            event.accepted = true;
          } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
            root.passwordTextEdited("");
            event.accepted = true;
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Row {
      id: powerControls
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 16

      Button {
        id: sleepButton
        text: "Sleep"
        iconText: "󰤄"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 6
        onClicked: root.suspendRequested()
      }

      Button {
        id: shutdownButton
        text: "Shutdown"
        iconText: "󰐥"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 7
        onClicked: root.shutdownRequested()
      }

      Button {
        id: restartButton
        text: "Restart"
        iconText: "󰜉"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 8
        onClicked: root.rebootRequested()
      }
    }
  }
}
