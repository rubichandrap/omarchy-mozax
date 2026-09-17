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
  property bool mosaic: false
  property int mosaicBlock: 8

  // Grid overlay drawn over the wallpaper, separating tiles like grout.
  property bool grid: true
  property int gridSize: 16        // line pitch in logical pixels (fine grid)
  property int gridGap: 1          // band width between tiles, logical pixels
  property color gridColor: "#000000"
  property real gridOpacity: 1.0

  // Interactive Cursor-Hover Glow Effect:
  // Tiles around the cursor shine with a radial falloff: the closer to the
  // cursor, the brighter the tile illuminates.
  property bool glow: true
  property int glowRadius: 2               // Radius in tiles around cursor (0 = single tile)
  property real glowIntensity: 0.40        // Peak shine brightness (0.0 to 1.0)
  property int glowDuration: 400           // Fade-out duration in milliseconds
  property bool glowTrail: true            // Smooth fading trail vs instant follow
  property color glowColor: "#ffffff"      // Shine overlay color (illuminates wallpaper)
  property bool glowBorder: true           // Subtle border highlight around glowing tiles
  property color glowBorderColor: "#ffffff"
  function imageUrl(path) {
    return Util.fileUrl(path)
  }

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
        + " " + root.glowDuration + " " + (root.glowTrail ? "true" : "false")
        + " " + root.glowColor + " " + root.glowRadius
    }

    function glowRadius(value: string): void {
      var n = parseInt(value)
      if (n >= 0) root.glowRadius = n
    }

    function glowIntensity(value: string): void {
      var v = Number(value)
      if (isFinite(v)) root.glowIntensity = Math.max(0, Math.min(1, v))
    }

    function glowBrightness(value: string): void {
      glowIntensity(value)
    }

    function glowDuration(value: string): void {
      var n = parseInt(value)
      if (n >= 0) root.glowDuration = n
    }

    function glowTrail(value: string): void {
      root.glowTrail = value === "true"
    }

    function glowColor(value: string): void {
      var s = String(value).trim()
      if (s.length > 0) root.glowColor = s
    }

    function glowBorder(value: string): void {
      root.glowBorder = value === "true"
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

  Component.onCompleted: refreshBackground()

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

      // Cursor-hover tile glow layer
      Item {
        id: glowLayer
        anchors.fill: parent
        visible: root.glow

        property var activeTiles: ({})
        readonly property int poolSize: 128

        Repeater {
          id: glowPool
          model: glowLayer.poolSize

          Rectangle {
            id: glowTile
            property string tileKey: ""

            width: Math.max(0, root.gridSize - root.gridGap)
            height: Math.max(0, root.gridSize - root.gridGap)
            color: root.glowColor
            opacity: 0.0

            border.width: root.glowBorder ? 1 : 0
            border.color: root.glowBorderColor

            NumberAnimation {
              id: tileFadeAnim
              target: glowTile
              property: "opacity"
              duration: root.glowDuration
              easing.type: Easing.OutQuad
              onFinished: {
                if (glowTile.tileKey && glowLayer.activeTiles[glowTile.tileKey] === glowTile) {
                  delete glowLayer.activeTiles[glowTile.tileKey]
                }
                glowTile.tileKey = ""
              }
            }

            function activate(tx, ty, targetOpacity, instant) {
              x = tx
              y = ty
              tileFadeAnim.stop()
              if (instant) {
                opacity = targetOpacity
              } else {
                tileFadeAnim.from = targetOpacity
                tileFadeAnim.to = 0.0
                tileFadeAnim.restart()
              }
            }

            function deactivate() {
              tileFadeAnim.stop()
              opacity = 0.0
              if (tileKey && glowLayer.activeTiles[tileKey] === glowTile) {
                delete glowLayer.activeTiles[tileKey]
              }
              tileKey = ""
            }
          }
        }
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
      }

      // Glow controller manages pool cycling and radial tile mapping
      Item {
        id: glowController

        property int poolIndex: 0

        function reset() {
          for (var i = 0; i < glowLayer.poolSize; i++) {
            var t = glowPool.itemAt(i)
            if (t) t.deactivate()
          }
          glowLayer.activeTiles = ({})
        }

        function triggerTile(col, row, targetOpacity, instant) {
          var tx = col * root.gridSize + root.gridGap
          var ty = row * root.gridSize + root.gridGap
          var key = col + "_" + row

          var delegate = glowLayer.activeTiles[key]
          if (delegate) {
            delegate.activate(tx, ty, targetOpacity, instant)
          } else {
            delegate = glowPool.itemAt(poolIndex)
            if (delegate) {
              if (delegate.tileKey && glowLayer.activeTiles[delegate.tileKey] === delegate) {
                delete glowLayer.activeTiles[delegate.tileKey]
              }
              delegate.tileKey = key
              glowLayer.activeTiles[key] = delegate
              delegate.activate(tx, ty, targetOpacity, instant)
              poolIndex = (poolIndex + 1) % glowLayer.poolSize
            }
          }
        }

        function onPointerMoved(mx, my) {
          if (!root.glow) return

          if (!root.glowTrail) {
            reset()
          }

          var centerCol = Math.floor(mx / root.gridSize)
          var centerRow = Math.floor(my / root.gridSize)
          var r = Math.max(0, root.glowRadius)

          if (r === 0) {
            if (centerCol >= 0 && centerRow >= 0) {
              triggerTile(centerCol, centerRow, root.glowIntensity, !root.glowTrail)
            }
            return
          }

          var maxDist = (r + 0.5) * root.gridSize

          for (var dc = -r; dc <= r; dc++) {
            for (var dr = -r; dr <= r; dr++) {
              var c = centerCol + dc
              var rw = centerRow + dr
              if (c < 0 || rw < 0) continue

              var tileCenterX = c * root.gridSize + root.gridSize / 2
              var tileCenterY = rw * root.gridSize + root.gridSize / 2

              var dist = Math.hypot(mx - tileCenterX, my - tileCenterY)
              if (dist > maxDist) continue

              var norm = dist / maxDist
              var falloff = Math.cos(norm * (Math.PI / 2))
              var targetOpacity = root.glowIntensity * falloff

              if (targetOpacity < 0.02) continue

              triggerTile(c, rw, targetOpacity, !root.glowTrail)
            }
          }
        }
      }

      MouseArea {
        id: mouseTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: function(mouse) {
          glowController.onPointerMoved(mouse.x, mouse.y)
        }

        onExited: {
          glowController.reset()
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
