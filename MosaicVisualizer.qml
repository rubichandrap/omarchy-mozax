pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property var values: []
  property int columns: 0
  property int rows: 4
  property int bandCount: 60
  property real cellPitch: 32
  property int rowPitch: 16
  property int gridGap: 1
  property real bottomOffset: 0
  property real visualizerOpacity: 0.65
  property color accentColor: "#ffffff"
  property var cellConfig: []
  property var cellValues: []

  readonly property real boardWidth: Math.max(0, columns * cellPitch)
  readonly property real startX: Math.max(0, (width - boardWidth) / 2)
  readonly property int startY: Math.max(0, Math.floor(height - bottomOffset - rows * rowPitch))
  readonly property real tileWidth: Math.max(1, cellPitch - gridGap * 2)
  readonly property real tileHeight: Math.max(1, rowPitch - gridGap * 2)

  function hash(column, row) {
    var value = Math.sin(column * 127.1 + row * 311.7) * 43758.5453
    return value - Math.floor(value)
  }

  function clampBand(band) {
    return Math.max(0, Math.min(bandCount - 1, band))
  }

  function rebuildCells() {
    if (columns <= 0 || rows <= 0 || bandCount <= 0) {
      cellConfig = []
      cellValues = []
      return
    }

    var config = []
    var values = []
    for (var row = 0; row < rows; row++) {
      var baseBand = rows > 1
        ? Math.round((rows - 1 - row) * (bandCount - 1) / (rows - 1))
        : Math.floor(bandCount / 2)
      for (var column = 0; column < columns; column++) {
        var jitter = Math.floor(hash(column * 7.3 + 0.5, row * 3.7 + 1.1) * 5) - 2
        config.push({
          column: column,
          row: row,
          band: clampBand(baseBand + jitter),
          threshold: 0.04 + hash(column * 1.7 + 0.31, row * 2.9 + 0.77) * 0.74
        })
        values.push(0)
      }
    }
    cellConfig = config
    cellValues = values
  }

  function advance(rawValues) {
    if (cellConfig.length !== rows * columns || cellValues.length !== rows * columns) rebuildCells()
    if (cellConfig.length === 0) return

    var next = []
    for (var i = 0; i < cellConfig.length; i++) {
      var cell = cellConfig[i]
      var raw = Number(rawValues && rawValues[cell.band])
      if (!isFinite(raw) || raw < 0) raw = 0
      var level = Math.min(1.05, raw / 16)
      var value = Number(cellValues[i]) * 0.88
      if (level > cell.threshold && level > value) value = level
      next.push(value < 0.001 ? 0 : value)
    }
    cellValues = next
  }

  function tileScale(value) {
    if (value >= 0.45) return 1.0
    if (value >= 0.28) return 0.85
    if (value >= 0.15) return 0.68
    if (value >= 0.05) return 0.5
    return 0
  }

  function tileAlpha(value) {
    if (value >= 0.45) return 1.0
    if (value >= 0.28) return 0.8
    if (value >= 0.15) return 0.62
    if (value >= 0.05) return 0.42
    return 0
  }

  function tileColor(value) {
    if (value >= 0.85) {
      return Qt.rgba(
        Math.min(1, accentColor.r * 1.5 + 0.25),
        Math.min(1, accentColor.g * 1.5 + 0.25),
        Math.min(1, accentColor.b * 1.5 + 0.25),
        1)
    }
    if (value >= 0.65) {
      return Qt.rgba(
        Math.min(1, accentColor.r * 1.3 + 0.15),
        Math.min(1, accentColor.g * 1.3 + 0.15),
        Math.min(1, accentColor.b * 1.3 + 0.15),
        1)
    }
    return accentColor
  }

  onValuesChanged: advance(values)
  onColumnsChanged: {
    rebuildCells()
    advance(values)
  }
  onRowsChanged: {
    rebuildCells()
    advance(values)
  }
  onBandCountChanged: {
    rebuildCells()
    advance(values)
  }

  Component.onCompleted: {
    rebuildCells()
    advance(values)
  }

  Repeater {
    model: root.cellConfig

    Rectangle {
      id: tile
      required property int index

      readonly property real intensity: index < root.cellValues.length
        ? Number(root.cellValues[index])
        : 0
      readonly property real tileScaleFactor: root.tileScale(tile.intensity)
      readonly property real opacityScale: root.tileAlpha(tile.intensity)

      width: root.tileWidth * tile.tileScaleFactor
      height: root.tileHeight * tile.tileScaleFactor
      x: root.startX + root.cellConfig[index].column * root.cellPitch + root.gridGap
        + (root.tileWidth - width) / 2
      y: root.startY + root.cellConfig[index].row * root.rowPitch + root.gridGap
        + (root.tileHeight - height) / 2
      color: root.tileColor(tile.intensity)
      opacity: root.visualizerOpacity * tile.opacityScale
    }
  }
}
