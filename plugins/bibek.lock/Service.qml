import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var settings: null
  property string omarchyPath: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
  readonly property string loginName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string stateRoot: stateHome + "/omarchy"
  readonly property string shareRoot: "/usr/share/omarchy"
  readonly property string userBackgroundsRoot: home + "/.config/omarchy/backgrounds"
  readonly property string omarchyBin: "/usr/share/omarchy/bin/omarchy"
  readonly property string systemctlBin: "/usr/bin/systemctl"
  readonly property string sessionLockedBin: "/usr/share/omarchy/bin/omarchy-hyprland-session-locked"
  readonly property string wakeBin: "/usr/share/omarchy/bin/omarchy-system-wake"
  readonly property string brightKeyboardBin: "/usr/share/omarchy/bin/omarchy-brightness-keyboard"
  readonly property string brightDisplayBin: "/usr/share/omarchy/bin/omarchy-brightness-display"
  readonly property string fprintdListBin: "/usr/bin/fprintd-list"
  readonly property string cavaBin: "/usr/bin/cava"
  readonly property string stdbufBin: "/usr/bin/stdbuf"
  readonly property string cavaConfigPath: decodeURIComponent(String(Qt.resolvedUrl("cava.conf")).replace(/^file:\/\//, ""))
  readonly property string fingerprintPamPath: "/etc/pam.d/omarchy-lock-fingerprint"
  readonly property string fixedPath: "/usr/local/sbin:/usr/local/bin:/usr/bin"
  property bool fingerprintPamFile: false
  property int maxHelperBytes: 4096
  property int helperTimeoutMs: 3000
  property int wakeTimeoutMs: 5000

  property string timeFormat: setting("timeFormat", "hh:mm AP")
  property string dateFormat: setting("dateFormat", "dddd, MMMM d")
  readonly property var auraStyles: ["horizon", "halo", "spectrum", "cloud", "orbs"]
  property string auraStyle: {
    var value = String(setting("auraStyle", "horizon"));
    return auraStyles.indexOf(value) >= 0 ? value : "horizon";
  }
  property real auraIntensity: {
    var value = Number(setting("auraIntensity", 1));
    return isFinite(value) ? Math.max(0.2, Math.min(2, value)) : 1;
  }

  property bool lockRequested: false
  property bool pendingSessionLock: false
  property bool authenticatingPassword: false
  property bool fingerprintAuthenticating: false
  property bool passwordPamConfigured: false
  property bool fingerprintConfigured: false
  property bool previewVisible: false
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string lastEvent: "init"
  property string lastEventAt: ""
  property bool strandedLock: false
  property bool strandedLockResolved: false

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating

  // Keep the lock screen lit while music plays so the media card stays visible.
  readonly property bool mediaPlaying: {
    var players = Mpris.players ? Mpris.players.values : [];
    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying)
        return true;
    }
    return false;
  }

  onMediaPlayingChanged: {
    if (!mediaPlaying && lockRequested)
      armBlankTimer();
  }

  // Live audio levels for the aura, fed by cava while the lock screen (or its
  // preview) shows music. audioBass < 0 means "no feed": the aura falls back to
  // a synthetic pulse.
  readonly property bool audioWanted: (locked || previewVisible || screensaverShown) && mediaPlaying && !Style.reduceMotion
  property real audioBass: -1
  property real audioHigh: 0
  property var audioBands: []
  property int cavaFailures: 0

  onAudioWantedChanged: {
    if (!audioWanted) {
      audioBass = -1;
      audioHigh = 0;
      audioBands = [];
      cavaFailures = 0;
      cavaRetryTimer.stop();
    }
    syncCava();
  }

  // ── Screensaver ──
  // Replaces Omarchy's terminal screensaver: after shell.json idle.screensaver
  // seconds without input (0 disables it), an overlay with the cover and aura
  // covers every screen until the next key or mouse movement.
  property var shellIdleConfig: ({})
  readonly property int screensaverSeconds: {
    var n = Number(shellIdleConfig.screensaver);
    return isFinite(n) && n >= 0 ? Math.floor(n) : 150;
  }
  readonly property bool screensaverEnabled: setting("screensaver", true) !== false && screensaverSeconds > 0
  property bool screensaverPreview: false
  readonly property bool screensaverShown: !locked && ((screensaverEnabled && screensaverIdle.isIdle) || screensaverPreview)

  onScreensaverShownChanged: logEvent("screensaver: " + (screensaverShown ? "shown" : "hidden"))

  function dismissScreensaver() {
    screensaverPreview = false;
  }

  FileView {
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(text());
        root.shellIdleConfig = parsed && parsed.idle && typeof parsed.idle === "object" ? parsed.idle : ({});
      } catch (e) {
        root.shellIdleConfig = ({});
      }
    }
  }

  IdleMonitor {
    id: screensaverIdle
    enabled: root.screensaverEnabled && !root.locked
    respectInhibitors: true
    timeout: Math.max(1, root.screensaverSeconds)
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: saverWindow
      required property var modelData
      screen: modelData
      visible: root.screensaverShown || saverContent.opacity > 0
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      color: "transparent"
      WlrLayershell.namespace: "omarchy-lock-screensaver"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.screensaverShown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Screensaver {
        id: saverContent
        anchors.fill: parent
        focus: true
        active: root.screensaverShown
        timeFormat: root.timeFormat
        dateFormat: root.dateFormat
        intensity: root.auraIntensity
        audioBass: root.audioBass
        audioHigh: root.audioHigh
        opacity: root.screensaverShown ? 1 : 0
        Behavior on opacity {
          NumberAnimation { duration: Style.duration(root.screensaverShown ? 900 : 200); easing.type: Easing.OutCubic }
        }
        Keys.onPressed: function (event) {
          root.dismissScreensaver();
          event.accepted = true;
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        property point last: Qt.point(-1, -1)
        onPositionChanged: function (mouse) {
          if (last.x >= 0 && (Math.abs(mouse.x - last.x) > 4 || Math.abs(mouse.y - last.y) > 4))
            root.dismissScreensaver();
          last = Qt.point(mouse.x, mouse.y);
        }
        onPressed: root.dismissScreensaver()
        onWheel: root.dismissScreensaver()
      }
    }
  }

  // ── Now playing pill ──
  NowPlaying {
    id: nowPlaying
    suppressed: root.locked || root.screensaverShown || root.setting("nowPlaying", true) === false
  }

  // Weather next to the date. Fetched only when the lock screen (or its
  // preview) opens, at most every 20 minutes; the last good reading stays.
  readonly property bool weatherWanted: locked || previewVisible
  readonly property string weatherScriptPath: Qt.resolvedUrl("weather-fetch").toString().replace(/^file:\/\//, "")
  property var weather: null
  property real weatherFetchedAt: 0

  onWeatherWantedChanged: if (weatherWanted) refreshWeather(false)

  function refreshWeather(force) {
    if (weatherProc.running)
      return;
    if (!force && weather && Date.now() - weatherFetchedAt < 20 * 60 * 1000)
      return;
    weatherProc.running = true;
  }

  function weatherIcon(code, sunrise, sunset) {
    var night = false;
    var toMinutes = function (s) {
      var m = /^([0-9]{1,2}):([0-9]{2}) (AM|PM)$/.exec(String(s || ""));
      if (!m)
        return -1;
      return (parseInt(m[1], 10) % 12 + (m[3] === "PM" ? 12 : 0)) * 60 + parseInt(m[2], 10);
    };
    var rise = toMinutes(sunrise), set = toMinutes(sunset);
    if (rise >= 0 && set >= 0) {
      var now = new Date();
      var minutes = now.getHours() * 60 + now.getMinutes();
      night = minutes < rise || minutes >= set;
    }
    var c = parseInt(code, 10);
    var cp = 0xe33d;
    if (c === 113)
      cp = night ? 0xe32b : 0xe30d;
    else if (c === 116)
      cp = night ? 0xe32e : 0xe302;
    else if ([143, 248, 260].indexOf(c) >= 0)
      cp = 0xe313;
    else if ([176, 263, 353].indexOf(c) >= 0)
      cp = night ? 0xe333 : 0xe308;
    else if ([179, 227, 230, 323, 326, 368].indexOf(c) >= 0)
      cp = night ? 0xe327 : 0xe30a;
    else if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0)
      cp = 0xe3ad;
    else if ([200, 386, 389, 392, 395].indexOf(c) >= 0)
      cp = 0xe31d;
    else if ([266, 293, 296, 299, 302, 305, 308, 356, 359].indexOf(c) >= 0)
      cp = 0xe318;
    else if ([329, 332, 335, 338, 371].indexOf(c) >= 0)
      cp = 0xe31a;
    return String.fromCodePoint(cp);
  }

  function handleWeather(line) {
    try {
      var data = JSON.parse(String(line));
      if (!/^-?[0-9]{1,3}$/.test(String(data.temp)))
        return;
      var desc = String(data.desc || "");
      desc = desc.length > 0 ? desc.charAt(0).toUpperCase() + desc.slice(1, 60) : "";
      weather = {
        "icon": weatherIcon(data.code, data.sunrise, data.sunset),
        "temp": String(data.temp) + "°",
        "desc": desc,
        "place": String(data.place || "").slice(0, 40)
      };
      weatherFetchedAt = Date.now();
      logEvent("weather: " + weather.temp + " " + weather.desc);
    } catch (e) {}
  }

  Process {
    id: weatherProc
    command: [root.weatherScriptPath]
    stdout: SplitParser {
      onRead: function (data) {
        root.handleWeather(data);
      }
    }
  }

  Timer {
    interval: 30 * 60 * 1000
    repeat: true
    running: root.weatherWanted
    onTriggered: root.refreshWeather(true)
  }

  // Switch to the next aura style and remember it in lock.json, keeping the
  // other keys as they are.
  function cycleAuraStyle() {
    var index = auraStyles.indexOf(auraStyle);
    var next = auraStyles[(index + 1) % auraStyles.length];
    var merged = {};
    var current = fileConfig || {};
    for (var key in current)
      merged[key] = current[key];
    merged.auraStyle = next;
    fileConfig = merged;
    lockConfigWriter.setText(JSON.stringify(merged, null, 2) + "\n");
  }

  function syncCava() {
    var want = audioWanted && cavaFailures < 3;
    if (want && !cavaProcess.running)
      cavaProcess.running = true;
    else if (!want && cavaProcess.running)
      cavaProcess.running = false;
  }

  // One cava frame: "n;n;n;n;n;n;" with values 0-100, bands from low to high.
  function handleCavaFrame(line) {
    var text = String(line);
    if (text.length === 0 || text.length > 128)
      return;
    var parts = text.split(";");
    var values = [];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] === "")
        continue;
      if (!/^[0-9]{1,3}$/.test(parts[i]))
        return;
      values.push(Math.min(100, parseInt(parts[i], 10)) / 100);
    }
    if (values.length < 6)
      return;
    audioBands = values.slice(0, 6);
    audioBass = Math.max(values[0], values[1]);
    audioHigh = (values[2] + values[3] + values[4] + values[5]) / 4;
  }

  property var fileConfig: ({})
  function parseFileConfig(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""));
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
    } catch (e) {
      return ({});
    }
  }
  function setting(key, fallback) {
    var value = root.fileConfig ? root.fileConfig[key] : undefined;
    return value === undefined || value === null ? fallback : value;
  }
  property int maxConfigBytes: 65536
  property int configTimeoutMs: 5000
  readonly property string readScriptPath: Qt.resolvedUrl("read-config").toString().replace(/^file:\/\//, "")
  property string configRaw: ""
  property bool configApplied: false

  function loadConfig() {
    if (configProc.running)
      return;
    configProc.collected = "";
    configProc.collectedBytes = 0;
    configProc.overflowed = false;
    configProc.timedOut = false;
    configProc.command = [root.readScriptPath, Quickshell.env("HOME") + "/.config/omarchy/lock.json", String(root.maxConfigBytes)];
    configWatchdog.restart();
    configProc.running = true;
  }

  function applyConfig(ok, raw) {
    var next = ok ? String(raw || "") : "";
    if (next === root.configRaw && root.configApplied)
      return;
    root.configRaw = next;
    root.configApplied = true;
    root.fileConfig = root.parseFileConfig(next);
  }

  Timer {
    id: configWatchdog
    interval: root.configTimeoutMs
    repeat: false
    onTriggered: {
      if (configProc.running) {
        configProc.timedOut = true;
        configProc.collected = "";
        configProc.collectedBytes = 0;
        root.killProc(configProc);
      }
    }
  }

  Timer {
    id: configPoll
    interval: 10000
    repeat: true
    running: true
    onTriggered: root.loadConfig()
  }

  Process {
    id: configProc
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (configProc.overflowed || configProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (configProc.collectedBytes + chunk.length > root.maxConfigBytes) {
          configProc.overflowed = true;
          configProc.collected = "";
          configProc.collectedBytes = 0;
          root.killProc(configProc);
          return;
        }
        configProc.collected += chunk;
        configProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (configProc.overflowed || configProc.timedOut)
          return;
        configProc.collectedBytes += String(data + "\n").length;
        if (configProc.collectedBytes > root.maxConfigBytes) {
          configProc.overflowed = true;
          configProc.collected = "";
          configProc.collectedBytes = 0;
          root.killProc(configProc);
        }
      }
    }
    onExited: function (exitCode) {
      configWatchdog.stop();
      var ok = !configProc.overflowed && !configProc.timedOut && exitCode === 0;
      var output = String(configProc.collected);
      configProc.collected = "";
      configProc.collectedBytes = 0;
      configProc.overflowed = false;
      configProc.timedOut = false;
      root.applyConfig(ok, output);
    }
  }

  function realScreenCount() {
    var screens = Quickshell.screens || [];
    var count = 0;
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i];
      if (screen && screen.name && screen.width > 0 && screen.height > 0)
        count += 1;
    }
    return count;
  }

  function hasRealScreen() {
    return realScreenCount() > 0;
  }

  function queueSessionLock() {
    pendingSessionLock = true;
    if (!sessionLockStabilizeTimer.running)
      logEvent("lock-pending: screen-stabilizing");
    sessionLockStabilizeTimer.restart();
    if (!pendingSessionLockTimer.running)
      pendingSessionLockTimer.start();
  }

  function requestSessionLock() {
    if (!lockRequested || sessionLock.locked || sessionLock.secure)
      return;
    if (sessionLockStabilizeTimer.running)
      return;
    if (!hasRealScreen()) {
      if (!pendingSessionLock || lastEvent !== "lock-pending: no-real-screen")
        logEvent("lock-pending: no-real-screen");
      pendingSessionLock = true;
      if (!pendingSessionLockTimer.running)
        pendingSessionLockTimer.start();
      return;
    }
    pendingSessionLock = false;
    pendingSessionLockTimer.stop();
    sessionLock.locked = true;
  }

  function checkStrandedLock() {
    if (strandedLockResolved || strandedLockCheckProc.running)
      return;
    if (locked || lockRequested) {
      strandedLockResolved = true;
      return;
    }
    strandedLockCheckProc.running = true;
    strandedWatchdog.restart();
  }

  function killProc(proc) {
    try {
      proc.signal(9);
    } catch (e) {
    }
    proc.running = false;
  }

  function acceptBackground(raw) {
    var line = String(raw || "").split("\n")[0].trim();
    if (line === "" || line.charAt(0) !== "/" || line.length > 4096)
      return "";
    if (line.indexOf(root.stateRoot + "/") !== 0 && line.indexOf(root.shareRoot + "/") !== 0 && line.indexOf(root.userBackgroundsRoot + "/") !== 0)
      return "";
    return line;
  }

  function recoverStrandedLock() {
    if (!strandedLock || locked || !passwordPamConfigured)
      return;
    strandedLock = false;
    logEvent("lock-stranded: recovering");
    beginLock();
  }

  function refreshBackground() {
    if (backgroundProc.running)
      return;
    backgroundProc.collected = "";
    backgroundProc.collectedBytes = 0;
    backgroundProc.overflowed = false;
    backgroundProc.timedOut = false;
    backgroundProc.command = ["/usr/bin/env", "-i", "/usr/bin/sh", "-c", "p=$(/usr/bin/readlink -f \"$0\" 2>/dev/null); [ -n \"$p\" ] || exit 0; case \"$p\" in \"$1\"/*|\"$2\"/*|\"$3\"/*) ;; *) exit 0;; esac; [ -f \"$p\" ] && [ ! -L \"$p\" ] || exit 0; [ \"$(/usr/bin/stat -c %s \"$p\")\" -le 67108864 ] || exit 0; printf '%s' \"$p\"", root.currentBackgroundLink, root.stateRoot, root.shareRoot, root.userBackgroundsRoot];
    backgroundProc.running = true;
    backgroundWatchdog.restart();
  }

  function refreshFingerprintStatus() {
    if (!root.fingerprintPamFile || root.loginName === "" || fingerprintListProc.running) {
      if (!root.fingerprintPamFile || root.loginName === "")
        setFingerprintConfigured(false);
      return;
    }
    fingerprintListProc.collected = "";
    fingerprintListProc.collectedBytes = 0;
    fingerprintListProc.overflowed = false;
    fingerprintListProc.timedOut = false;
    fingerprintListProc.command = [root.fprintdListBin, root.loginName];
    fingerprintListProc.running = true;
    fingerprintWatchdog.restart();
  }

  function setFingerprintConfigured(on) {
    root.fingerprintConfigured = on === true;
    if (root.lockRequested && root.fingerprintConfigured)
      root.startFingerprint();
    else if (!root.fingerprintConfigured && fingerprintPam.active)
      fingerprintPam.abort();
  }

  function logEvent(event) {
    lastEvent = event;
    lastEventAt = new Date().toISOString();
    console.log("omarchy lock " + lastEventAt + " " + event);
  }

  function resetAuthenticationState() {
    enteredPassword = "";
    pendingPassword = "";
    failureMessage = "";
    failedAttempts = 0;
    authenticatingPassword = false;
    fingerprintAuthenticating = false;
    fingerprintRetryTimer.stop();
    if (passwordPam.active)
      passwordPam.abort();
    if (fingerprintPam.active)
      fingerprintPam.abort();
  }

  function beginLock() {
    if (!passwordPamConfigured) {
      logEvent("lock-denied: missing-pam");
      return false;
    }
    resetAuthenticationState();
    lockRequested = true;
    armBlankTimer();
    logEvent("lock-requested");
    queueSessionLock();
    Qt.callLater(function () {
        root.refreshBackground();
        root.refreshFingerprintStatus();
      });
    return true;
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested)
      return;
    lockRequested = false;
    pendingSessionLock = false;
    sessionLockStabilizeTimer.stop();
    pendingSessionLockTimer.stop();
    resetAuthenticationState();
    idleBlankTimer.stop();
    sessionLock.locked = false;
    logEvent("unlocked");
    runWake();
  }

  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now();
    idleBlankTimer.restart();
  }

  function runWake() {
    if (!wakeProcess.running) {
      wakeProcess.running = true;
      wakeWatchdog.restart();
    }
    if (lockRequested)
      armBlankTimer();
  }

  function runBlank() {
    if (!blankKeyboardProc.running) {
      blankKeyboardProc.running = true;
      blankWatchdog.restart();
    }
    if (!blankDisplayProc.running) {
      blankDisplayProc.running = true;
      blankWatchdog.restart();
    }
  }

  function requestShutdown() {
    root.runPower([root.omarchyBin, "system", "shutdown"]);
  }

  function requestReboot() {
    root.runPower([root.omarchyBin, "system", "reboot"]);
  }

  function requestSuspend() {
    root.runPower([root.systemctlBin, "suspend"]);
  }

  function runPower(args) {
    if (powerProc.running)
      return;
    powerProc.command = args;
    powerProc.collected = "";
    powerProc.collectedBytes = 0;
    powerProc.running = true;
    powerWatchdog.restart();
  }

  function submitPassword(value) {
    var password = String(value || "");
    if (!lockRequested || authenticatingPassword || password.length === 0)
      return;
    runWake();
    pendingPassword = password;
    failureMessage = "";
    authenticatingPassword = true;
    if (!passwordPam.start()) {
      handlePasswordFailure();
      return;
    }
    Qt.callLater(respondToPasswordPrompt);
  }

  function respondToPasswordPrompt() {
    if (!authenticatingPassword || !passwordPam.active || !passwordPam.responseRequired)
      return;
    passwordPam.respond(pendingPassword);
  }

  function handlePasswordFailure() {
    if (!lockRequested)
      return;
    authenticatingPassword = false;
    enteredPassword = "";
    pendingPassword = "";
    failedAttempts += 1;
    failureMessage = "Authentication failed (" + failedAttempts + ")";
    runWake();
  }

  function startFingerprint() {
    if (!lockRequested || !sessionLock.secure || !fingerprintConfigured)
      return;
    if (fingerprintPam.active || fingerprintAuthenticating)
      return;
    fingerprintAuthenticating = true;
    if (!fingerprintPam.start()) {
      fingerprintAuthenticating = false;
    }
  }

  function handleFingerprintFinished(result) {
    fingerprintAuthenticating = false;
    if (!lockRequested)
      return;
    if (result === PamResult.Success) {
      finishUnlock();
    } else if (fingerprintConfigured) {
      fingerprintRetryTimer.restart();
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: false

    onSecureStateChanged: {
      root.logEvent("secure=" + secure);
      if (secure) {
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
        root.startFingerprint();
      }
    }

    onLockStateChanged: {
      root.logEvent("session-locked=" + locked);
      if (locked) {
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
      }
      if (!locked && root.lockRequested) {
        root.lockRequested = false;
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
        root.resetAuthenticationState();
        root.runWake();
      }
    }

    WlSessionLockSurface {
      id: lockSurface
      color: Color.background

      LockView {
        id: lockView
        anchors.fill: parent
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
        fingerprintConfigured: root.fingerprintConfigured
        authenticatingPassword: root.authenticatingPassword
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        inputEnabled: root.lockRequested
        loadBackground: root.locked
        passwordText: root.enteredPassword
        userName: root.userName
        timeFormat: root.timeFormat
        dateFormat: root.dateFormat
        audioBass: root.audioBass
        audioHigh: root.audioHigh
        audioBands: root.audioBands
        auraStyle: root.auraStyle
        auraIntensity: root.auraIntensity
        weather: root.weather
        onAuraStyleCycleRequested: root.cycleAuraStyle()
        onPasswordTextEdited: function (password) {
          root.enteredPassword = password;
        }
        onSubmitPassword: function (password) {
          root.submitPassword(password);
        }
        onClearFailureRequested: root.failureMessage = ""
        onWakeRequested: root.runWake()
        onSleepRequested: root.runBlank()
        onShutdownRequested: root.requestShutdown()
        onRebootRequested: root.requestReboot()
        onSuspendRequested: root.requestSuspend()
      }
    }
  }

  PanelWindow {
    id: previewWindow
    visible: root.previewVisible
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    LockView {
      anchors.fill: parent
      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: false
      failureMessage: ""
      failedAttempts: 0
      inputEnabled: false
      loadBackground: root.previewVisible
      passwordText: ""
      userName: root.userName
      timeFormat: root.timeFormat
      dateFormat: root.dateFormat
      audioBass: root.audioBass
      audioHigh: root.audioHigh
      audioBands: root.audioBands
      auraStyle: root.auraStyle
      auraIntensity: root.auraIntensity
      weather: root.weather
      onAuraStyleCycleRequested: root.cycleAuraStyle()
      onWakeRequested: root.runWake()
      onSleepRequested: root.runBlank()
      onShutdownRequested: root.requestShutdown()
      onRebootRequested: root.requestReboot()
      onSuspendRequested: root.requestSuspend()
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.previewVisible = false
    }
  }

  PamContext {
    id: passwordPam
    config: "omarchy-lock-password"
    user: root.userName

    onResponseRequiredChanged: root.respondToPasswordPrompt()
    onPamMessage: root.respondToPasswordPrompt()

    onCompleted: function (result) {
      root.authenticatingPassword = false;
      root.pendingPassword = "";
      if (!root.lockRequested)
        return;
      if (result === PamResult.Success)
        root.finishUnlock();
      else
        root.handlePasswordFailure();
    }

    onError: function (error) {
      root.handlePasswordFailure();
    }
  }

  PamContext {
    id: fingerprintPam
    config: "omarchy-lock-fingerprint"
    user: root.userName

    onCompleted: function (result) {
      root.handleFingerprintFinished(result);
    }

    onError: function (error) {
      root.fingerprintAuthenticating = false;
      if (root.lockRequested && root.fingerprintConfigured)
        fingerprintRetryTimer.restart();
    }
  }

  Timer {
    id: fingerprintRetryTimer
    interval: 250
    repeat: false
    onTriggered: root.startFingerprint()
  }

  Timer {
    id: backgroundWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (backgroundProc.running) {
        backgroundProc.timedOut = true;
        backgroundProc.collected = "";
        backgroundProc.collectedBytes = 0;
        root.killProc(backgroundProc);
      }
    }
  }

  Process {
    id: backgroundProc
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (backgroundProc.overflowed || backgroundProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (backgroundProc.collectedBytes + chunk.length > root.maxHelperBytes) {
          backgroundProc.overflowed = true;
          backgroundProc.collected = "";
          backgroundProc.collectedBytes = 0;
          root.killProc(backgroundProc);
          return;
        }
        backgroundProc.collected += chunk;
        backgroundProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (backgroundProc.overflowed || backgroundProc.timedOut)
          return;
        backgroundProc.collectedBytes += String(data + "\n").length;
        if (backgroundProc.collectedBytes > root.maxHelperBytes) {
          backgroundProc.overflowed = true;
          backgroundProc.collected = "";
          backgroundProc.collectedBytes = 0;
          root.killProc(backgroundProc);
        }
      }
    }
    onExited: function (exitCode) {
      backgroundWatchdog.stop();
      var failed = backgroundProc.overflowed || backgroundProc.timedOut;
      var output = String(backgroundProc.collected);
      backgroundProc.collected = "";
      backgroundProc.collectedBytes = 0;
      backgroundProc.overflowed = false;
      backgroundProc.timedOut = false;
      var next = (!failed && exitCode === 0) ? root.acceptBackground(output) : "";
      if (next !== "" && next !== root.backgroundPath) {
        root.backgroundPath = next;
        root.backgroundVersion += 1;
      } else if (next === "" && root.backgroundPath !== "") {
        root.backgroundPath = "";
        root.backgroundVersion += 1;
      }
    }
  }

  Timer {
    id: fingerprintWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (fingerprintListProc.running) {
        fingerprintListProc.timedOut = true;
        fingerprintListProc.collected = "";
        fingerprintListProc.collectedBytes = 0;
        root.killProc(fingerprintListProc);
        root.setFingerprintConfigured(false);
      }
    }
  }

  Process {
    id: fingerprintListProc
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath
      })
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (fingerprintListProc.overflowed || fingerprintListProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (fingerprintListProc.collectedBytes + chunk.length > root.maxHelperBytes) {
          fingerprintListProc.overflowed = true;
          fingerprintListProc.collected = "";
          fingerprintListProc.collectedBytes = 0;
          root.killProc(fingerprintListProc);
          return;
        }
        fingerprintListProc.collected += chunk;
        fingerprintListProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (fingerprintListProc.overflowed || fingerprintListProc.timedOut)
          return;
        fingerprintListProc.collectedBytes += String(data + "\n").length;
        if (fingerprintListProc.collectedBytes > root.maxHelperBytes) {
          fingerprintListProc.overflowed = true;
          fingerprintListProc.collected = "";
          fingerprintListProc.collectedBytes = 0;
          root.killProc(fingerprintListProc);
        }
      }
    }
    onExited: function (exitCode) {
      fingerprintWatchdog.stop();
      var failed = fingerprintListProc.overflowed || fingerprintListProc.timedOut;
      var output = String(fingerprintListProc.collected);
      fingerprintListProc.collected = "";
      fingerprintListProc.collectedBytes = 0;
      fingerprintListProc.overflowed = false;
      fingerprintListProc.timedOut = false;
      var enrolled = !failed && exitCode === 0 && output.toLowerCase().indexOf("finger") !== -1;
      root.setFingerprintConfigured(root.fingerprintPamFile && enrolled);
    }
  }

  Timer {
    id: strandedWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (strandedLockCheckProc.running) {
        root.killProc(strandedLockCheckProc);
        root.strandedLockResolved = true;
      }
    }
  }

  Process {
    id: strandedLockCheckProc
    command: [root.sessionLockedBin]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        strandedLockCheckProc.collectedBytes += String(data + "\n").length;
        if (strandedLockCheckProc.collectedBytes > root.maxHelperBytes)
          root.killProc(strandedLockCheckProc);
      }
    }
    property int collectedBytes: 0
    onExited: function (exitCode) {
      strandedWatchdog.stop();
      strandedLockCheckProc.collectedBytes = 0;
      if (exitCode === 2)
        return;
      root.strandedLockResolved = true;
      root.strandedLock = exitCode === 0 && !root.locked && !root.lockRequested;
      root.recoverStrandedLock();
    }
  }

  Timer {
    id: wakeWatchdog
    interval: root.wakeTimeoutMs
    repeat: false
    onTriggered: {
      if (wakeProcess.running)
        root.killProc(wakeProcess);
    }
  }

  Process {
    id: wakeProcess
    command: [root.wakeBin]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        wakeProcess.collectedBytes += String(data + "\n").length;
        if (wakeProcess.collectedBytes > root.maxHelperBytes)
          root.killProc(wakeProcess);
      }
    }
    property int collectedBytes: 0
    onExited: {
      wakeWatchdog.stop();
      wakeProcess.collectedBytes = 0;
    }
  }

  Timer {
    id: blankWatchdog
    interval: root.wakeTimeoutMs
    repeat: false
    onTriggered: {
      if (blankKeyboardProc.running)
        root.killProc(blankKeyboardProc);
      if (blankDisplayProc.running)
        root.killProc(blankDisplayProc);
    }
  }

  Process {
    id: blankKeyboardProc
    command: [root.brightKeyboardBin, "off"]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        blankKeyboardProc.collectedBytes += String(data + "\n").length;
        if (blankKeyboardProc.collectedBytes > root.maxHelperBytes)
          root.killProc(blankKeyboardProc);
      }
    }
    property int collectedBytes: 0
    onExited: {
      blankKeyboardProc.collectedBytes = 0;
      if (!blankKeyboardProc.running && !blankDisplayProc.running)
        blankWatchdog.stop();
    }
  }

  Process {
    id: blankDisplayProc
    command: [root.brightDisplayBin, "off"]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        blankDisplayProc.collectedBytes += String(data + "\n").length;
        if (blankDisplayProc.collectedBytes > root.maxHelperBytes)
          root.killProc(blankDisplayProc);
      }
    }
    property int collectedBytes: 0
    onExited: {
      blankDisplayProc.collectedBytes = 0;
      if (!blankKeyboardProc.running && !blankDisplayProc.running)
        blankWatchdog.stop();
    }
  }

  Timer {
    id: powerWatchdog
    interval: 30000
    repeat: false
    onTriggered: {
      if (powerProc.running)
        root.killProc(powerProc);
    }
  }

  Process {
    id: powerProc
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null,
        "DBUS_SESSION_BUS_ADDRESS": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        var chunk = String(data + "\n");
        if (powerProc.collectedBytes + chunk.length > root.maxHelperBytes) {
          root.logEvent("power-failed: stderr-overflow");
          root.killProc(powerProc);
          return;
        }
        powerProc.collected += chunk;
        powerProc.collectedBytes += chunk.length;
      }
    }
    property string collected: ""
    property int collectedBytes: 0
    onExited: function (exitCode) {
      powerWatchdog.stop();
      var err = String(powerProc.collected);
      powerProc.collected = "";
      powerProc.collectedBytes = 0;
      if (exitCode !== 0)
        root.logEvent("power-failed: exit=" + exitCode + (err !== "" ? " err=" + err.slice(0, 200) : ""));
      else if (err !== "")
        root.logEvent("power-stderr: " + err.slice(0, 200));
    }
  }

  FileView {
    id: lockConfigWriter
    path: Quickshell.env("HOME") + "/.config/omarchy/lock.json"
    atomicWrites: true
    blockLoading: false
    printErrors: false
    onSaveFailed: root.logEvent("aura-style-save-failed")
  }

  Process {
    id: cavaProcess
    command: [root.stdbufBin, "-oL", root.cavaBin, "-p", root.cavaConfigPath]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HOME": null,
        "XDG_RUNTIME_DIR": null,
        "PIPEWIRE_RUNTIME_DIR": null
      })
    stdout: SplitParser {
      onRead: function (data) {
        root.handleCavaFrame(data);
      }
    }
    onExited: function (exitCode) {
      root.audioBass = -1;
      root.audioHigh = 0;
      root.audioBands = [];
      if (root.audioWanted) {
        root.cavaFailures += 1;
        root.logEvent("cava-exited: " + exitCode + " (" + root.cavaFailures + "/3)");
        cavaRetryTimer.restart();
      }
    }
  }

  Timer {
    id: cavaRetryTimer
    interval: 2000
    repeat: false
    onTriggered: root.syncCava()
  }

  Timer {
    id: idleBlankTimer
    interval: 5000
    repeat: false
    property double armedAt: 0
    onTriggered: {
      if (Date.now() - armedAt > interval + 2000) {
        root.armBlankTimer();
        return;
      }
      if (root.lockRequested && !root.authenticatingPassword && !root.mediaPlaying)
        root.runBlank();
    }
  }

  Timer {
    id: sessionLockStabilizeTimer
    interval: 500
    repeat: false
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: pendingSessionLockTimer
    interval: 100
    repeat: true
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: strandedLockRetryTimer
    interval: 500
    repeat: true
    readonly property int budget: 20
    property int remaining: 20
    running: !root.strandedLockResolved && remaining > 0

    function rearm() {
      if (!root.strandedLockResolved)
        remaining = budget;
    }

    onTriggered: {
      remaining -= 1;
      root.checkStrandedLock();
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      root.requestSessionLock();
      strandedLockRetryTimer.rearm();
      root.checkStrandedLock();
    }
  }

  onAuthenticatingPasswordChanged: {
    if (!lockRequested)
      return;
    if (authenticatingPassword)
      idleBlankTimer.stop();
    else
      armBlankTimer();
  }

  FileView {
    path: "/etc/pam.d/omarchy-lock-password"
    watchChanges: true
    printErrors: false
    onLoaded: root.passwordPamConfigured = true
    onLoadFailed: root.passwordPamConfigured = false
    onFileChanged: reload()
  }

  FileView {
    path: root.fingerprintPamPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.fingerprintPamFile = true;
      root.refreshFingerprintStatus();
    }
    onLoadFailed: {
      root.fingerprintPamFile = false;
      root.setFingerprintConfigured(false);
    }
    onFileChanged: reload()
  }

  onPasswordPamConfiguredChanged: {
    if (!passwordPamConfigured)
      return;
    strandedLock = false;
    strandedLockResolved = false;
    strandedLockRetryTimer.rearm();
    checkStrandedLock();
  }

  Component.onCompleted: {
    refreshBackground();
    refreshFingerprintStatus();
    checkStrandedLock();
    root.loadConfig();
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      if (!root.passwordPamConfigured)
        return "missing-pam";
      if (!root.locked && !root.beginLock())
        return "failed";
      return "ok";
    }

    function isLocked(): string {
      return root.locked ? "true" : "false";
    }

    function status(): string {
      return JSON.stringify({
          "locked": root.locked,
          "requested": root.lockRequested,
          "pending": root.pendingSessionLock,
          "sessionLocked": sessionLock.locked,
          "secure": sessionLock.secure,
          "realScreens": root.realScreenCount(),
          "passwordPam": root.passwordPamConfigured,
          "fingerprint": root.fingerprintConfigured,
          "authenticating": root.authenticating,
          "lastEvent": root.lastEvent,
          "lastEventAt": root.lastEventAt
        });
    }

    function preview(): string {
      root.refreshBackground();
      root.refreshFingerprintStatus();
      root.previewVisible = true;
      return "ok";
    }

    function hidePreview(): string {
      root.previewVisible = false;
      return "ok";
    }

    function quietNowPlaying(ms: int): string {
      nowPlaying.quietUntil = Date.now() + Math.max(0, ms);
      return "ok";
    }

    function nowPlaying(): string {
      nowPlaying.announce();
      return nowPlaying.showing ? "shown" : "nothing-playing";
    }

    function screensaver(): string {
      root.screensaverPreview = !root.screensaverPreview;
      return root.screensaverPreview ? "shown" : "hidden";
    }

    function cycleAura(): string {
      root.cycleAuraStyle();
      return root.auraStyle;
    }
  }
}
