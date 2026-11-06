import QtQuick
import QtQuick.Shapes
import qs.Commons

// One wing of a live activity in the closed notch: the leading wing holds
// what it is (cover, ring, dot, glyph), the trailing wing what it says
// (equalizer, time left, count). Nothing in a wing takes clicks; clicking
// anywhere on the notch opens it to the activity's tab.
Item {
  id: wing

  property var island: null
  property string kind: ""
  property bool leading: true

  readonly property var clocks: island ? island.clocks : null
  readonly property real glyphPx: island ? island.f(13) : 13
  readonly property real textPx: island ? island.f(12) : 12
  readonly property color timerTone: clocks && clocks.isBreak ? island.greenColor : island.orangeColor

  // ---------------------------------------------------------------- media
  AlbumArt {
    visible: wing.kind === "media" && wing.leading
    anchors.centerIn: parent
    width: island ? island.barHeight - island.s(10) : 18
    height: width
    radius: island ? island.s(4) : 4
    source: island ? island.mediaArt : ""
    tint: island ? island.accentColor : "white"
    fontFamily: island ? island.fontFamily : Style.font.family
    opacity: island && island.mediaPlaying ? 1 : 0.6
  }

  Visualizer {
    visible: wing.kind === "media" && !wing.leading
    anchors.centerIn: parent
    playing: !!island && island.mediaPlaying && visible
    color: island ? island.mediaTint : "white"
    bars: 4
    barWidth: island ? Math.max(2, island.s(2)) : 2
    maxHeight: island ? island.s(12) : 12
  }

  // ------------------------------------------------------------ recording
  RecordDot {
    visible: wing.kind === "recording" && wing.leading
    anchors.centerIn: parent
    size: island ? island.s(8) : 8
    color: island ? island.urgentColor : "red"
  }

  Text {
    visible: wing.kind === "recording" && !wing.leading
    anchors.centerIn: parent
    text: island ? island.formatElapsed(island.recordingElapsed) : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: island ? island.urgentColor : "red"
  }

  // ---------------------------------------------------------------- timer
  Shape {
    id: ring
    visible: wing.kind === "timer" && wing.leading
    anchors.centerIn: parent
    width: island ? island.s(13) : 13
    height: width
    preferredRendererType: Shape.CurveRenderer
    opacity: wing.clocks && wing.clocks.timerPaused ? 0.5 : 1
    readonly property real stroke: Math.max(1.5, island ? island.s(2) : 2)
    readonly property real r: width / 2 - stroke / 2

    ShapePath {
      strokeWidth: ring.stroke
      strokeColor: Util.alpha(wing.timerTone, 0.25)
      fillColor: "transparent"
      PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: 360 }
    }

    ShapePath {
      strokeWidth: ring.stroke
      strokeColor: wing.timerTone
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r
        startAngle: -90
        sweepAngle: wing.clocks ? Math.max(1, wing.clocks.timerProgress * 360) : 0
      }
    }
  }

  Text {
    visible: wing.kind === "timer" && !wing.leading
    anchors.centerIn: parent
    text: wing.clocks ? wing.clocks.timeDisplay : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: wing.timerTone
    opacity: wing.clocks && wing.clocks.timerPaused ? 0.6 : 1
  }

  // ------------------------------------------------------------ stopwatch
  Text {
    visible: wing.kind === "stopwatch" && wing.leading
    anchors.centerIn: parent
    text: "󱎫"
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.glyphPx
    color: island ? island.accentColor : "white"
  }

  Text {
    visible: wing.kind === "stopwatch" && !wing.leading
    anchors.centerIn: parent
    text: wing.clocks ? island.formatStopwatch(wing.clocks.stopwatchElapsed) : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: island ? island.fg : "white"
    opacity: wing.clocks && wing.clocks.stopwatchRunning ? 1 : 0.6
  }

  // ------------------------------------------------------- mic / camera
  Text {
    visible: wing.kind === "mic" && wing.leading
    anchors.centerIn: parent
    text: island && island.cameraActive ? "󰄀" : "󰍬"
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.glyphPx
    color: island ? (island.cameraActive ? island.greenColor : island.orangeColor) : "orange"
  }

  Rectangle {
    visible: wing.kind === "mic" && !wing.leading
    anchors.centerIn: parent
    width: island ? island.s(6) : 6
    height: width
    radius: width / 2
    color: island ? (island.cameraActive ? island.greenColor : island.orangeColor) : "orange"
  }

  // ------------------------------------------------------ script activity
  Text {
    visible: wing.kind === "activity" && wing.leading
    anchors.centerIn: parent
    text: island && island.activity ? (island.activity.icon || "󰔟") : ""
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.glyphPx
    color: island && island.activity ? island.toneFor(island.activity.color) : "white"
  }

  Text {
    visible: wing.kind === "activity" && !wing.leading
    anchors.centerIn: parent
    width: parent.width - (island ? island.s(6) : 6)
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: {
      var a = island ? island.activity : null
      if (!a) return ""
      if (a.value) return String(a.value)
      if (a.progress >= 0) return Math.round(a.progress * 100) + "%"
      return ""
    }
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: island ? island.fg : "white"
  }

  // ---------------------------------------------------- meeting soon
  Text {
    visible: wing.kind === "calendar" && wing.leading
    anchors.centerIn: parent
    text: "󰃭"
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.glyphPx
    color: island ? island.accentColor : "white"
  }

  Text {
    visible: wing.kind === "calendar" && !wing.leading
    anchors.centerIn: parent
    text: island && island.calendar ? island.calendar.countdown : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: island ? island.accentColor : "white"
  }

  // ---------------------------------------------------------------- inbox
  Text {
    visible: wing.kind === "inbox" && wing.leading
    anchors.centerIn: parent
    text: "󰂚"
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.glyphPx
    color: island ? island.fg : "white"
  }

  Text {
    visible: wing.kind === "inbox" && !wing.leading
    anchors.centerIn: parent
    text: island ? String(island.inbox.length) : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: wing.textPx
    font.features: { "tnum": 1 }
    color: island ? island.fg : "white"
  }
}
