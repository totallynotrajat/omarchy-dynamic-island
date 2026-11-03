import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// What the resting island shows: The digital clock ALWAYS visible in the center of the bar
// with subtle status indicators for Pomodoro, media, and calendar meetings.
// Right-clicking cycles the clock format variations.
Item {
  id: face

  property var island: null
  readonly property string mode: island ? island.idleFace : "clock"

  Row {
    anchors.centerIn: parent
    spacing: island ? island.s(6) : 6

    // Default Clock Text - ALWAYS visible when blended/resting
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

    // Active Pomodoro indicator badge
    Row {
      visible: island && island.clocks && island.clocks.timerActive
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(3) : 3

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks && island.clocks.isPomodoro
          ? (island.clocks.isBreak ? "󰏤" : "󰔛") : "󰔛"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: island && island.clocks && island.clocks.isBreak
          ? island.greenColor : island.orangeColor
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks
          ? (island.clocks.timeDisplay || Model.formatClock(Math.ceil(island.clocks.timerLeft / 1000))) : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: island ? island.orangeColor : "#ffaa00"
      }
    }

    // Active music playing indicator
    Text {
      visible: island && island.mediaPlaying && (!island.clocks || !island.clocks.timerActive)
      anchors.verticalCenter: parent.verticalCenter
      text: "󰎆"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.greenColor : "#2DD5B7"
    }

    // Calendar meeting soon indicator
    Text {
      visible: island && island.calendar && island.calendar.soon && (!island.clocks || !island.clocks.timerActive)
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
