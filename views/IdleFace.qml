import QtQuick

// Resting island face: the clock, plus a countdown while a timer runs and a
// single mark for playing media or an imminent meeting. Right-clicking the
// resting island cycles the clock format.
Item {
  id: face

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timing: !!(clocks && clocks.timerActive)
  readonly property bool resting: !!(clocks && clocks.isPomodoro && clocks.isBreak)
  readonly property color timerTone: island ? (resting ? island.greenColor : island.orangeColor) : "#F7E8B2"

  Row {
    anchors.centerIn: parent
    spacing: island ? island.s(6) : 6

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: island ? island.formattedClockText : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(12) : 12
      font.weight: Font.DemiBold
      color: island ? island.fg : "#F7E8B2"
    }

    Row {
      visible: face.timing
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(3) : 3
      opacity: face.timing && face.clocks.timerPaused ? 0.55 : 1

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: face.resting ? "" : "󰔛"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: face.timerTone
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: face.clocks ? face.clocks.timeDisplay : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        font.features: { "tnum": 1 }
        color: face.timerTone
      }
    }

    Text {
      visible: !face.timing && !!(island && island.mediaPlaying)
      anchors.verticalCenter: parent.verticalCenter
      text: "󰎆"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.greenColor : "#2DD5B7"
    }

    Text {
      visible: !face.timing && !!(island && island.calendar && island.calendar.soon)
      anchors.verticalCenter: parent.verticalCenter
      text: "󰃭"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.accentColor : "#2DD5B7"
    }
  }
}
