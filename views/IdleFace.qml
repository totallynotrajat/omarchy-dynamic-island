import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Resting island face: Digital system clock is ALWAYS visible in the center of the bar.
// Displays subtle indicators beside the clock when a timer, music, or meeting is active.
// Right-clicking the resting notch cycles the clock format variations immediately.
Item {
  id: face

  property var island: null

  Row {
    anchors.centerIn: parent
    spacing: island ? island.s(6) : 6

    // Default Digital Clock Text - ALWAYS visible when blended/resting
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: island ? island.formattedClockText : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(12) : 12
      font.weight: Font.DemiBold
      color: island ? island.fg : "#ffffff"
    }

    // Active Pomodoro / Timer indicator badge
    Row {
      visible: !!(island && island.clocks && island.clocks.timerActive)
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(3) : 3

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks && island.clocks.isPomodoro
          ? (island.clocks.isBreak ? "" : "󰔛") : "󰔛"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: island && island.clocks && island.clocks.isBreak
          ? (island ? island.greenColor : "#2DD5B7")
          : (island ? island.orangeColor : "#F7E8B2")
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks ? (island.clocks.timeDisplay || Model.formatClock(Math.ceil(island.clocks.timerLeft / 1000))) : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        font.features: { "tnum": 1 }
        color: island ? island.orangeColor : "#F7E8B2"
      }
    }

    // Active media playing indicator
    Text {
      visible: !!(island && island.mediaPlaying && (!island.clocks || !island.clocks.timerActive))
      anchors.verticalCenter: parent.verticalCenter
      text: "󰎆"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.greenColor : "#2DD5B7"
    }

    // Upcoming meeting indicator
    Text {
      visible: !!(island && island.calendar && island.calendar.soon && (!island.clocks || !island.clocks.timerActive))
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
