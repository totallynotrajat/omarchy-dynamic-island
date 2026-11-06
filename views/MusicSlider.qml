import QtQuick
import qs.Commons

// Boring Notch's scrubber: a thin bar that thickens while dragged, with the
// elapsed and total time under it.
Item {
  id: slider

  property var island: null
  property real position: 0   // seconds
  property real length: 0     // seconds
  property bool seekable: false
  property color color: "white"

  property bool dragging: false
  property real dragValue: 0
  readonly property real shown: dragging ? dragValue : (length > 0 ? Math.max(0, Math.min(1, position / length)) : 0)

  signal seek(real fraction)

  implicitHeight: bar.height + times.height + (island ? island.s(4) : 4)

  function fmt(sec) {
    sec = Math.max(0, Math.floor(sec))
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
    return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  Item {
    id: bar
    width: parent.width
    height: island ? island.s(10) : 10

    Rectangle {
      id: trackBg
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: slider.dragging ? (island ? island.s(8) : 8) : (island ? island.s(5) : 5)
      radius: height / 2
      color: Util.alpha(island ? island.fg : "white", 0.18)
      Behavior on height { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

      Rectangle {
        width: Math.round(parent.width * slider.shown)
        height: parent.height
        radius: parent.radius
        color: slider.color
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.topMargin: -4
      anchors.bottomMargin: -4
      enabled: slider.seekable && slider.length > 0
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      preventStealing: true
      function at(x) { return Math.max(0, Math.min(1, x / width)) }
      onPressed: function(m) { slider.dragging = true; slider.dragValue = at(m.x) }
      onPositionChanged: function(m) { if (pressed) slider.dragValue = at(m.x) }
      onReleased: function(m) { slider.seek(at(m.x)); slider.dragging = false }
      onCanceled: slider.dragging = false
    }
  }

  Item {
    id: times
    anchors.top: bar.bottom
    anchors.topMargin: island ? island.s(3) : 3
    width: parent.width
    height: elapsed.implicitHeight

    Text {
      id: elapsed
      text: slider.fmt(slider.shown * slider.length)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(10) : 10
      font.features: { "tnum": 1 }
      color: island ? island.fgDim : "gray"
    }

    Text {
      anchors.right: parent.right
      text: slider.length > 0 ? slider.fmt(slider.length) : "--:--"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(10) : 10
      font.features: { "tnum": 1 }
      color: island ? island.fgDim : "gray"
    }
  }
}
