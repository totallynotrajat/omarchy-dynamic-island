import QtQuick
import qs.Commons

// Resting island face: Displays the time by default (e.g. "Tue 3 Nov 10:20 PM"),
// with subtle status indicators for Focusd Pomodoro and media when active.
Item {
  id: face

  property var island: null

  Row {
    anchors.centerIn: parent
    spacing: island ? island.s(6) : 6

    // Default Clock Text (e.g. "Tue 3 Nov 10:20 PM")
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: island ? island.defaultClockText : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(12) : 12
      font.weight: Font.DemiBold
      color: island ? island.fg : "#ffffff"
    }

    // Active Focusd Pomodoro badge
    Row {
      visible: island && island.clocks && island.clocks.timerActive
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(3) : 3

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks && island.clocks.isFocusd
          ? (island.clocks.focusSession.indexOf("break") !== -1 ? "" : "") : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: island && island.clocks && island.clocks.isFocusd && island.clocks.focusSession.indexOf("break") !== -1
          ? island.greenColor : island.orangeColor
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island && island.clocks && island.clocks.isFocusd ? island.clocks.focusRemainingText : ""
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
      color: island ? island.greenColor : "#00ff88"
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
      color: island ? island.accentColor : "#3388ff"
    }
  }
}
