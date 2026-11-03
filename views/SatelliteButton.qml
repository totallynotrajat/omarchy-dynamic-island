import QtQuick
import qs.Commons

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

  // Background floating circular glass orb
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: width / 2
    color: sat.isActive ? Util.alpha(island ? island.accentColor : "#2DD5B7", 0.28)
      : (satMouse.containsMouse ? Util.alpha(island ? island.surfaceTop : "#111C18", 0.95) : Util.alpha(island ? island.surfaceTop : "#111C18", 0.72))
    border.width: 1
    border.color: sat.isActive ? (island ? island.accentColor : "#2DD5B7")
      : (satMouse.containsMouse ? Util.alpha(island ? island.fg : "#ffffff", 0.4) : (island ? island.rim : "#ffffff"))

    scale: satMouse.pressed ? 0.92 : (satMouse.containsMouse ? 1.08 : 1.0)

    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    // Active jade glow indicator ring
    Rectangle {
      anchors.fill: parent
      anchors.margins: -(island ? island.s(3) : 3)
      radius: width / 2
      color: "transparent"
      border.width: 1.5
      border.color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.5)
      visible: sat.isActive
      opacity: sat.isActive ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Text {
      anchors.centerIn: parent
      text: sat.glyph
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(18) : 18
      color: sat.isActive ? (island ? island.accentColor : "#2DD5B7")
        : (satMouse.containsMouse ? (island ? island.fg : "#ffffff") : (island ? island.fgDim : "#aaaaaa"))
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  // Floating Tooltip placed horizontally to avoid sibling overlap
  Rectangle {
    id: tip
    visible: opacity > 0.01
    opacity: satMouse.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    anchors.right: sat.side === "left" ? parent.left : undefined
    anchors.rightMargin: sat.side === "left" ? (island ? island.s(8) : 8) : 0
    anchors.left: sat.side === "right" ? parent.right : undefined
    anchors.leftMargin: sat.side === "right" ? (island ? island.s(8) : 8) : 0
    anchors.verticalCenter: parent.verticalCenter
    height: island ? island.s(22) : 22
    width: tipText.implicitWidth + (island ? island.s(14) : 14)
    radius: height / 2
    color: island ? island.bodyAt(0.92) : "#111C18"
    border.width: 1
    border.color: island ? island.rim : "#ffffff"
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
      color: island ? island.fg : "#ffffff"
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
