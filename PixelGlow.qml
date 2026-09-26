// Scatter-dithered tile glow.
//
// The light is not a disc. Every tile owns a threshold, and a tile only lights
// when the light under the cursor beats that threshold. The threshold is an
// ordered 8x8 dither rank mixed with a per-tile random offset, the way the
// omarchy-site hero field does it, so a bright pool arrives as a loose
// constellation of squares that thickens toward the cursor and dissolves at
// its edge. A click stamps the Omarchy mark, which grows from under a cell per
// logo pixel to a few and melts away through the same dither.
//
// The tiles are items rather than drawn pixels: a full screen canvas has to
// hand its whole backing store over every frame it changes, which costs more
// than the effect is worth. A pool of rectangles costs nothing while the
// cursor is still, and only the tiles that change while it moves.
import QtQuick

Item {
  id: root

  // ---- lattice, in logical pixels ----
  property real cell: 16     // tile pitch
  property real gap: 1       // grout the tile leaves to the grid overlay

  // ---- light ----
  property real radius: 4       // radius of the solid core, in tiles
  property real intensity: 0.7  // peak brightness, 0.0 to 1.0
  property real scatter: 0.22   // 0 = pure ordered dither, 1 = pure random
  property real drift: 0        // ambient wandering pool, 0 disables it

  // ---- inks, dimmest to brightest ----
  property color inkDim: "#22300f"
  property color inkMid: "#5c7a3c"
  property color inkLit: "#9ece6a"
  property color inkHover: "#c2e593"
  property color inkCrest: "#e9f7d8"

  // Driven by the parent: false parks the effect entirely.
  property bool active: true

  // ---- live state ----
  property real pointerX: -1e4
  property real pointerY: -1e4
  property real pointerAmp: 0
  property real clock: 0
  property var pings: []
  property bool needsPaint: true

  property real pointerAmpTarget: 0
  property int lastFrameMs: 0

  // The ambient pool's brightness as of the last paint, so a charge dimming or
  // a mark lighting it is a change step() can see.
  property real paintedDriftAmp: -1

  property var tiles: []
  property int used: 0
  property int shown: 0

  // The ambient pool charges by dimming, then blooms the mark, the way the
  // site's sprite does: once after a second or two of drifting, then every two
  // to three, at a charge no bigger than a quick click's.
  property real spriteStampAt: Infinity
  property real spriteChargeAt: 0
  property real spriteCharge: 0

  readonly property int pingSlots: 4
  readonly property real tileSpan: Math.max(1, cell - gap)

  /**
   * Reach of the pool in logical pixels. The dither eats most of the light,
   * so the pool has to reach well past the radius the slider names for its
   * scattered edge to land where the slider says it should.
   */
  readonly property real reach: cell * (radius + 0.5) * 2.0

  /** The widest a stamp may bloom, in cells per logo pixel. The site lets a
   *  long hold run to 6.25; this stops short of it so the pool of tiles a
   *  stamp can want stays a size a wallpaper can afford. */
  readonly property real markMax: 4.0

  /** How long a held press has to charge, and how long a mark burns for a
   *  charge. Both are the site's, to the decimal. */
  readonly property real chargeTime: 1.1
  readonly property real markLife: 0.65
  readonly property real markLifePerCharge: 0.55

  readonly property int colMax: Math.max(0, Math.ceil(width / cell) - 1)
  readonly property int rowMax: Math.max(0, Math.ceil(height / cell) - 1)

  /** Tiles one pool of this reach can ever want, and so the pool of them. */
  readonly property int poolCells: {
    var across = 2 * Math.ceil(reach / cell) + 1
    return across * across
  }

  /** 95 lit logo pixels, each covering at most markMax cells a side. */
  readonly property int markCells: 95 * markMax * markMax

  readonly property int tileBudget:
    Math.min(6000, poolCells * (drift > 0.002 ? 2 : 1) + Math.ceil(markCells))

  /** The ambient pool wanders on two incommensurate periods, so it never
   *  returns to the same place and no loop seam can show. */
  readonly property real driftX:
    width * (0.5 + 0.44 * (1 + 0.1 * Math.sin(clock * 0.11)) * Math.sin(clock * 0.6483))
  readonly property real driftY:
    height * (0.48 + 0.38 * (1 + 0.1 * Math.sin(clock * 0.0937 + 2)) * Math.sin(clock * 0.3911 + 1.1))

  /** The ambient pool's brightness, dimmed to 40% while it charges, the way
   *  the site's sprite is. */
  readonly property real driftAmp: drift * intensity * (spriteChargeAt > 0 ? 0.4 : 1)

  /**
   * How often the ambient pool repaints, in seconds. It crosses the screen in
   * about ten seconds, so it does move every frame, but it is a soft dim pool
   * and nothing about it reads at refresh rate: the tiles it lights are a whole
   * cell across and it is never brighter than the pool under the cursor. A
   * third of the frames draws the same glow a frame earlier, and skipping them
   * is most of what the idle cost of the effect is. The mark it blooms is a
   * separate, short, fast animation and still repaints every frame.
   */
  readonly property real driftInterval: 1 / 30

  /** When the ambient pool last drew itself, so step() can hold it to its
   *  own rate while the pointer and the marks keep theirs. */
  property real lastDriftPaint: -1

  // The Omarchy mosaic mark, 15x15.
  readonly property var logoRows: [
    "111111111111111",
    "100000010000001",
    "101111110001101",
    "101000000000101",
    "101000000000101",
    "101000000000101",
    "101000000000101",
    "111000000000101",
    "101000000000101",
    "101000000000101",
    "101000000000101",
    "101000000000101",
    "101111111111101",
    "100000010000001",
    "111111110111111"
  ]

  // 32 baked steps of the ink ramp, so a tile never has its colour rebuilt.
  readonly property var inkLut: buildInkLut()

  function smoothstep(edge0, edge1, x) {
    var t = (x - edge0) / (edge1 - edge0)
    if (t < 0) t = 0
    else if (t > 1) t = 1
    return t * t * (3 - 2 * t)
  }

  function mixColor(a, b, t) {
    if (t <= 0) return a
    if (t >= 1) return b
    return Qt.rgba(
      a.r + (b.r - a.r) * t,
      a.g + (b.g - a.g) * t,
      a.b + (b.b - a.b) * t,
      1
    )
  }

  function buildInkLut() {
    // Where each ink starts taking over, dimmest first.
    var edges = [0.04, 0.24, 0.5, 0.76, 0.96]
    var inks = [inkDim, inkMid, inkLit, inkHover, inkCrest]
    var out = []
    for (var i = 0; i < 32; i++) {
      var h = i / 31
      var c = inks[0]
      for (var s = 1; s < inks.length; s++) {
        c = mixColor(c, inks[s], smoothstep(edges[s - 1], edges[s], h))
      }
      // Fading the dimmest steps back keeps a scattered edge from looking
      // like stickers laid on the wallpaper.
      out.push(Qt.rgba(c.r, c.g, c.b, 0.35 + 0.65 * h))
    }
    return out
  }

  /**
   * The 8x8 ordered dither, built from three interleaved 2x2 levels so the
   * pattern needs no table. Ranks run 0..63.
   */
  function bayerRank(col, row) {
    var x = col & 7
    var y = row & 7
    var v = 0
    for (var k = 0; k < 3; k++) {
      var xb = (x >> k) & 1
      var yb = (y >> k) & 1
      v = v * 4 + (2 * xb + 3 * yb - 4 * xb * yb)
    }
    return (v + 0.5) / 64
  }

  /**
   * A per-tile random offset, hashed from the tile place in a 64x64 patch of
   * noise, so a tile keeps its own threshold while it sits still and the
   * scatter repeats across the screen instead of clumping.
   */
  function tileNoise(col, row) {
    var h = Math.imul(col & 63, 73856093) ^ Math.imul(row & 63, 19349663)
    h = Math.imul(h ^ (h >>> 13), 1274126177)
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296
  }

  /**
   * Move the pool to a point. The pool is never smoothed: the cells under the
   * cursor are the cells that light, the way the site does it. Only the fade
   * in and out of its response is eased.
   */
  function pointerTo(x, y) {
    if (x === pointerX && y === pointerY && pointerAmpTarget === 1) return
    needsPaint = true
    pointerX = x
    pointerY = y
    pointerAmpTarget = 1
  }

  /** Let the pool die back to nothing. */
  function release() {
    pointerAmpTarget = 0
  }

  /**
   * Stamp the mark centred on a point. `charge` is 0..1, how long the press
   * was held: a quick click leaves a small mark, a long hold blooms a wide
   * one. The size jitters a little per stamp, so no two are quite twins.
   */
  function stamp(x, y, charge) {
    var c = Math.max(0, Math.min(1, charge))
    var from = 0.45 + 1.6 * c
    var next = pings.slice()
    next.push({
      x: x,
      y: y,
      born: clock,
      from: from,
      to: Math.min(markMax, from + 1.0 + 3.2 * c) * (0.92 + Math.random() * 0.16),
      life: (markLife + markLifePerCharge * c) * (0.92 + Math.random() * 0.16)
    })
    while (next.length > pingSlots) next.shift()
    pings = next
  }

  /** One live stamp as cells per logo pixel, and how strongly it is burning. */
  function stampVec(i) {
    var p = pings[i]
    if (!p) return { cell: 0, amp: 0 }
    var age = (clock - p.born) / p.life
    if (age < 0 || age >= 1) return { cell: 0, amp: 0 }
    var grow = 1 - Math.pow(1 - age, 3)
    return {
      cell: cell * (p.from + (p.to - p.from) * grow),
      amp: Math.pow(1 - age, 1.7)
    }
  }

  /** Advance every animated value by a frame, in wall clock seconds. */
  function step(dt) {
    clock += dt

    var moving = pings.length > 0

    // The ambient pool repaints on its own slower clock, so it is not redrawn
    // at refresh rate for a glow that is dimmer than the pool under the cursor
    // and a whole cell coarse. Dimming for a charge or lighting a mark is a
    // change in brightness rather than position, and it goes through at once:
    // waiting out the interval would show the bloom late.
    if (drift > 0.002) {
      if (Math.abs(driftAmp - paintedDriftAmp) > 0.004
          || clock - lastDriftPaint >= driftInterval) moving = true
    }

    // Rise fast, die back slow enough not to pop as the pointer leaves.
    var tau = pointerAmpTarget > pointerAmp ? 0.05 : 0.18
    pointerAmp += (pointerAmpTarget - pointerAmp) * (1 - Math.exp(-dt / tau))
    if (Math.abs(pointerAmpTarget - pointerAmp) < 0.002) pointerAmp = pointerAmpTarget
    if (pointerAmp !== pointerAmpTarget) moving = true

    if (drift > 0.002) {
      if (spriteStampAt === Infinity) spriteStampAt = clock + 1 + Math.random()
      if (spriteChargeAt === 0 && clock >= spriteStampAt) {
        spriteChargeAt = clock
        spriteCharge = Math.random() * 0.2
      }
    } else {
      spriteStampAt = Infinity
      spriteChargeAt = 0
    }
    if (spriteChargeAt > 0 && clock - spriteChargeAt >= spriteCharge * chargeTime) {
      stamp(driftX, driftY, spriteCharge)
      spriteChargeAt = 0
      spriteStampAt = clock + 2 + Math.random()
    }

    if (pings.length > 0) {
      var live = []
      for (var i = 0; i < pings.length; i++) {
        if (clock - pings[i].born < pings[i].life) live.push(pings[i])
      }
      if (live.length !== pings.length) pings = live
    }

    // A parked pool with nothing alive has nothing new to draw, so the frame
    // loop stops touching the tiles and the effect costs nothing at all. The
    // flag is only ever raised here and by pointerTo(), and only the paint
    // itself clears it, so a cursor move between frames cannot be lost.
    if (moving) needsPaint = true
  }

  /** Hand the next tile in the pool to a cell that has earned it. */
  function place(col, row, heat) {
    var tile = tiles[used]
    if (!tile) return
    tile.x = col * cell + gap
    tile.y = row * cell + gap
    tile.color = inkLut[heat > 1 ? 31 : (heat * 31 + 0.5) | 0]
    if (!tile.visible) tile.visible = true
    used++
  }

  /** Every cell a pool of light at (cx, cy) reaches. */
  function pool(cx, cy, r, amp) {
    if (amp < 0.002 || r < 1 || cell < 1) return
    var c0 = Math.max(0, Math.floor((cx - r) / cell))
    var c1 = Math.min(colMax, Math.floor((cx + r) / cell))
    var r0 = Math.max(0, Math.floor((cy - r) / cell))
    var r1 = Math.min(rowMax, Math.floor((cy + r) / cell))
    var rr = r * r
    var invIntensity = 1 / Math.max(intensity, 0.001)
    var heatScale = 0.45 + 0.55 * intensity
    var scatterMix = scatter
    var ordered = 1 - scatter

    for (var row = r0; row <= r1; row++) {
      var centreY = (row + 0.5) * cell
      for (var col = c0; col <= c1; col++) {
        var centreX = (col + 0.5) * cell
        var dx = centreX - cx
        var dy = centreY - cy
        var d2 = dx * dx + dy * dy
        if (d2 >= rr) continue
        // Squared falloff, softened toward its tail so the sparse outer rings
        // still carry a few lit tiles instead of stopping dead.
        var f = 1 - Math.sqrt(d2) / r
        var light = f * (0.5 + 0.5 * f) * amp
        var lum = light * 2.0
        if (lum <= 0.03) continue
        if (lum <= ordered * bayerRank(col, row) + scatterMix * tileNoise(col, row)) continue
        // Heat follows the shape of the pool, not its brightness, so the ink
        // ramp stays put and the intensity slider only moves how many tiles
        // light and how brightly they read.
        var heat = light * invIntensity
        if (heat > 1) heat = 1
        place(col, row, heat * heatScale)
      }
    }
  }

  /**
   * One live stamp, spread over the cells its logo pixels cover. A logo pixel
   * narrower than a cell lights only the cells whose centres fall inside it,
   * which is what makes a young stamp read as scattered specks.
   */
  function mark(x, y, stampCell, amp) {
    if (amp < 0.004 || stampCell < 0.05 || cell < 1) return
    var half = cell * 0.5
    var lum = amp * 1.5
    var scatterMix = scatter
    var ordered = 1 - scatter

    for (var ly = 0; ly < 15; ly++) {
      var line = logoRows[ly]
      for (var lx = 0; lx < 15; lx++) {
        if (line.charAt(lx) !== "1") continue
        var colFrom = Math.ceil((x + (lx - 7.5) * stampCell - half) / cell)
        var colTo = Math.ceil((x + (lx - 6.5) * stampCell - half) / cell) - 1
        var rowFrom = Math.ceil((y + (ly - 7.5) * stampCell - half) / cell)
        var rowTo = Math.ceil((y + (ly - 6.5) * stampCell - half) / cell) - 1
        for (var row = Math.max(0, rowFrom); row <= Math.min(rowMax, rowTo); row++) {
          for (var col = Math.max(0, colFrom); col <= Math.min(colMax, colTo); col++) {
            if (lum <= ordered * bayerRank(col, row) + scatterMix * tileNoise(col, row)) continue
            place(col, row, amp)
          }
        }
      }
    }
  }

  /** Light every tile this frame's light has earned. */
  function update() {
    if (tiles.length === 0) collectTiles()
    used = 0

    var amp = pointerAmp * intensity
    if (amp > 0.002) pool(pointerX, pointerY, reach, amp)

    if (drift > 0.002) {
      pool(driftX, driftY, reach * 1.1, driftAmp)
      paintedDriftAmp = driftAmp
      lastDriftPaint = clock
    }

    for (var i = 0; i < pingSlots; i++) {
      if (!pings[i]) continue
      var vec = stampVec(i)
      if (vec.amp < 0.004) continue
      mark(pings[i].x, pings[i].y, vec.cell, vec.amp)
    }

    // Tiles the light has moved off of go back in the pool.
    for (var t = used; t < shown; t++) tiles[t].visible = false
    shown = used

    needsPaint = false
  }

  /** The repeater hands out its tiles one insertion at a time, so the list is
   *  gathered on the next event loop pass, when they have all landed. */
  function collectTiles() {
    var list = []
    for (var i = 0; i < poolRepeater.count; i++) list.push(poolRepeater.itemAt(i))
    root.tiles = list
    root.shown = 0
  }

  Item {
    id: field
    anchors.fill: parent

    Repeater {
      id: poolRepeater
      model: root.tileBudget
      onCountChanged: Qt.callLater(root.collectTiles)

      Rectangle {
        id: tile
        visible: false
        width: root.tileSpan
        height: root.tileSpan
        color: "transparent"
      }
    }

    Component.onCompleted: Qt.callLater(root.collectTiles)
  }

  FrameAnimation {
    running: root.active
    onTriggered: {
      var now = Date.now()
      var dt = root.lastFrameMs > 0 ? (now - root.lastFrameMs) / 1000 : 1 / 60
      root.lastFrameMs = now
      if (dt > 0.2) dt = 0.2
      if (dt > 0) root.step(dt)
      if (root.needsPaint) root.update()
    }
  }
}
