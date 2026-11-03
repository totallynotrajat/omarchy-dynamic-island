import QtQuick
import QtQuick.Shapes
import qs.Commons

// Resting island face: the clock, plus at most one indicator beside it, in
// priority order: running timer (mini ring + countdown), playing media
// (three-bar meter), imminent meeting (dot). Right-clicking the resting
// island cycles the clock format.
Item {
  id: face

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timing: !!(clocks && clocks.timerActive)
  readonly property bool playing: !timing && !!(island && island.mediaPlaying)
  readonly property bool meeting: !timing && !playing && !!(island && island.calendar && island.calendar.soon)
  readonly property bool resting: !!(clocks && clocks.isPomodoro && clocks.isBreak)
  readonly property color timerTone: island ? (resting ? island.greenColor : island.orangeColor) : "#E5C736"

  Row {
    anchors.centerIn: parent
    spacing: island ? island.s(8) : 8

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: island ? island.formattedClockText : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(13) : 13
      font.weight: Font.DemiBold
      font.letterSpacing: 0.2
      font.features: { "tnum": 1 }
      color: island ? island.fg : "#F7E8B2"
    }

    // Timer: progress ring + countdown
    Row {
      visible: face.timing
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(5) : 5
      opacity: face.timing && face.clocks.timerPaused ? 0.55 : 1

      Shape {
        id: mini
        anchors.verticalCenter: parent.verticalCenter
        width: island ? island.s(11) : 11
        height: width
        preferredRendererType: Shape.CurveRenderer
        readonly property real stroke: Math.max(1.4, island ? island.s(1.6) : 1.6)
        readonly property real r: width / 2 - stroke / 2

        ShapePath {
          strokeWidth: mini.stroke
          strokeColor: Util.alpha(face.timerTone, 0.25)
          fillColor: "transparent"
          PathAngleArc {
            centerX: mini.width / 2; centerY: mini.height / 2
            radiusX: mini.r; radiusY: mini.r
            startAngle: -90; sweepAngle: 360
          }
        }

        ShapePath {
          strokeWidth: mini.stroke
          strokeColor: face.timerTone
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: mini.width / 2; centerY: mini.height / 2
            radiusX: mini.r; radiusY: mini.r
            startAngle: -90
            sweepAngle: face.clocks ? Math.max(1, face.clocks.timerProgress * 360) : 0
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: face.clocks ? face.clocks.timeDisplay : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(12) : 12
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        color: face.timerTone
      }
    }

    // Media: three-bar meter
    Row {
      id: meter
      visible: face.playing
      anchors.verticalCenter: parent.verticalCenter
      height: island ? island.s(10) : 10
      spacing: island ? island.s(2) : 2

      Repeater {
        model: [0.5, 1.0, 0.7]

        Rectangle {
          id: meterBar
          required property var modelData
          required property int index
          property real level: modelData
          anchors.bottom: parent.bottom
          width: Math.max(2, island ? island.s(2) : 2)
          height: Math.max(2, meter.height * level)
          radius: width / 2
          color: island ? island.accentColor : "#2DD5B7"
          Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.InOutSine } }

          Timer {
            interval: 300 + meterBar.index * 70
            repeat: true
            running: face.playing && face.visible
            onTriggered: meterBar.level = 0.35 + Math.random() * 0.65
          }
        }
      }
    }

    // Meeting soon: a single jade dot
    Rectangle {
      visible: face.meeting
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(5) : 5
      height: width
      radius: width / 2
      color: island ? island.accentColor : "#2DD5B7"
    }
  }
}
