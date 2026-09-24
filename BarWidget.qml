import QtQuick
import QtQuick.Controls
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "rubichandrap.mozax"

  readonly property var mozax: bar?.shell?.serviceFor("rubichandrap.mozax")
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string ff: bar ? bar.fontFamily : Style.font.family

  property bool popupOpen: false
  function close() { popupOpen = false }

  function syncFields() {
    if (!mozax) return
    glowColorField.text = String(mozax.customGlowColor)
    gridColorField.text = String(mozax.gridColor)
    widthDropdown.value = visualizerWidthValue()
  }

  function visualizerWidthValue() {
    if (!mozax) return "0"
    var w = Number(mozax.visualizerWidth)
    if (!isFinite(w) || w <= 0.001) return "0"
    return String(w)
  }

  function isHex(s) {
    return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(String(s || "").trim())
  }

  onBarChanged: if (bar) syncFields()
  onPopupOpenChanged: if (popupOpen) syncFields()
  Component.onCompleted: syncFields()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  component SliderControl: Column {
    id: sc

    property QtObject barRef: null
    property string label: ""
    property string valueText: ""
    property real boundValue: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    signal applied(real v)

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(4)

    Item {
      width: parent.width
      height: Math.max(sliderLabel.implicitHeight, sliderValue.implicitHeight)

      Text {
        id: sliderLabel
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: sc.label
        color: sc.barRef ? sc.barRef.foreground : Color.foreground
        font.family: sc.barRef ? sc.barRef.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        id: sliderValue
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: sc.valueText
        color: Qt.darker(sc.barRef ? sc.barRef.foreground : Color.foreground, 1.4)
        font.family: sc.barRef ? sc.barRef.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    PanelSlider {
      bar: sc.barRef
      width: parent.width
      value: sc.boundValue
      minimum: sc.minimum
      maximum: sc.maximum
      step: sc.step
      integer: sc.integer
      onMoved: function(v) { sc.applied(v) }
      onReleased: function(v) { sc.applied(v) }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰉩"
    tooltipText: "Mozax"
    onPressed: function(pressedButton) {
      if (pressedButton === Qt.RightButton) return
      root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(520))

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      // Always keep a right gutter so the overlay scrollbar never sits on
      // inputs/labels (attached ScrollBar paints over full-width content).
      // Handle uses the theme foreground for contrast on the dark popup.
      ScrollBar.vertical: ScrollBar {
        id: vBar
        policy: ScrollBar.AsNeeded
        width: Style.space(8)

        background: Item {}

        contentItem: Rectangle {
          implicitWidth: Style.space(6)
          radius: width / 2
          color: root.fg
          opacity: vBar.pressed ? 1.0 : (vBar.hovered ? 0.85 : 0.5)
        }
      }

      Column {
        id: column
        width: flick.width - Style.space(16)
        spacing: Style.space(8)
        opacity: root.mozax ? 1.0 : 0.45
        enabled: !!root.mozax

        // ---------- Glow ----------
        PanelSectionHeader {
          text: "GLOW"
          foreground: root.fg
          fontFamily: root.ff
        }

        Toggle {
          width: parent.width
          label: "Tile glow"
          description: "Cursor spotlight and click burst"
          checked: root.mozax ? root.mozax.glow : false
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.glow = !root.mozax.glow
        }

        SliderControl {
          visible: root.mozax && root.mozax.glow
          barRef: root.bar
          label: "Radius"
          valueText: (root.mozax ? root.mozax.glowRadius : 3) + " tiles"
          boundValue: root.mozax ? root.mozax.glowRadius : 3
          minimum: 0
          maximum: 10
          step: 1
          integer: true
          onApplied: function(v) { if (root.mozax) root.mozax.glowRadius = Math.round(v) }
        }

        SliderControl {
          visible: root.mozax && root.mozax.glow
          barRef: root.bar
          label: "Intensity"
          valueText: Math.round((root.mozax ? root.mozax.glowIntensity : 0.45) * 100) + "%"
          boundValue: root.mozax ? root.mozax.glowIntensity : 0.45
          minimum: 0
          maximum: 1
          step: 0.05
          onApplied: function(v) { if (root.mozax) root.mozax.glowIntensity = Math.max(0, Math.min(1, v)) }
        }

        SliderControl {
          visible: root.mozax && root.mozax.glow
          barRef: root.bar
          label: "Trail fade"
          valueText: (root.mozax ? root.mozax.glowDuration : 400) + " ms"
          boundValue: root.mozax ? root.mozax.glowDuration : 400
          minimum: 0
          maximum: 1500
          step: 50
          integer: true
          onApplied: function(v) { if (root.mozax) root.mozax.glowDuration = Math.max(0, Math.round(v)) }
        }

        Toggle {
          visible: root.mozax && root.mozax.glow
          width: parent.width
          label: "Smooth trail"
          description: "Fading wake instead of instant follow"
          checked: root.mozax ? root.mozax.glowTrail : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.glowTrail = !root.mozax.glowTrail
        }

        Toggle {
          visible: root.mozax && root.mozax.glow
          width: parent.width
          label: "Tile border"
          description: "Subtle outline on lit tiles"
          checked: root.mozax ? root.mozax.glowBorder : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.glowBorder = !root.mozax.glowBorder
        }

        Toggle {
          visible: root.mozax && root.mozax.glow
          width: parent.width
          label: "Theme accent"
          description: "Use brightened theme color"
          checked: root.mozax ? root.mozax.glowUseTheme : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: {
            if (!root.mozax) return
            root.mozax.glowUseTheme = !root.mozax.glowUseTheme
            root.syncFields()
          }
        }

        Item {
          visible: root.mozax && root.mozax.glow && !root.mozax.glowUseTheme
          width: parent.width
          height: glowColorCol.visible ? glowColorCol.implicitHeight : 0

          Column {
            id: glowColorCol
            visible: parent.height > 0
            width: parent.width
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText
              text: "Custom glow color"
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }

            TextField {
              id: glowColorField
              width: parent.width
              text: root.mozax ? String(root.mozax.customGlowColor) : "#ffffff"
              placeholderText: "#ffffff"
              foreground: root.fg
              onEditingFinished: {
                if (!root.mozax) return
                if (root.isHex(text)) root.mozax.customGlowColor = text.trim()
                else text = String(root.mozax.customGlowColor)
              }
            }
          }
        }

        // ---------- Grid ----------
        PanelSeparator {
          foreground: root.fg
        }

        PanelSectionHeader {
          text: "GRID"
          foreground: root.fg
          fontFamily: root.ff
        }

        Toggle {
          width: parent.width
          label: "Grid overlay"
          description: "Grout lines over the wallpaper"
          checked: root.mozax ? root.mozax.grid : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.grid = !root.mozax.grid
        }

        SliderControl {
          visible: root.mozax && root.mozax.grid
          barRef: root.bar
          label: "Line pitch"
          valueText: (root.mozax ? root.mozax.gridSize : 16) + " px"
          boundValue: root.mozax ? root.mozax.gridSize : 16
          minimum: 4
          maximum: 64
          step: 1
          integer: true
          onApplied: function(v) {
            if (!root.mozax) return
            root.mozax.gridSize = Math.max(4, Math.round(v))
            if (root.mozax.gridGap >= root.mozax.gridSize)
              root.mozax.gridGap = Math.max(0, root.mozax.gridSize - 1)
          }
        }

        SliderControl {
          visible: root.mozax && root.mozax.grid
          barRef: root.bar
          label: "Line width"
          valueText: (root.mozax ? root.mozax.gridGap : 1) + " px"
          boundValue: root.mozax ? root.mozax.gridGap : 1
          minimum: 0
          maximum: Math.max(0, (root.mozax ? root.mozax.gridSize : 16) - 1)
          step: 1
          integer: true
          onApplied: function(v) { if (root.mozax) root.mozax.gridGap = Math.round(v) }
        }

        SliderControl {
          visible: root.mozax && root.mozax.grid
          barRef: root.bar
          label: "Opacity"
          valueText: Math.round((root.mozax ? root.mozax.gridOpacity : 0.5) * 100) + "%"
          boundValue: root.mozax ? root.mozax.gridOpacity : 0.5
          minimum: 0
          maximum: 1
          step: 0.05
          onApplied: function(v) { if (root.mozax) root.mozax.gridOpacity = Math.max(0, Math.min(1, v)) }
        }

        Item {
          visible: root.mozax && root.mozax.grid
          width: parent.width
          height: gridColorCol.visible ? gridColorCol.implicitHeight : 0

          Column {
            id: gridColorCol
            visible: parent.height > 0
            width: parent.width
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText
              text: "Line color"
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }

            TextField {
              id: gridColorField
              width: parent.width
              text: root.mozax ? String(root.mozax.gridColor) : "#000000"
              placeholderText: "#000000"
              foreground: root.fg
              onEditingFinished: {
                if (!root.mozax) return
                if (root.isHex(text)) root.mozax.gridColor = text.trim()
                else text = String(root.mozax.gridColor)
              }
            }
          }
        }

        // ---------- Mosaic ----------
        PanelSeparator {
          foreground: root.fg
        }

        PanelSectionHeader {
          text: "MOSAIC"
          foreground: root.fg
          fontFamily: root.ff
        }

        Toggle {
          width: parent.width
          label: "Pixelation"
          description: "Retro blocky wallpaper"
          checked: root.mozax ? root.mozax.mosaic : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.mosaic = !root.mozax.mosaic
        }

        SliderControl {
          visible: root.mozax && root.mozax.mosaic
          barRef: root.bar
          label: "Block size"
          valueText: (root.mozax ? root.mozax.mosaicBlock : 8) + " px"
          boundValue: root.mozax ? root.mozax.mosaicBlock : 8
          minimum: 2
          maximum: 32
          step: 1
          integer: true
          onApplied: function(v) { if (root.mozax) root.mozax.mosaicBlock = Math.max(2, Math.round(v)) }
        }

        // ---------- Visualizer ----------
        PanelSeparator {
          foreground: root.fg
        }

        PanelSectionHeader {
          text: "VISUALIZER"
          foreground: root.fg
          fontFamily: root.ff
        }

        Toggle {
          width: parent.width
          label: "Audio tiles"
          description: "Spectrum bars along the bottom"
          checked: root.mozax ? root.mozax.visualizer : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.visualizer = !root.mozax.visualizer
        }

        SliderControl {
          visible: root.mozax && root.mozax.visualizer
          barRef: root.bar
          label: "Opacity"
          valueText: Math.round((root.mozax ? root.mozax.visualizerOpacity : 0.65) * 100) + "%"
          boundValue: root.mozax ? root.mozax.visualizerOpacity : 0.65
          minimum: 0
          maximum: 1
          step: 0.05
          onApplied: function(v) { if (root.mozax) root.mozax.visualizerOpacity = Math.max(0, Math.min(1, v)) }
        }

        SliderControl {
          visible: root.mozax && root.mozax.visualizer
          barRef: root.bar
          label: "Max height"
          valueText: (root.mozax ? root.mozax.visualizerHeight : 16) + " tiles"
          boundValue: root.mozax ? root.mozax.visualizerHeight : 16
          minimum: 2
          maximum: 32
          step: 1
          integer: true
          onApplied: function(v) { if (root.mozax) root.mozax.visualizerHeight = Math.max(2, Math.round(v)) }
        }

        Dropdown {
          id: widthDropdown
          visible: root.mozax && root.mozax.visualizer
          width: parent.width
          label: "Width"
          showLabel: true
          value: root.visualizerWidthValue()
          options: [
            { value: "0", label: "Default" },
            { value: "1", label: "Full" },
            { value: "0.75", label: "75%" },
            { value: "0.5", label: "50%" },
            { value: "0.25", label: "25%" }
          ]
          onChanged: function(v) { if (root.mozax) root.mozax.visualizerWidth = Number(v) }
        }
      }
    }
  }
}
