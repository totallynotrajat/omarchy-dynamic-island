import QtQuick
import qs.Commons

// A glyph button for the open notch: no chrome until hovered, then a soft
// round wash, like Boring Notch's HoverButton. `label` turns it into a pill
// with text beside the glyph.
Item {
  id: button

  property var island: null
  property string glyph: ""
  property string label: ""
  property real glyphSize: island ? island.f(15) : 15
  property color color: island ? island.fg : "white"
  property bool available: true
  property bool selected: false
  property string tooltip: ""

  signal clicked()

  readonly property real side: island ? island.s(28) : 28
  implicitWidth: label ? row.implicitWidth + side * 0.7 : side
  implicitHeight: side
  scale: mouse.pressed && available ? 0.9 : 1

  Behavior on scale { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Util.alpha(button.color, !button.available ? 0
      : (button.selected ? 0.14 : (mouse.pressed ? 0.16 : (mouse.containsMouse ? 0.08 : 0))))
    Behavior on color { ColorAnimation { duration: Style.duration(140) } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: island ? island.s(5) : 5
    opacity: button.available ? 1 : 0.35

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: button.glyph
      visible: text !== ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: button.glyphSize
      color: button.color
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: button.label
      visible: text !== ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(11) : 11
      font.features: { "tnum": 1 }
      color: button.color
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (button.available) button.clicked()
  }
}
