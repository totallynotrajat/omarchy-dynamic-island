import QtQuick
import qs.Commons

// Floating glass orb beside the expanded island. Active: jade glyph on a
// faint jade fill. Tooltip opens outward, away from the island.
Item {
  id: sat

  property string glyph: ""
  property string tooltipText: ""
  property bool isActive: false
  property string side: "left"
  property var island: null
  signal clicked()

  width: island ? island.s(42) : 42
  height: width

  readonly property color fg: island ? island.fg : "#F7E8B2"
  readonly property color accent: island ? island.accentColor : "#2DD5B7"
  readonly property color glass: island ? island.surfaceTop : "#111C18"

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: width / 2
    color: sat.isActive ? Util.alpha(sat.accent, 0.13)
      : Util.alpha(sat.glass, satMouse.containsMouse ? 0.96 : 0.82)
    border.width: 1
    border.color: sat.isActive ? Util.alpha(sat.accent, 0.45)
      : Util.alpha(sat.fg, satMouse.containsMouse ? 0.18 : 0.08)

    scale: satMouse.pressed ? 0.94 : (satMouse.containsMouse ? 1.06 : 1.0)

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Text {
      anchors.centerIn: parent
      text: sat.glyph
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(17) : 17
      color: sat.isActive ? sat.accent
        : (satMouse.containsMouse ? sat.fg : Util.alpha(sat.fg, 0.6))
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  Rectangle {
    id: tip
    visible: opacity > 0.01
    opacity: satMouse.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
    anchors.right: sat.side === "left" ? parent.left : undefined
    anchors.rightMargin: sat.side === "left" ? (island ? island.s(10) : 10) : 0
    anchors.left: sat.side === "right" ? parent.right : undefined
    anchors.leftMargin: sat.side === "right" ? (island ? island.s(10) : 10) : 0
    anchors.verticalCenter: parent.verticalCenter
    height: island ? island.s(22) : 22
    width: tipText.implicitWidth + (island ? island.s(18) : 18)
    radius: height / 2
    color: sat.glass
    border.width: 1
    border.color: Util.alpha(sat.fg, 0.07)
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
      color: sat.fg
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
