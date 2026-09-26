// Mozax - fork of the built-in omarchy.background renderer (Omarchy 4.0.4)
// with an interactive cursor-hover tile glow, grid overlay, and optional
// mosaic pixelation on top of the wallpaper.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1

  // Mosaic effect: on, the wallpaper is drawn into a small layer texture and
  // scaled back up without smoothing, so the desktop shows retro blocks.
  property bool mosaic: true
  property int mosaicBlock: 8

  // Grid overlay drawn over the wallpaper, separating tiles like grout.
  property bool grid: true
  property int gridSize: 16        // line pitch in logical pixels (fine grid)
  property int gridGap: 1          // band width between tiles, logical pixels
  property color gridColor: "#000000"
  property real gridOpacity: 0.5

  // Interactive Cursor-Hover Glow Effect:
  // Tiles light by beat a per-tile dither threshold, so the pool under the
  // cursor arrives as a loose constellation of squares that thickens toward
  // the centre, and a click dissolves the Omarchy mark through the same
  // dither. See PixelGlow.qml for the renderer.
  property bool glow: true
  property int glowRadius: 4               // Radius of the solid core, in tiles
  property real glowIntensity: 0.7         // Peak brightness (0.0 to 1.0)
  property real glowScatter: 0.22         // Randomness of the lit tiles (0 ordered, 1 pure random)
  property bool glowDrift: true            // Ambient pool wandering the screen, blooming the mark
  property bool glowUseTheme: true         // Dynamically tracks brightened Omarchy theme accent color
  property color customGlowColor: "#ffffff"
  readonly property color brightThemeAccent: Qt.lighter(Color.accent, 1.45)
  property color glowColor: glowUseTheme ? brightThemeAccent : customGlowColor
  readonly property int glowRadiusMax: 10
  readonly property real glowDriftStrength: 0.55

  // Audio Visualizer Effect:
  // Spectrum bars or a fading tile heatmap along the bottom edge.
  property bool visualizer: true
  property string visualizerVariant: "bars"
  property real visualizerOpacity: 0.65     // Tile visualizer opacity (0.0 to 1.0)
  property int visualizerHeight: 16         // Maximum visualizer height in tiles
  property int visualizerMosaicRows: 4
  property real visualizerWidth: 0.0        // Width ratio (0.0 = default auto, 0.05 to 1.0 = fraction of screen width)
  property var visualizerValues: []
  readonly property int visualizerBarsCount: 60
  readonly property int visualizerMosaicRowsMax: 12
  readonly property string cavaConfigFile: stateHome + "/omarchy/mozax-cava.conf"

  // Persisted settings: every knob below is written back to a JSON state file,
  // so tuning survives a shell restart instead of falling back to the defaults
  // in this file. Delete the state file to return to the baked-in defaults.
  readonly property string settingsPath: stateHome + "/omarchy/mozax.json"
  property bool settingsLoaded: false

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function settingsSnapshot() {
    return {
      version: 4,
      mosaic: mosaic, mosaicBlock: mosaicBlock,
      grid: grid, gridSize: gridSize, gridGap: gridGap,
      gridColor: String(gridColor), gridOpacity: gridOpacity,
      glow: glow, glowRadius: glowRadius, glowIntensity: glowIntensity,
      glowScatter: glowScatter, glowDrift: glowDrift,
      glowUseTheme: glowUseTheme, customGlowColor: String(customGlowColor),
      visualizer: visualizer, visualizerVariant: visualizerVariant,
      visualizerOpacity: visualizerOpacity, visualizerMosaicRows: visualizerMosaicRows,
      visualizerHeight: visualizerHeight, visualizerWidth: visualizerWidth
    }
  }

  function loadSettings(raw) {
    // FileView can fire onLoaded more than once during startup; only the first
    // pass may touch the knobs, and only it flips settingsLoaded.
    if (settingsLoaded) return
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
    if (parsed && typeof parsed === "object") {
      function boolval(key, fallback) {
        return typeof parsed[key] === "boolean" ? parsed[key] : fallback
      }
      function intval(key, fallback, min) {
        var v = Number(parsed[key])
        return isFinite(v) ? Math.max(min, Math.round(v)) : fallback
      }
      function realval(key, fallback) {
        var v = Number(parsed[key])
        return isFinite(v) ? v : fallback
      }
      function unitval(key, fallback) {
        return Math.max(0, Math.min(1, realval(key, fallback)))
      }
      function colorval(key, fallback) {
        var s = String(parsed[key] || "")
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s) ? s : fallback
      }

      mosaic = boolval("mosaic", mosaic)
      mosaicBlock = intval("mosaicBlock", mosaicBlock, 2)
      grid = boolval("grid", grid)
      gridSize = intval("gridSize", gridSize, 4)
      gridGap = Math.min(intval("gridGap", gridGap, 0), gridSize - 1)
      gridColor = colorval("gridColor", gridColor)
      gridOpacity = unitval("gridOpacity", gridOpacity)
      glow = boolval("glow", glow)
      glowRadius = Math.min(glowRadiusMax, intval("glowRadius", glowRadius, 0))
      glowIntensity = unitval("glowIntensity", glowIntensity)
      glowScatter = unitval("glowScatter", glowScatter)
      glowDrift = boolval("glowDrift", glowDrift)
      glowUseTheme = boolval("glowUseTheme", glowUseTheme)
      customGlowColor = colorval("customGlowColor", customGlowColor)
      visualizer = boolval("visualizer", visualizer)
      visualizerVariant = String(parsed.visualizerVariant || "").trim().toLowerCase() === "mosaic" ? "mosaic" : "bars"
      visualizerOpacity = unitval("visualizerOpacity", visualizerOpacity)
      visualizerMosaicRows = Math.min(visualizerMosaicRowsMax, intval("visualizerMosaicRows", visualizerMosaicRows, 1))
      visualizerHeight = intval("visualizerHeight", visualizerHeight, 2)
      visualizerWidth = unitval("visualizerWidth", visualizerWidth)
      cavaProc.running = visualizer
    }
    settingsLoaded = true
  }

  function scheduleSettingsSave() {
    if (!settingsLoaded) return
    settingsSaveTimer.restart()
  }

  function flushSettings() {
    stateFileView.setText(JSON.stringify(settingsSnapshot(), null, 2) + "\n")
  }

  // Any knob change schedules a debounced write. Changes made while loading are
  // ignored: settingsLoaded is still false during loadSettings().
  onMosaicChanged: scheduleSettingsSave()
  onMosaicBlockChanged: scheduleSettingsSave()
  onGridChanged: scheduleSettingsSave()
  onGridSizeChanged: scheduleSettingsSave()
  onGridGapChanged: scheduleSettingsSave()
  onGridColorChanged: scheduleSettingsSave()
  onGridOpacityChanged: scheduleSettingsSave()
  onGlowChanged: scheduleSettingsSave()
  onGlowRadiusChanged: scheduleSettingsSave()
  onGlowIntensityChanged: scheduleSettingsSave()
  onGlowScatterChanged: scheduleSettingsSave()
  onGlowDriftChanged: scheduleSettingsSave()
  onGlowUseThemeChanged: scheduleSettingsSave()
  onCustomGlowColorChanged: scheduleSettingsSave()
  // Cava follows the knob, not just the IPC entry points: the bar widget
  // flips `visualizer` directly, and loadSettings still arms cava itself
  // while settingsLoaded is false.
  onVisualizerChanged: {
    scheduleSettingsSave()
    if (settingsLoaded) cavaProc.running = visualizer
  }
  onVisualizerVariantChanged: scheduleSettingsSave()
  onVisualizerOpacityChanged: scheduleSettingsSave()
  onVisualizerMosaicRowsChanged: scheduleSettingsSave()
  onVisualizerHeightChanged: scheduleSettingsSave()
  onVisualizerWidthChanged: scheduleSettingsSave()

  signal requestBurst(int col, int row)
  signal requestGlowHover(int x, int y)

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(pendingColorsRaw)
    Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  Process {
    id: ensureCavaConfigProc
    command: ["bash", "-c", "if [[ ! -f '" + root.cavaConfigFile + "' ]]; then mkdir -p '" + root.stateHome + "/omarchy' && cat << 'EOF' > '" + root.cavaConfigFile + "'\n[general]\nbars = 60\nframerate = 30\nautosens = 1\n\n[input]\nmethod = pulse\n\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 16\nEOF\nfi"]
    running: true
    onExited: function(exitCode) {
      if (root.visualizer) cavaProc.running = true
    }
  }

  Process {
    id: cavaProc
    command: ["cava", "-p", root.cavaConfigFile]
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var parts = line.split(";")
        var vals = []
        for (var i = 0; i < parts.length; i++) {
          var p = parts[i].trim()
          if (p.length > 0) vals.push(parseInt(p) || 0)
        }
        if (vals.length > 0) root.visualizerValues = vals
      }
    }
    onExited: function(exitCode) {
      if (root.visualizer) cavaRestartTimer.restart()
    }
  }

  Timer {
    id: cavaRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root.visualizer && !cavaProc.running) cavaProc.running = true
    }
  }

  FileView {
    id: stateFileView
    path: root.settingsPath
    atomicWrites: true
    watchChanges: false
    printErrors: false
    onLoaded: root.loadSettings(text())
    // First run: the file does not exist yet, keep the baked-in defaults.
    onLoadFailed: root.loadSettings("")
  }

  Timer {
    id: settingsSaveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushSettings()
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    // Glow effect controls
    function glowToggle(): void {
      root.glow = !root.glow
    }

    function glow(value: string): void {
      root.glow = value === "true"
    }

    function glowStatus(): string {
      return (root.glow ? "true" : "false") + " " + root.glowIntensity
        + " " + root.glowColor + " " + root.glowRadius + " " + (root.glowUseTheme ? "theme" : "custom")
    }

    function glowRadius(value: string): void {
      var n = parseInt(value)
      if (n >= 0) root.glowRadius = Math.min(n, root.glowRadiusMax)
    }

    function glowIntensity(value: string): void {
      var v = Number(value)
      if (isFinite(v)) root.glowIntensity = Math.max(0, Math.min(1, v))
    }

    function glowBrightness(value: string): void {
      glowIntensity(value)
    }

    function glowScatter(value: string): void {
      var v = Number(value)
      if (isFinite(v)) root.glowScatter = Math.max(0, Math.min(1, v))
    }

    function glowScatterStatus(): string {
      return String(root.glowScatter) + " " + (root.glowDrift ? "drift" : "still")
    }

    function glowDrift(value: string): void {
      root.glowDrift = value === "true"
    }

    function glowColor(value: string): void {
      var s = String(value || "").trim().toLowerCase()
      if (s === "theme" || s === "accent") {
        root.glowUseTheme = true
      } else if (s === "default" || s === "white" || s === "#fff" || s === "#ffffff") {
        root.glowUseTheme = false
        root.customGlowColor = "#ffffff"
      } else if (s.length > 0) {
        root.glowUseTheme = false
        root.customGlowColor = s
      }
    }

    function burst(col: string, row: string): void {
      var c = parseInt(col) || 10
      var r = parseInt(row) || 10
      root.requestBurst(c, r)
    }

    function glowHover(x: string, y: string): void {
      var px = parseInt(x) || 960
      var py = parseInt(y) || 600
      root.requestGlowHover(px, py)
    }

    // Audio visualizer controls
    function visualizerToggle(): void {
      root.visualizer = !root.visualizer
      if (root.visualizer) cavaProc.running = true
      else cavaProc.running = false
    }

    function visualizer(value: string): void {
      root.visualizer = value === "true"
      if (root.visualizer) cavaProc.running = true
      else cavaProc.running = false
    }

    function visualizerStatus(): string {
      var w = root.visualizerWidth <= 0.0 ? "default" : root.visualizerWidth.toFixed(2)
      return (root.visualizer ? "true" : "false") + " " + root.visualizerOpacity
        + " " + root.visualizerHeight + " " + w
    }

    function visualizerVariant(value: string): void {
      var variant = String(value || "").trim().toLowerCase()
      if (variant === "bars" || variant === "mosaic") root.visualizerVariant = variant
    }

    function visualizerVariantStatus(): string {
      return root.visualizerVariant
    }

    function visualizerWidth(value: string): void {
      var s = String(value || "").trim().toLowerCase()
      if (s === "default" || s === "auto" || s === "0" || s === "0.0") {
        root.visualizerWidth = 0.0
      } else if (s === "full" || s === "max" || s === "1" || s === "1.0" || s === "100%") {
        root.visualizerWidth = 1.0
      } else {
        var v = parseFloat(s)
        if (s.endsWith("%")) v = v / 100.0
        if (isFinite(v) && v > 0.0) {
          root.visualizerWidth = Math.max(0.05, Math.min(1.0, v))
        }
      }
    }
    function visualizerOpacity(value: string): void {
      var v = Number(value)
      if (isFinite(v)) root.visualizerOpacity = Math.max(0, Math.min(1, v))
    }

    function visualizerHeight(value: string): void {
      var n = parseInt(value)
      if (n >= 2) root.visualizerHeight = n
    }

    function visualizerMosaicRows(value: string): void {
      var n = parseInt(value)
      if (n >= 1) root.visualizerMosaicRows = Math.min(n, root.visualizerMosaicRowsMax)
    }

    function visualizerMosaicRowsStatus(): string {
      return String(root.visualizerMosaicRows)
    }

    // Mozax additions: mosaic toggle, block size and status.
    function mosaicToggle(): void {
      root.mosaic = !root.mosaic
    }

    function mosaic(value: string): void {
      root.mosaic = value === "true"
    }

    function mosaicStatus(): string {
      return (root.mosaic ? "true" : "false") + " " + root.mosaicBlock
    }

    function mosaicBlockSize(value: string): void {
      var n = parseInt(value)
      if (n >= 2) root.mosaicBlock = n
    }

    // Grid overlay additions.
    function gridToggle(): void {
      root.grid = !root.grid
    }

    function grid(value: string): void {
      root.grid = value === "true"
    }

    function gridStatus(): string {
      return (root.grid ? "true" : "false") + " " + root.gridSize + " " + root.gridGap
        + " " + root.gridColor + " " + root.gridOpacity
    }

    function gridSize(value: string): void {
      var n = parseInt(value)
      if (n >= 4) root.gridSize = n
    }

    function gridGap(value: string): void {
      var n = parseInt(value)
      if (n >= 0 && n < root.gridSize) root.gridGap = n
    }

    function gridOpacity(value: string): void {
      var v = Number(value)
      if (isFinite(v)) root.gridOpacity = Math.max(0, Math.min(1, v))
    }

    function gridColor(value: string): void {
      var s = String(value).trim()
      if (s.length > 0) root.gridColor = s
    }

    function set(path: string): void {
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: {
    refreshBackground()
    stateFileView.reload()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      updatesEnabled: true

      property bool maskReady: false

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Image {
        id: base
        anchors.fill: parent
        source: root.imageUrl(root.displayedBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        layer.enabled: root.mosaic
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / root.mosaicBlock)), Math.max(1, Math.round(height / root.mosaicBlock)))
        onStatusChanged: {
          if (status === Image.Ready && root.finishingTransition) {
            root.incomingBackground = ""
            root.oldBackground = ""
            root.finishingTransition = false
          }
        }
      }

      Image {
        id: oldFrame
        anchors.fill: parent
        source: root.imageUrl(root.oldBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        layer.enabled: root.mosaic
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / root.mosaicBlock)), Math.max(1, Math.round(height / root.mosaicBlock)))
        visible: root.oldBackground !== "" && root.revealProgress < 1
        onStatusChanged: panel.maybeStartReveal()
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          source: root.imageUrl(root.incomingBackground)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          layer.enabled: root.mosaic
          layer.textureSize: Qt.size(Math.max(1, Math.round(width / root.mosaicBlock)), Math.max(1, Math.round(height / root.mosaicBlock)))
          onStatusChanged: panel.maybeStartReveal()
        }
      }

      // Audio visualizer along the bottom
      Item {
        id: visualizerLayer
        anchors.fill: parent
        visible: root.visualizer && root.visualizerValues.length > 0

        readonly property int totalCols: Math.floor(panel.width / root.gridSize)
        readonly property bool customMode: root.visualizerWidth > 0.0
        readonly property int targetCols: customMode
          ? Math.max(1, Math.min(totalCols, Math.round(totalCols * root.visualizerWidth)))
          : Math.min(totalCols, root.visualizerBarsCount * Math.max(1, Math.floor(totalCols / root.visualizerBarsCount)))
        readonly property int colsPerBar: customMode ? 1 : Math.max(1, Math.floor(totalCols / root.visualizerBarsCount))
        readonly property int barCount: customMode ? targetCols : root.visualizerBarsCount
        readonly property int barSpanPixels: colsPerBar * root.gridSize
        readonly property int totalBarsCols: barCount * colsPerBar
        readonly property int startCol: Math.max(0, Math.floor((totalCols - totalBarsCols) / 2))
        readonly property int startOffset: startCol * root.gridSize
        readonly property int mosaicMaxCols: Math.max(0, Math.floor(totalCols / 2))
        readonly property int mosaicAvailableCols: Math.min(root.visualizerBarsCount, mosaicMaxCols)
        readonly property int mosaicCols: customMode
          ? Math.max(0, Math.min(mosaicAvailableCols, Math.round(mosaicAvailableCols * root.visualizerWidth)))
          : mosaicAvailableCols
        readonly property real mosaicBoardWidth: customMode ? panel.width * root.visualizerWidth : panel.width
        readonly property real mosaicCellPitch: mosaicCols > 0 ? mosaicBoardWidth / mosaicCols : 0
        readonly property int mosaicRowPitch: Math.max(root.gridSize, Math.min(32, mosaicCellPitch / 2))
        readonly property int mosaicRows: Math.max(1, Math.min(root.visualizerMosaicRows, Math.floor(panel.height / root.gridSize)))

        function sampleValue(index, count) {
          var vals = root.visualizerValues
          if (!vals || vals.length === 0) return 0
          if (count <= 1 || vals.length === 1) return vals[0] || 0
          var pos = (index / (count - 1)) * (vals.length - 1)
          var i0 = Math.floor(pos)
          var i1 = Math.min(vals.length - 1, i0 + 1)
          var f = pos - i0
          var v0 = vals[i0] || 0
          var v1 = vals[i1] || 0
          return Math.round(v0 * (1 - f) + v1 * f)
        }

        Repeater {
          model: root.visualizerVariant === "bars" ? visualizerLayer.barCount : 0

          Rectangle {
            id: vizBar
            anchors.bottom: parent.bottom

            x: visualizerLayer.startOffset + index * visualizerLayer.barSpanPixels + root.gridGap
            width: Math.max(0, visualizerLayer.barSpanPixels - root.gridGap)

            property int rawVal: visualizerLayer.customMode
              ? visualizerLayer.sampleValue(index, visualizerLayer.barCount)
              : (root.visualizerValues.length > index ? root.visualizerValues[index] : 0)
            property int tileCount: Math.min(root.visualizerHeight, rawVal)

            height: Math.max(0, tileCount * root.gridSize - root.gridGap)

            Behavior on height {
              NumberAnimation {
                duration: 65
                easing.type: Easing.OutQuad
              }
            }

            gradient: Gradient {
              GradientStop { position: 0.0; color: Color.foreground }
              GradientStop { position: 0.6; color: Color.accent }
              GradientStop { position: 1.0; color: Qt.darker(Color.accent, 1.25) }
            }
            opacity: root.visualizerOpacity
          }
        }

        Loader {
          id: mosaicLoader
          anchors.fill: parent
          active: root.visualizer && root.visualizerVariant === "mosaic"
          sourceComponent: mosaicVisualizerComponent
        }

        Component {
          id: mosaicVisualizerComponent

          MosaicVisualizer {
            anchors.fill: parent
            values: root.visualizerValues
            columns: visualizerLayer.mosaicCols
            rows: visualizerLayer.mosaicRows
            cellPitch: visualizerLayer.mosaicCellPitch
            rowPitch: visualizerLayer.mosaicRowPitch
            gridGap: root.gridGap
            visualizerOpacity: root.visualizerOpacity
            accentColor: Color.accent
            bandCount: root.visualizerBarsCount
          }
        }
      }

      // Cursor-hover tile glow: the pool dithered into scattered tiles, with
      // the click stamp of the Omarchy mark. See PixelGlow.qml.
      PixelGlow {
        id: pixelGlow
        anchors.fill: parent
        visible: root.glow
        active: root.glow

        cell: root.gridSize
        gap: root.gridGap
        radius: root.glowRadius
        intensity: root.glowIntensity
        scatter: root.glowScatter
        drift: root.glowDrift ? root.glowDriftStrength : 0

        // The theme accent, walked from a dim floor to a bright lip so a tile
        // reads as lit rather than pasted on.
        inkDim: Qt.darker(root.glowColor, 2.3)
        inkMid: Qt.darker(root.glowColor, 1.55)
        inkLit: root.glowColor
        inkHover: Qt.lighter(root.glowColor, 1.2)
        inkCrest: Qt.lighter(root.glowColor, 1.45)
      }

      // 4. Grid overlay lines drawn over the tiles
      Item {
        id: gridLayer
        anchors.fill: parent
        visible: root.grid
        opacity: root.gridOpacity

        Repeater {
          model: Math.ceil(gridLayer.width / root.gridSize)

          Rectangle {
            width: root.gridGap
            height: gridLayer.height
            x: index * root.gridSize
            color: root.gridColor
          }
        }

        Repeater {
          model: Math.ceil(gridLayer.height / root.gridSize)

          Rectangle {
            height: root.gridGap
            width: gridLayer.width
            y: index * root.gridSize
            color: root.gridColor
          }
        }
      }

      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: revealMask.centerTop - revealMask.spread; startY: 0
            PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
            PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
        function onRequestBurst(col, row) {
          pixelGlow.stamp((col + 0.5) * root.gridSize, (row + 0.5) * root.gridSize, 0.2)
        }
        function onRequestGlowHover(x, y) {
          pixelGlow.pointerTo(x, y)
        }
      }

      MouseArea {
        id: mouseTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Seconds the press has been held, read on release: a quick click
        // leaves a small mark, a long hold blooms a wide one.
        property real pressedAt: 0

        onPositionChanged: function(mouse) {
          pixelGlow.pointerTo(mouse.x, mouse.y)
        }

        onExited: {
          pixelGlow.release()
        }

        onPressed: function(mouse) {
          if (mouse.button === Qt.LeftButton) pressedAt = pixelGlow.clock
        }

        onClicked: function(mouse) {
          if (!root.glow) return
          if (mouse.button !== Qt.LeftButton) return
          var charge = (pixelGlow.clock - pressedAt) / 1.1
          pixelGlow.stamp(mouse.x, mouse.y, charge)
        }

        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}
