import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// Ambient, music-reactive glow for the lock screen, coloured from the cover art.
//
// Fills the whole lock view; styles position themselves around the media card
// (cardX/cardY/cardWidth/cardHeight, in this item's coordinates).
//
// Styles: "horizon" (light band along the bottom), "halo" (soft glow around
// the card, like the music menu), "spectrum" (soft light columns per frequency band), "cloud"
// (one swirling colour mass) and "orbs" (separate soft lights).
//
// `level` is bass energy 0..1, `high` mid/treble energy, `bands` six bands from
// low to high. While `level` is negative there is no audio feed and a synthetic
// pulse stands in for it.
Item {
  id: aura

  property string style: "horizon"
  property real intensity: 1
  property var colors: ["#ffffff", "#ffffff", "#ffffff", "#ffffff"]
  property bool present: false
  property bool playing: false
  // No music: the aura breathes slowly and dimly in the theme's colours.
  property bool idle: false
  // Whether the media card is on screen (styles that glow around it hide
  // that part without it).
  property bool cardVisible: true
  property bool animate: true
  property real level: -1
  property real high: 0
  property var bands: []
  // What sits behind the aura (the blurred wallpaper), for the halo's glass.
  property Item backdrop: null

  property real cardX: 0
  property real cardY: 0
  property real cardWidth: 400
  property real cardHeight: 144
  readonly property real cardCX: cardX + cardWidth / 2
  readonly property real cardCY: cardY + cardHeight / 2

  readonly property bool motion: animate && !Style.reduceMotion
  readonly property bool synthetic: level < 0
  readonly property bool running: motion && present && (playing || idle)
  readonly property real k: Math.max(0.2, Math.min(2, intensity))

  // Seconds of animated time and the halo's rotation angle, advanced per frame.
  property real clock: 0
  property real spin: 0

  FrameAnimation {
    running: aura.running
    onTriggered: {
      aura.clock += frameTime;
      aura.spin = (aura.spin + frameTime * (30 + 160 * aura.sparkle)) % 360;
    }
  }

  // Synthetic breathing when there is no audio feed.
  property real breath: 0
  SequentialAnimation on breath {
    running: aura.running && aura.synthetic && !aura.idle
    loops: Animation.Infinite
    NumberAnimation { from: 0.25; to: 1; duration: 900; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0.25; duration: 1200; easing.type: Easing.InOutSine }
  }

  // Idle: a slow breath, about six seconds in and out.
  property real idleBreath: 0.5
  SequentialAnimation on idleBreath {
    running: aura.motion && aura.present && aura.idle
    loops: Animation.Infinite
    NumberAnimation { from: 0.2; to: 0.75; duration: 3200; easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.75; to: 0.2; duration: 3600; easing.type: Easing.InOutSine }
  }

  // Audio levels, eased just enough to hide 45 fps steps.
  property real audioEnergy: Math.max(0, Math.min(1, level))
  property real audioHigh: Math.max(0, Math.min(1, high))
  Behavior on audioEnergy {
    NumberAnimation { duration: Style.duration(50); easing.type: Easing.OutCubic }
  }
  Behavior on audioHigh {
    NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutCubic }
  }

  readonly property real energy: idle ? (motion ? idleBreath * 0.6 : 0.3) : (!playing ? 0.2 : (!motion ? 0.5 : (synthetic ? breath : audioEnergy)))
  readonly property real sparkle: playing && motion && !synthetic ? audioHigh : 0

  // Value of the spectrum at position x in 0..5 (band index, interpolated).
  function bandAt(x) {
    if (!playing)
      return 0.15;
    if (!motion)
      return 0.4;
    if (synthetic || !bands || bands.length < 6)
      return 0.2 + 0.6 * breath * (0.5 + 0.5 * Math.sin(clock * (2.0 + x * 0.35) + x * 1.3));
    var i = Math.max(0, Math.min(5, x));
    var lo = Math.floor(i), hi = Math.min(5, lo + 1), f = i - lo;
    return bands[lo] + (bands[hi] - bands[lo]) * f;
  }

  function mix(a, b, f) {
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
  }

  // Palette colour at position t in 0..1, blending neighbours.
  function paletteAt(t) {
    var x = Math.max(0, Math.min(1, t)) * 3;
    var lo = Math.floor(x), hi = Math.min(3, lo + 1);
    return mix([c0, c1, c2, c3][lo], [c0, c1, c2, c3][hi], x - lo);
  }

  // Palette with smooth cross-fades when the track changes.
  property color c0: colors[0]
  property color c1: colors[1 % colors.length]
  property color c2: colors[2 % colors.length]
  property color c3: colors[3 % colors.length]
  Behavior on c0 { ColorAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }
  Behavior on c1 { ColorAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }
  Behavior on c2 { ColorAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }
  Behavior on c3 { ColorAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }

  opacity: present ? 1 : 0
  visible: opacity > 0
  Behavior on opacity {
    NumberAnimation { duration: Style.duration(aura.present ? 250 : 150); easing.type: Easing.OutCubic }
  }

  Loader {
    anchors.fill: parent
    active: aura.visible
    sourceComponent: aura.style === "halo" ? haloStyle : aura.style === "spectrum" ? spectrumStyle : aura.style === "cloud" ? cloudStyle : aura.style === "orbs" ? orbsStyle : horizonStyle
  }

  // ── Horizon: a continuous band of light along the bottom of the screen ──
  Component {
    id: horizonStyle

    Item {
      id: horizon
      width: aura.width
      height: Math.max(180, aura.height - aura.cardY + 80)
      y: aura.height - height
      clip: true
      opacity: Math.min(1, (0.6 + 0.35 * aura.energy + 0.25 * aura.sparkle) * aura.k)
      transform: Scale {
        origin.y: horizon.height
        yScale: 0.6 + 0.55 * aura.energy
      }

      Canvas {
        id: horizonCanvas
        width: horizon.width * 2
        height: horizon.height
        // Slide sideways; the pattern repeats every horizon.width so it loops seamlessly.
        x: -((aura.clock * 45) % Math.max(1, horizon.width))
        renderTarget: Canvas.Image
        readonly property var paintKey: [aura.c0, aura.c1, aura.c2, aura.c3, width, height]
        onPaintKeyChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          var cols = [aura.c0, aura.c1, aura.c2, aura.c3];
          var g = ctx.createLinearGradient(0, 0, width, 0);
          for (var i = 0; i <= 8; i++)
            g.addColorStop(i / 8, String(cols[i % 4]));
          ctx.fillStyle = g;
          ctx.fillRect(0, 0, width, height);
          // Fade out towards the top.
          ctx.globalCompositeOperation = "destination-in";
          var v = ctx.createLinearGradient(0, 0, 0, height);
          v.addColorStop(0, "rgba(0,0,0,0)");
          v.addColorStop(0.45, "rgba(0,0,0,0.35)");
          v.addColorStop(1, "rgba(0,0,0,1)");
          ctx.fillStyle = v;
          ctx.fillRect(0, 0, width, height);
        }
      }
    }
  }

  // ── Halo: a copy of the music menu's glow, glass included ──
  // In the bar menu Hyprland's glassy blur (ignore_alpha 0.3) frosts whatever
  // lies behind the glow wherever it is more than 30% opaque, which draws a
  // sharp-edged acrylic rim that grows and shrinks with the bass. The lock
  // screen gets no compositor blur, so the same is done here: the backdrop,
  // darkened and saturated like Hyprland's glass (brightness 0.75, vibrancy
  // 0.35), shows only where the glow passes 0.3; the glow is drawn on top.
  Component {
    id: haloStyle

    // The Loader stretches its item over the view; the glow sits inside.
    Item {
      id: haloRoot
      readonly property int spread: Style.space(10)
      readonly property int pad: spread + 48
      readonly property real glowOpacity: Math.min(1, (aura.playing && aura.motion && !aura.synthetic ? 0.22 + 0.43 * aura.audioEnergy : 0.45) * aura.k)

      component Glow: Item {
        Rectangle {
          x: haloRoot.pad - haloRoot.spread
          y: haloRoot.pad - haloRoot.spread
          width: aura.cardWidth + haloRoot.spread * 2
          height: aura.cardHeight + haloRoot.spread * 2
          radius: Style.cornerRadius + haloRoot.spread
          opacity: haloRoot.glowOpacity
          Behavior on opacity { NumberAnimation { duration: 90 } }
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: aura.c0 }
            GradientStop { position: 0.5; color: aura.c1 }
            GradientStop { position: 1.0; color: aura.c2 }
          }
          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 32
            autoPaddingEnabled: true
          }
        }
      }

      Item {
        id: region
        visible: aura.cardVisible
        x: aura.cardX - haloRoot.pad
        y: aura.cardY - haloRoot.pad
        width: aura.cardWidth + haloRoot.pad * 2
        height: aura.cardHeight + haloRoot.pad * 2

        // The glow's alpha, used as the glass mask.
        Glow {
          id: glassMask
          anchors.fill: parent
          visible: false
          layer.enabled: true
        }

        // Glass: the backdrop behind the glow, frosted like Hyprland's.
        Item {
          anchors.fill: parent
          visible: aura.backdrop !== null
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: glassMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.08
          }
          ShaderEffectSource {
            id: behind
            anchors.fill: parent
            sourceItem: aura.backdrop
            sourceRect: Qt.rect(region.x, region.y, region.width, region.height)
            live: true
            visible: false
          }
          MultiEffect {
            anchors.fill: parent
            source: behind
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.3
            blurMax: 16
            saturation: 0.35
          }
          // The lock's own shade over the wallpaper, then the glass's 0.75.
          Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
          Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25) }
        }

        // The glow itself, over the glass.
        Glow { anchors.fill: parent }
      }

      // Screen edges: the same light frame the windows get while music plays,
      // here on all four walls of the lock screen, beating with the bass.
      Item {
        id: edges
        anchors.fill: parent
        readonly property int wall: Style.space(20)
        opacity: Math.min(1, (aura.idle ? (aura.motion ? 0.12 + 0.45 * aura.idleBreath : 0.35) : (aura.playing && aura.motion && !aura.synthetic ? 0.3 + 0.7 * aura.audioEnergy : 0.6)) * aura.k)
        Behavior on opacity { NumberAnimation { duration: aura.idle ? 400 : 90 } }
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1.0
          blurMax: 32
          autoPaddingEnabled: false
        }

        component Wall: Rectangle {
          property bool across: true
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: aura.c0 }
            GradientStop { position: 0.5; color: aura.c1 }
            GradientStop { position: 1.0; color: aura.c2 }
          }
        }
        Wall { x: 0; y: -edges.wall / 2; width: parent.width; height: edges.wall }
        Wall { x: 0; y: parent.height - edges.wall / 2; width: parent.width; height: edges.wall }
        Rectangle { x: -edges.wall / 2; y: 0; width: edges.wall; height: parent.height; color: aura.c0 }
        Rectangle { x: parent.width - edges.wall / 2; y: 0; width: edges.wall; height: parent.height; color: aura.c2 }
      }
    }
  }

  // ── Spectrum: soft columns of light rising from the bottom, low to high ──
  Component {
    id: spectrumStyle

    Item {
      id: spectrum
      readonly property int columns: 18
      width: aura.width
      height: Math.max(180, aura.height - aura.cardY + 80)
      y: aura.height - height
      opacity: Math.min(1, (0.8 + 0.25 * aura.sparkle) * aura.k)
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        saturation: 0.2
        autoPaddingEnabled: false
      }

      Row {
        anchors.fill: parent

        Repeater {
          model: spectrum.columns

          Item {
            id: column
            required property int index
            readonly property real t: index / (spectrum.columns - 1)
            readonly property real value: aura.bandAt(t * 5)
            readonly property color tint: aura.paletteAt(t)
            width: spectrum.width / spectrum.columns
            height: spectrum.height

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width * 0.75
              height: parent.height * (0.1 + 0.9 * column.value)
              radius: width / 2
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(column.tint.r, column.tint.g, column.tint.b, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(column.tint.r, column.tint.g, column.tint.b, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(column.tint.r, column.tint.g, column.tint.b, 0.95) }
              }
              Behavior on height {
                NumberAnimation { duration: Style.duration(60); easing.type: Easing.OutCubic }
              }
            }
          }
        }
      }
    }
  }

  // ── Cloud: one mass of colour whose hues swirl into each other ──
  Component {
    id: cloudStyle

    Item {
      id: cloud
      width: Math.min(aura.width, aura.cardWidth * 2.6)
      height: aura.cardHeight * 3
      x: aura.cardCX - width / 2
      y: aura.cardCY - height / 2 + 20
      scale: 1 + 0.14 * aura.energy
      opacity: Math.min(1, (0.6 + 0.35 * aura.energy + 0.2 * aura.sparkle) * aura.k)
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.3
        autoPaddingEnabled: true
      }

      Repeater {
        model: [
          { "speed": 0.35, "phase": 0.0, "rx": 0.16, "ry": 0.12 },
          { "speed": -0.28, "phase": 1.7, "rx": 0.2, "ry": 0.1 },
          { "speed": 0.22, "phase": 3.3, "rx": 0.14, "ry": 0.14 },
          { "speed": -0.4, "phase": 4.8, "rx": 0.18, "ry": 0.09 }
        ]

        GlowBlob {
          required property var modelData
          required property int index
          tint: [aura.c0, aura.c1, aura.c2, aura.c3][index]
          diameter: cloud.width * 0.6
          squash: 0.6
          x: cloud.width / 2 - width / 2 + Math.cos(aura.clock * modelData.speed + modelData.phase) * cloud.width * modelData.rx
          y: cloud.height / 2 - height / 2 + Math.sin(aura.clock * modelData.speed * 1.2 + modelData.phase) * cloud.height * modelData.ry
        }
      }
    }
  }

  // ── Orbs: separate soft lights around the card ──
  Component {
    id: orbsStyle

    Item {
      id: orbs
      width: Math.min(aura.width, aura.cardWidth * 2.4)
      height: aura.cardHeight * 2.6
      x: aura.cardCX - width / 2
      y: aura.cardCY - height / 2 + 20

      Repeater {
        model: [
          { "dx": 0.0, "dy": 0.0, "size": 1.0, "orbit": 18, "phase": 0.0, "gain": 1.0 },
          { "dx": -0.42, "dy": 0.05, "size": 0.8, "orbit": 34, "phase": 1.6, "gain": 0.9 },
          { "dx": 0.42, "dy": 0.05, "size": 0.8, "orbit": 34, "phase": 3.4, "gain": 0.9 },
          { "dx": 0.0, "dy": 0.22, "size": 0.65, "orbit": 26, "phase": 5.0, "gain": 0.8 }
        ]

        GlowBlob {
          required property var modelData
          required property int index
          readonly property real drift: aura.clock * 0.4
          tint: [aura.c0, aura.c1, aura.c2, aura.c3][index]
          diameter: orbs.width * 0.62 * modelData.size
          squash: 0.5 * (1 + 0.24 * aura.energy * modelData.gain)
          x: orbs.width / 2 + modelData.dx * orbs.width - width / 2 + Math.cos(drift + modelData.phase) * modelData.orbit
          y: orbs.height / 2 + modelData.dy * orbs.height - height / 2 + Math.sin(drift * 1.3 + modelData.phase) * modelData.orbit * 0.6
          scale: 1 + 0.2 * aura.energy * modelData.gain
          opacity: Math.min(1, (0.45 + 0.45 * aura.energy + 0.3 * aura.sparkle) * modelData.gain * aura.k)
        }
      }
    }
  }

  // Soft radial light used by the cloud and orbs styles.
  component GlowBlob: Shape {
    id: blob
    property color tint: "white"
    property real diameter: 100
    property real squash: 1

    width: diameter
    height: diameter
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
      origin.x: blob.width / 2
      origin.y: blob.height / 2
      yScale: blob.squash
    }

    ShapePath {
      strokeWidth: -1
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: blob.diameter / 2
        centerY: blob.diameter / 2
        centerRadius: blob.diameter / 2
        focalX: blob.diameter / 2
        focalY: blob.diameter / 2
        GradientStop { position: 0.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 1.0) }
        GradientStop { position: 0.35; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.55) }
        GradientStop { position: 0.7; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.15) }
        GradientStop { position: 1.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.0) }
      }

      PathAngleArc {
        centerX: blob.diameter / 2
        centerY: blob.diameter / 2
        radiusX: blob.diameter / 2
        radiusY: blob.diameter / 2
        startAngle: 0
        sweepAngle: 360
      }
    }
  }
}
