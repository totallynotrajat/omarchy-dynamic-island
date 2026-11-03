import QtQuick
import qs.Commons

Item {
  id: sat

  property string glyph: ""
  property string tooltipText: ""
  property bool isActive: false
  property var island: null
  signal clicked()

  width: island ? island.s(42) : 42
  height: width

  // Background floating circular glass orb
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: width / 2
    color: sat.isActive ? Util.alpha(island.accentColor, 0.28)
      : (satMouse.containsMouse ? Util.alpha(island.surfaceTop, 0.95) : Util.alpha(island.surfaceTop, 0.72))
    border.width: 1
    border.color: sat.isActive ? island.accentColor
      : (satMouse.containsMouse ? Util.alpha(island.fg, 0.4) : island.rim)

    scale: satMouse.pressed ? 0.92 : (satMouse.containsMouse ? 1.08 : 1.0)

    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    // Active jade glow indicator ring
    Rectangle {
      anchors.fill: parent
      anchors.margins: -island.s(3)
      radius: width / 2
      color: "transparent"
      border.width: 1.5
      border.color: Util.alpha(island.accentColor, 0.5)
      visible: sat.isActive
      opacity: sat.isActive ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Text {
      anchors.centerIn: parent
      text: sat.glyph
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "monospace"
      font.pixelSize: island ? island.f(18) : 18
      color: sat.isActive ? island.accentColor
        : (satMouse.containsMouse ? island.fg : island.fgDim)
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  // Floating Tooltip
  Rectangle {
    id: tip
    visible: opacity > 0.01
    opacity: satMouse.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    y: parent.height + island.s(6)
    anchors.horizontalCenter: parent.horizontalCenter
    height: island.s(22)
    width: tipText.implicitWidth + island.s(14)
    radius: height / 2
    color: island.bodyAt(0.92)
    border.width: 1
    border.color: island.rim
    z: 100

    Text {
      id: tipText
      anchors.centerIn: parent
      text: sat.tooltipText
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(10) : 10
      font.weight: Font.Medium
      color: island.fg
    }
  }

  MouseArea {
    id: satMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: sat.clicked()
  }
}
