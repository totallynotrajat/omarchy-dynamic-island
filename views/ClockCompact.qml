import QtQuick
import "../IslandModel.js" as Model

// Timer or stopwatch, compact.
// Focusd Pomodoro session glyph sits in a ring that fills as time progresses;
// remaining time hugs the trailing edge.
Item {
  id: view

  property var island: null
  property string mode: "timer"
  readonly property var clocks: island.clocks
  readonly property bool timer: mode === "timer"
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property bool isBreak: clocks.isFocusd && (clocks.focusSession === "short-break" || clocks.focusSession === "long-break")
  readonly property color tone: paused ? island.fgDim : (timer ? (isBreak ? island.greenColor : island.orangeColor) : island.accentColor)

  function glyph() {
    if (!view.timer) return "󱎫"
    if (view.clocks.isFocusd) {
      if (view.clocks.focusSession === "short-break") return view.paused ? "󰏤" : ""
      if (view.clocks.focusSession === "long-break") return view.paused ? "󰒲" : ""
      return view.paused ? "󰏤" : ""
    }
    return view.paused ? "󰏤" : "󰔛"
  }

  Item {
    anchors.left: parent.left
    anchors.leftMargin: island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(22)
    height: width

    ProgressRing {
      anchors.fill: parent
      visible: view.timer
      progress: view.clocks.timerProgress
      color: view.tone
      lineWidth: island.s(2)
    }

    Text {
      anchors.centerIn: parent
      text: view.glyph()
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: view.timer ? island.f(11) : island.f(15)
      color: view.tone
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    text: view.timer ? (view.clocks.isFocusd ? view.clocks.focusRemainingText : Model.formatClock(Math.ceil(view.clocks.timerLeft / 1000)))
      : Model.formatClock(view.clocks.stopwatchElapsed / 1000, false)
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(13)
    font.bold: true
    font.features: { "tnum": 1 }
    color: view.tone
  }
}
