import QtQuick
import QtQuick.Controls
import QtQuick.Window
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

  function visualizerVariantValue() {
    if (!mozax) return "bars"
    return mozax.visualizerVariant === "mosaic" ? "mosaic" : "bars"
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

  component WindowDropdown: Item {
    id: dd

    property string label: ""
    property string value: ""
    property var options: []
    property color foreground: Color.popups.text
    property color background: Color.popups.background
    property color popupBorder: Color.popups.border
    property color accent: Color.accent
    property string fontFamily: Style.font.family
    property int rowHeight: Style.spacing.controlHeight
    property int popupRowHeight: Style.spacing.popupRowHeight
    property bool showLabel: true
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)

    signal changed(string value)

    function syncSelection() {
      if (popup.opened) optionList.currentIndex = Math.max(0, optionList.indexOfValue(value))
    }

    onValueChanged: Qt.callLater(syncSelection)

    function optionValue(o) {
      return (o && typeof o === "object") ? String(o.value) : String(o)
    }

    function optionLabel(o) {
      return (o && typeof o === "object") ? String(o.label) : String(o)
    }

    function currentLabel() {
      for (var i = 0; i < options.length; i++) {
        if (optionValue(options[i]) === value) return optionLabel(options[i])
      }
      return value
    }

    implicitWidth: Style.spacing.dropdownWidth
    implicitHeight: showLabel && label !== "" ? rowHeight + Style.spacing.huge : rowHeight

    Column {
      anchors.fill: parent
      spacing: Style.spacing.labelGap

      Text {
        textFormat: Text.PlainText
        visible: dd.showLabel && dd.label !== ""
        text: dd.label
        color: Qt.darker(dd.foreground, 1.4)
        font.family: dd.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      BorderSurface {
        id: trigger
        width: parent.width
        height: dd.rowHeight
        radius: Style.cornerRadius

        readonly property bool _focused: trigger.activeFocus
        readonly property bool _hot: triggerHover.hovered
        readonly property var _borderSpec: Border.controlSpec(trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"), dd.foreground, dd.accent)

        color: Style.controlFill(trigger._focused, trigger._hot, dd.foreground, dd.accent)
        borderSpec: _borderSpec
        activeFocusOnTab: true

        HoverHandler {
          id: triggerHover
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
              || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            popup.opened ? popup.close() : popup.open()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape && popup.opened) {
            popup.close()
            event.accepted = true
          }
        }

        Text {
          anchors.left: parent.left
          anchors.right: chevron.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
          anchors.rightMargin: trigger.borderRight + Style.spacing.md
          text: dd.currentLabel()
          color: dd.foreground
          font.family: dd.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          id: chevron
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
          text: "󰅀"
          color: Qt.darker(dd.foreground, 1.2)
          font.family: dd.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            trigger.forceActiveFocus()
            popup.opened ? popup.close() : popup.open()
          }
        }

        Popup {
          id: popup
          parent: trigger.Window.window ? trigger.Window.window.contentItem : trigger
          property real _anchorX: 0
          property real _anchorY: 0

          function reposition() {
            if (!parent) return
            var p = trigger.mapToItem(parent, 0, trigger.height + Style.spacing.xxs)
            var below = parent.height - p.y
            var above = p.y - Style.spacing.xxs
            _anchorX = Math.max(Style.space(8), Math.min(p.x, parent.width - width - Style.space(8)))
            _anchorY = below >= implicitHeight
              ? p.y
              : Math.max(Style.space(8), above >= implicitHeight ? above - implicitHeight : above)
          }

          x: _anchorX
          y: _anchorY
          width: trigger.width
          implicitHeight: Math.min(dd.options.length * dd.popupRowHeight + Math.max(0, dd.options.length - 1) * Style.spacing.labelGap + Style.spacing.xxs,
                                   dd.popupRowHeight * 8 + 7 * Style.spacing.labelGap + Style.spacing.xxs)
          padding: Style.spacing.hairline
          leftPadding: Border.left(dd.popupBorderSpec) + Style.spacing.hairline
          rightPadding: Border.right(dd.popupBorderSpec) + Style.spacing.hairline
          topPadding: Border.top(dd.popupBorderSpec) + Style.spacing.hairline
          bottomPadding: Border.bottom(dd.popupBorderSpec) + Style.spacing.hairline
          focus: true

          onOpened: {
            reposition()
            dd.syncSelection()
            optionList.forceActiveFocus()
          }

          Connections {
            target: trigger
            function onXChanged() { popup.reposition() }
            function onYChanged() { popup.reposition() }
            function onWidthChanged() { popup.reposition() }
            function onHeightChanged() { popup.reposition() }
          }

          background: BorderSurface {
            color: dd.background
            borderSpec: dd.popupBorderSpec
            radius: Style.cornerRadius
          }

          contentItem: ListView {
            id: optionList
            spacing: Style.spacing.labelGap
            implicitHeight: contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: dd.options
            currentIndex: -1

            function indexOfValue(v) {
              for (var i = 0; i < dd.options.length; i++) {
                if (dd.optionValue(dd.options[i]) === v) return i
              }
              return -1
            }

            function selectCurrent() {
              if (currentIndex < 0 || currentIndex >= dd.options.length) return
              var v = dd.optionValue(dd.options[currentIndex])
              dd.changed(v)
              popup.close()
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                popup.close()
                event.accepted = true
              } else if (event.key === Qt.Key_Down || event.text === "j") {
                optionList.currentIndex = Math.min(dd.options.length - 1, optionList.currentIndex + 1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || event.text === "k") {
                optionList.currentIndex = Math.max(0, optionList.currentIndex - 1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                optionList.selectCurrent()
                event.accepted = true
              }
            }

            delegate: Rectangle {
              required property var modelData
              required property int index
              width: optionList.width
              height: dd.popupRowHeight
              color: index === optionList.currentIndex
                ? Style.hoverFillFor(dd.foreground, dd.accent)
                : "transparent"

              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.controlPaddingX
                anchors.rightMargin: Style.spacing.controlPaddingX
                text: dd.optionLabel(modelData)
                color: index === optionList.currentIndex ? Style.hoverStateColor(dd.foreground, dd.accent) : dd.foreground
                font.family: dd.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: optionList.currentIndex = index
                onClicked: {
                  optionList.currentIndex = index
                  optionList.selectCurrent()
                }
              }
            }
          }
        }
      }
    }
  }

  component ColorPicker: Column {
    id: cp

    property string label: ""
    property string value: "#000000"
    property color foreground: Color.foreground
    property color accent: Color.accent
    property string fontFamily: Style.font.family
    property bool hasCursor: false

    signal applied(string hex)

    readonly property color previewColor: isHex(value) ? value : "#000000"
    readonly property real triggerHeight: Style.spacing.controlHeight

    property real hue: 0
    property real sat: 0
    property real val: 1
    property bool _loading: false

    width: parent ? parent.width : implicitWidth
    spacing: Style.spacing.labelGap

    function isHex(s) {
      return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(String(s || "").trim())
    }

    function normalizeHex(s) {
      var t = String(s || "").trim()
      if (t.charAt(0) !== "#") t = "#" + t
      if (t.length === 4) t = "#" + t[1] + t[1] + t[2] + t[2] + t[3] + t[3]
      return t
    }

    function rgbToHex(r, g, b) {
      function ch(n) {
        var v = Math.round(Math.max(0, Math.min(1, n)) * 255)
        return (v < 16 ? "0" : "") + v.toString(16)
      }
      return ("#" + ch(r) + ch(g) + ch(b)).toLowerCase()
    }

    function hexToRgb(hex) {
      var h = normalizeHex(hex).slice(1, 7)
      return {
        r: parseInt(h.substr(0, 2), 16) / 255,
        g: parseInt(h.substr(2, 2), 16) / 255,
        b: parseInt(h.substr(4, 2), 16) / 255
      }
    }

    function hsvToRgb(h, s, v) {
      h = ((h % 360) + 360) % 360
      var c = v * s
      var x = c * (1 - Math.abs((h / 60) % 2 - 1))
      var m = v - c
      var r = 0, g = 0, b = 0
      if (h < 60) { r = c; g = x }
      else if (h < 120) { r = x; g = c }
      else if (h < 180) { g = c; b = x }
      else if (h < 240) { g = x; b = c }
      else if (h < 300) { r = x; b = c }
      else { r = c; b = x }
      return { r: r + m, g: g + m, b: b + m }
    }

    function rgbToHsv(r, g, b) {
      var max = Math.max(r, g, b)
      var min = Math.min(r, g, b)
      var d = max - min
      var h = 0
      if (d > 0) {
        if (max === r) h = 60 * (((g - b) / d) % 6)
        else if (max === g) h = 60 * ((b - r) / d + 2)
        else h = 60 * ((r - g) / d + 4)
      }
      if (h < 0) h += 360
      return { h: h, s: max === 0 ? 0 : d / max, v: max }
    }

    function hsvToHex(h, s, v) {
      var c = hsvToRgb(h, s, v)
      return rgbToHex(c.r, c.g, c.b)
    }

    function loadFromValue(hex) {
      if (!isHex(hex)) return
      _loading = true
      var rgb = hexToRgb(hex)
      var hsv = rgbToHsv(rgb.r, rgb.g, rgb.b)
      hue = hsv.h
      sat = hsv.s
      val = hsv.v
      hexField.text = normalizeHex(hex).toLowerCase()
      _loading = false
      svCanvas.requestPaint()
    }

    function commit(h, s, v) {
      if (_loading) return
      hue = h
      sat = s
      val = v
      var hex = hsvToHex(h, s, v)
      hexField.text = hex
      applied(hex)
      svCanvas.requestPaint()
    }

    onValueChanged: loadFromValue(value)
    Component.onCompleted: loadFromValue(value)

    readonly property var presets: [
      { value: "#000000", label: "Black" },
      { value: "#ffffff", label: "White" },
      { value: Color.foreground, label: "Foreground" },
      { value: Color.background, label: "Background" },
      { value: Color.accent, label: "Accent" },
      { value: Color.muted, label: "Muted" },
      { value: Color.urgent, label: "Urgent" },
      { value: "#f38ba8", label: "Red" },
      { value: "#fab387", label: "Peach" },
      { value: "#f9e2af", label: "Yellow" },
      { value: "#a6e3a1", label: "Green" },
      { value: "#94e2d5", label: "Teal" },
      { value: "#89b4fa", label: "Blue" },
      { value: "#cba6f7", label: "Mauve" },
      { value: "#f5c2e7", label: "Pink" },
      { value: "#585b70", label: "Surface" }
    ]

    Text {
      textFormat: Text.PlainText
      visible: cp.label !== ""
      text: cp.label
      color: Qt.darker(cp.foreground, 1.4)
      font.family: cp.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Row {
      id: triggerRow
      width: parent.width
      height: cp.triggerHeight
      spacing: Style.spacing.controlGap

      BorderSurface {
        id: swatch
        width: cp.triggerHeight
        height: cp.triggerHeight
        radius: Style.cornerRadius
        color: cp.previewColor
        borderSpec: Border.controlSpec(
          swatchHover.hovered || swatchMouse.containsMouse || cp.hasCursor ? "hover-cursor" : "normal",
          cp.foreground, cp.accent)

        HoverHandler { id: swatchHover }
        MouseArea {
          id: swatchMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            loadFromValue(cp.value)
            pickerPopup.open()
          }
        }
      }

      TextField {
        id: hexField
        width: parent.width - swatch.width - parent.spacing
        height: cp.triggerHeight
        text: cp.isHex(cp.value) ? cp.normalizeHex(cp.value).toLowerCase() : "#000000"
        placeholderText: "#000000"
        foreground: cp.foreground
        validator: RegularExpressionValidator {
          regularExpression: /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/
        }
        onEditingFinished: {
          if (!cp.isHex(text) && !cp.isHex("#" + text)) {
            text = cp.isHex(cp.value) ? cp.normalizeHex(cp.value).toLowerCase() : "#000000"
            return
          }
          var hex = cp.normalizeHex(text).toLowerCase()
          text = hex
          var rgb = cp.hexToRgb(hex)
          var hsv = cp.rgbToHsv(rgb.r, rgb.g, rgb.b)
          cp._loading = true
          cp.hue = hsv.h
          cp.sat = hsv.s
          cp.val = hsv.v
          cp._loading = false
          cp.applied(hex)
          svCanvas.requestPaint()
        }
      }
    }

    Popup {
      id: pickerPopup
      // Reparent to the window so the Flickable clip can't cut the popup.
      parent: triggerRow.Window.window ? triggerRow.Window.window.contentItem : triggerRow
      property real _anchorX: 0
      property real _anchorY: 0

      function reposition() {
        if (!parent) return
        var p = triggerRow.mapToItem(parent, 0, triggerRow.height + Style.spacing.xxs)
        _anchorX = Math.max(Style.space(8), Math.min(p.x, parent.width - width - Style.space(8)))
        _anchorY = Math.max(Style.space(8), Math.min(p.y, parent.height - height - Style.space(8)))
      }

      x: _anchorX
      y: _anchorY
      width: triggerRow.width
      padding: Style.spacing.hairline
      leftPadding: Border.left(cp.popupBorderSpec) + Style.spacing.lg
      rightPadding: Border.right(cp.popupBorderSpec) + Style.spacing.lg
      topPadding: Border.top(cp.popupBorderSpec) + Style.spacing.lg
      bottomPadding: Border.bottom(cp.popupBorderSpec) + Style.spacing.lg
      focus: true

      readonly property var popupBorderSpec: Border.localOrSurfaceSpec(
        "popups", "border", Color.popups.border, Color.popups.border, Math.max(1, Style.normalBorderWidth))

      Connections {
        target: triggerRow
        function onXChanged() { pickerPopup.reposition() }
        function onYChanged() { pickerPopup.reposition() }
        function onWidthChanged() { pickerPopup.reposition() }
        function onHeightChanged() { pickerPopup.reposition() }
      }

      background: BorderSurface {
        color: Color.popups.background
        borderSpec: pickerPopup.popupBorderSpec
        radius: Style.cornerRadius
      }

      onOpened: {
        reposition()
        loadFromValue(cp.value)
      }

      contentItem: Column {
        spacing: Style.spacing.sm
        width: pickerPopup.width - pickerPopup.leftPadding - pickerPopup.rightPadding

        Item {
          width: parent.width
          height: Style.space(28)

          BorderSurface {
            id: previewSwatch
            anchors.left: parent.left
            anchors.right: previewHex.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Style.spacing.controlGap
            height: Style.space(24)
            radius: Style.cornerRadius
            color: cp.hsvToHex(cp.hue, cp.sat, cp.val)
            borderSpec: Border.controlSpec("normal", cp.foreground, cp.accent)
          }

          Text {
            id: previewHex
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: cp.hsvToHex(cp.hue, cp.sat, cp.val)
            color: cp.foreground
            font.family: cp.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }

        Canvas {
          id: svCanvas
          width: parent.width
          height: Style.space(84)
          onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            ctx.clearRect(0, 0, w, h)
            var pure = cp.hsvToRgb(cp.hue, 1, 1)
            ctx.fillStyle = cp.rgbToHex(pure.r, pure.g, pure.b)
            ctx.fillRect(0, 0, w, h)
            var gw = ctx.createLinearGradient(0, 0, w, 0)
            gw.addColorStop(0, "rgba(255,255,255,1)")
            gw.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = gw
            ctx.fillRect(0, 0, w, h)
            var gh = ctx.createLinearGradient(0, 0, 0, h)
            gh.addColorStop(0, "rgba(0,0,0,0)")
            gh.addColorStop(1, "rgba(0,0,0,1)")
            ctx.fillStyle = gh
            ctx.fillRect(0, 0, w, h)
          }

          BorderSurface {
            anchors.fill: parent
            color: "transparent"
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec("normal", cp.foreground, cp.accent)
          }

          Rectangle {
            id: svKnob
            width: Style.space(10)
            height: Style.space(10)
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, Style.space(1.5))
            border.color: cp.val > 0.55 ? "#000000" : "#ffffff"
            x: Math.max(0, Math.min(parent.width - width, cp.sat * parent.width - width / 2))
            y: Math.max(0, Math.min(parent.height - height, (1 - cp.val) * parent.height - height / 2))
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) {
              var s = Math.max(0, Math.min(1, mouse.x / width))
              var v = Math.max(0, Math.min(1, 1 - mouse.y / height))
              cp.commit(cp.hue, s, v)
            }
            onPositionChanged: function(mouse) {
              if (!pressed) return
              var s = Math.max(0, Math.min(1, mouse.x / width))
              var v = Math.max(0, Math.min(1, 1 - mouse.y / height))
              cp.commit(cp.hue, s, v)
            }
            onWheel: function(wheel) {
              var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
              var v = Math.max(0, Math.min(1, cp.val + step))
              cp.commit(cp.hue, cp.sat, v)
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.xs

          Text {
            textFormat: Text.PlainText
            text: "Hue"
            color: Qt.darker(cp.foreground, 1.4)
            font.family: cp.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Item {
            id: hueTrack
            width: parent.width
            height: Style.space(14)

            Rectangle {
              anchors.fill: parent
              radius: height / 2
              gradient: Gradient {
                GradientStop { position: 0.0; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.50; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.0; color: "#ff0000" }
              }
            }

            BorderSurface {
              anchors.fill: parent
              color: "transparent"
              radius: height / 2
              borderSpec: Border.controlSpec("normal", cp.foreground, cp.accent)
            }

            BorderSurface {
              id: hueKnob
              width: Style.space(10)
              height: Style.space(10)
              radius: width / 2
              color: cp.hsvToHex(cp.hue, cp.sat > 0.05 ? cp.sat : 1, cp.val > 0.05 ? cp.val : 1)
              borderSpec: Border.flat(cp.val > 0.55 ? "#000000" : "#ffffff", Math.max(2, Style.space(1.5)))
              x: Math.max(0, Math.min(parent.width - width, (cp.hue / 360) * parent.width - width / 2))
              anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPressed: function(mouse) {
                var h = Math.max(0, Math.min(359, (mouse.x / width) * 360))
                cp.commit(h, cp.sat, cp.val)
              }
              onPositionChanged: function(mouse) {
                if (!pressed) return
                var h = Math.max(0, Math.min(359, (mouse.x / width) * 360))
                cp.commit(h, cp.sat, cp.val)
              }
              onWheel: function(wheel) {
                var step = wheel.angleDelta.y > 0 ? 5 : -5
                var h = ((cp.hue + step) % 360 + 360) % 360
                cp.commit(h, cp.sat, cp.val)
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.xs

          Text {
            textFormat: Text.PlainText
            text: "Presets"
            color: Qt.darker(cp.foreground, 1.4)
            font.family: cp.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Grid {
            id: presetGrid
            width: parent.width
            columns: 8
            spacing: Style.spacing.xxs

            Repeater {
              model: cp.presets

              delegate: Rectangle {
                required property var modelData
                readonly property bool selected:
                  cp.isHex(cp.value)
                  && cp.normalizeHex(cp.value).toLowerCase() === cp.normalizeHex(modelData.value).toLowerCase()

                width: Style.space(18)
                height: Style.space(18)
                radius: Style.space(3)
                color: modelData.value
                border.width: selected ? Math.max(2, Style.space(1.5)) : Math.max(1, Style.space(1))
                border.color: selected ? cp.accent : Qt.darker(cp.foreground, 1.3)

                PanelToolTip {
                  visible: presetMouse.containsMouse
                  text: modelData.label
                  fontFamily: cp.fontFamily
                }

                MouseArea {
                  id: presetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var rgb = cp.hexToRgb(modelData.value)
                    var hsv = cp.rgbToHsv(rgb.r, rgb.g, rgb.b)
                    cp.commit(hsv.h, hsv.s, hsv.v)
                  }
                }
              }
            }
          }
        }
      }
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
          }
        }

        ColorPicker {
          id: glowColorPicker
          visible: root.mozax && root.mozax.glow && !root.mozax.glowUseTheme
          width: parent.width
          label: "Custom glow color"
          value: root.mozax ? String(root.mozax.customGlowColor) : "#ffffff"
          foreground: root.fg
          fontFamily: root.ff
          onApplied: function(hex) { if (root.mozax) root.mozax.customGlowColor = hex }
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

        ColorPicker {
          id: gridColorPicker
          visible: root.mozax && root.mozax.grid
          width: parent.width
          label: "Line color"
          value: root.mozax ? String(root.mozax.gridColor) : "#000000"
          foreground: root.fg
          fontFamily: root.ff
          onApplied: function(hex) { if (root.mozax) root.mozax.gridColor = hex }
        }

        // ---------- Wallpaper pixelation ----------
        PanelSeparator {
          foreground: root.fg
        }

        PanelSectionHeader {
          text: "WALLPAPER PIXELATION"
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
          label: "Audio visualizer"
          description: root.mozax && root.mozax.visualizerVariant === "mosaic"
            ? "Fading tile heatmap"
            : "Spectrum bars along the bottom"
          checked: root.mozax ? root.mozax.visualizer : true
          foreground: root.fg
          fontFamily: root.ff
          onClicked: if (root.mozax) root.mozax.visualizer = !root.mozax.visualizer
        }

        WindowDropdown {
          id: variantDropdown
          visible: root.mozax && root.mozax.visualizer
          width: parent.width
          label: "Effect"
          value: root.visualizerVariantValue()
          options: [
            { value: "bars", label: "Bars" },
            { value: "mosaic", label: "Mosaic" }
          ]
          onChanged: function(v) { if (root.mozax) root.mozax.visualizerVariant = v }
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
          visible: root.mozax && root.mozax.visualizer && root.mozax.visualizerVariant === "mosaic"
          barRef: root.bar
          label: "Mosaic height"
          valueText: (root.mozax ? root.mozax.visualizerMosaicRows : 4) + " rows"
          boundValue: root.mozax ? root.mozax.visualizerMosaicRows : 4
          minimum: 1
          maximum: root.mozax ? root.mozax.visualizerMosaicRowsMax : 12
          step: 1
          integer: true
          onApplied: function(v) {
            if (!root.mozax) return
            root.mozax.visualizerMosaicRows = Math.max(1, Math.min(root.mozax.visualizerMosaicRowsMax, Math.round(v)))
          }
        }

        SliderControl {
          visible: root.mozax && root.mozax.visualizer && root.mozax.visualizerVariant === "bars"
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

        WindowDropdown {
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
