import QtQuick
import qs.Commons

// Four-colour palette sampled from a cover image. palette[0] is the dominant
// hue, the rest other distinct hues (or variations of [0] when the cover has
// few colours). Without usable art it is derived from `fallback`.
Item {
  id: coverRoot

  property string artUrl: ""
  property bool artReady: true
  property color fallback: Color.accent

  property var sampledPalette: []
  property bool hasSampledAccent: false
  readonly property var themePalette: coverRoot.completePalette([fallback])
  readonly property var colors: hasSampledAccent && artReady && artUrl !== "" && sampledPalette.length === 4 ? sampledPalette : themePalette

  width: 24
  height: 24

  // Pads a palette to four colours with hue-shifted variations of its members.
  function completePalette(colors) {
    var out = colors.slice(0, 4);
    var shifts = [[0.07, 0.06], [-0.07, -0.04], [0.14, 0.1]];
    var k = 0;
    while (out.length < 4) {
      var base = out[k % colors.length];
      var h = base.hslHue < 0 ? 0 : base.hslHue;
      var shift = shifts[k % shifts.length];
      var l = Math.max(0.45, Math.min(0.75, base.hslLightness + shift[1]));
      out.push(Qt.hsla((h + shift[0] + 1) % 1, Math.max(0.4, base.hslSaturation), l, 1));
      k++;
    }
    return out;
  }

  function normalizeColor(r, g, b) {
    var c = Qt.rgba(r, g, b, 1);
    var h = c.hslHue < 0 ? 0 : c.hslHue;
    return Qt.hsla(h, Math.max(0.45, c.hslSaturation), Math.max(0.5, Math.min(0.7, c.hslLightness)), 1);
  }

  function sampleAccent() {
    var ctx = sampler.getContext("2d");
    var url = sampler.loadedUrl;
    if (!ctx || url === "" || !sampler.isImageLoaded(url)) {
      hasSampledAccent = false;
      return;
    }
    var n = sampler.width;
    ctx.clearRect(0, 0, n, n);
    ctx.drawImage(url, 0, 0, n, n);
    var data = ctx.getImageData(0, 0, n, n).data;
    // The canvas is only a scratch buffer: wipe it so the thumbnail never shows.
    ctx.clearRect(0, 0, n, n);

    // Bucket vivid pixels by hue (12 x 30 degrees), weighting saturation and brightness.
    var bucketCount = 12;
    var buckets = [];
    for (var k = 0; k < bucketCount; k++)
      buckets.push({ "r": 0, "g": 0, "b": 0, "w": 0, "index": k });
    var total = 0;
    for (var i = 0; i < data.length; i += 4) {
      var pr = data[i] / 255, pg = data[i + 1] / 255, pb = data[i + 2] / 255;
      var max = Math.max(pr, pg, pb), min = Math.min(pr, pg, pb);
      var delta = max - min;
      if (max <= 0 || delta <= 0)
        continue;
      var sat = delta / max;
      var w = sat * sat * max * (data[i + 3] / 255);
      if (w < 0.01)
        continue;
      var hue;
      if (max === pr)
        hue = ((pg - pb) / delta) % 6;
      else if (max === pg)
        hue = (pb - pr) / delta + 2;
      else
        hue = (pr - pg) / delta + 4;
      hue = ((hue / 6) + 1) % 1;
      var bucket = buckets[Math.min(bucketCount - 1, Math.floor(hue * bucketCount))];
      bucket.r += pr * w;
      bucket.g += pg * w;
      bucket.b += pb * w;
      bucket.w += w;
      total += w;
    }
    if (total < 0.5) {
      hasSampledAccent = false;
      return;
    }

    // Strongest buckets first; keep those with real presence and at least 60 degrees apart.
    buckets.sort(function (x, y) { return y.w - x.w; });
    var chosen = [];
    var picked = [];
    for (var j = 0; j < buckets.length && chosen.length < 4; j++) {
      var bk = buckets[j];
      if (bk.w < total * 0.06)
        break;
      var tooClose = false;
      for (var q = 0; q < picked.length; q++) {
        var d = Math.abs(picked[q] - bk.index);
        if (Math.min(d, bucketCount - d) < 2) {
          tooClose = true;
          break;
        }
      }
      if (tooClose)
        continue;
      picked.push(bk.index);
      chosen.push(normalizeColor(bk.r / bk.w, bk.g / bk.w, bk.b / bk.w));
    }
    if (chosen.length === 0) {
      hasSampledAccent = false;
      return;
    }
    sampledPalette = completePalette(chosen);
    hasSampledAccent = true;
  }

  // Hidden-behind-the-card sampler used only to compute the cover accent colour.
  Canvas {
    id: sampler
    width: 24
    height: 24
    z: -10
    renderTarget: Canvas.Image
    property string loadedUrl: ""

    function sync() {
      if (loadedUrl !== "")
        unloadImage(loadedUrl);
      loadedUrl = coverRoot.artUrl;
      coverRoot.hasSampledAccent = false;
      if (loadedUrl === "")
        return;
      if (isImageLoaded(loadedUrl))
        requestPaint();
      else
        loadImage(loadedUrl);
    }

    onImageLoaded: requestPaint()
    onPaint: coverRoot.sampleAccent()
    Component.onCompleted: sync()
  }

  onArtUrlChanged: sampler.sync()
}
