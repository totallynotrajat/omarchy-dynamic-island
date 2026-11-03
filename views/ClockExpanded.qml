import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / Pomodoro / stopwatch: time large, clickable, and its controls.
// Displays Pomodoro work/break cycles, cycle dots, and rich controls.
Item {
  id: view

  property var island: null
  readonly property var clocks: island.clocks
  readonly property bool timer: clocks.timerActive
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property bool isBreak: clocks.isPomodoro && (clocks.timerLabel.indexOf("Break") !== -1 || clocks.timerLabel.indexOf("break") !== -1)
  readonly property color tone: paused && !timer ? island.fgDim : (timer ? (isBreak ? island.greenColor : island.orangeColor) : island.accentColor)
  readonly property int pad: island.s(24)

  readonly property string sessionTitle: clocks.timerLabel || (clocks.stopwatchActive ? "Stopwatch" : "Pomodoro")
  readonly property string timeDisplay: clocks.stopwatchActive ? Model.formatClock(clocks.stopwatchElapsed / 1000, true)
    : Model.formatClock(Math.ceil(clocks.timerLeft / 1000))

  Column {
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(3)

    // Session label & cycle dots
    Row {
      spacing: island.s(8)

      Text {
        text: (clocks.isPomodoro ? (isBreak ? "  " : "  ") : "") + view.sessionTitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(12)
        font.weight: Font.DemiBold
        color: view.tone
      }

      // 4 cycle dots for pomodoro
      Row {
        visible: clocks.isPomodoro
        anchors.verticalCenter: parent.verticalCenter
        spacing: island.s(4)

        Repeater {
          model: 4
          Rectangle {
            required property int index
            width: island.s(5)
            height: width
            radius: width / 2
            color: index < (clocks.completedSessions % 4) ? view.tone : Util.alpha(island.fg, 0.2)
          }
        }
      }
    }

    // Big Time Readout - CLICKABLE to start / pause / resume!
    Item {
      width: timeText.implicitWidth
      height: timeText.implicitHeight

      Text {
        id: timeText
        anchors.centerIn: parent
        text: view.timeDisplay
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(36)
        font.weight: Font.Light
        font.letterSpacing: -1
        font.features: { "tnum": 1 }
        color: view.tone
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks.stopwatchActive) {
            clocks.toggleStopwatch()
          } else {
            clocks.toggleTimer()
          }
        }
      }
    }
  }

  // Right-hand action buttons
  Row {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(8)

    // +5 min
    IconButton {
      glyph: clocks.stopwatchActive ? "󰑓" : "󰐕"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: clocks.stopwatchActive ? clocks.resetStopwatch() : clocks.addToTimer(300)
    }

    // Play / Pause toggle
    Rectangle {
      width: island.s(46)
      height: width
      radius: width / 2
      color: Util.alpha(view.tone, pp.pressed ? 0.4 : 0.26)
      scale: pp.pressed ? 0.92 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: (view.timer && !view.paused) || clocks.stopwatchRunning ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(20)
        color: view.tone
      }

      MouseArea {
        id: pp
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks.stopwatchActive) clocks.toggleStopwatch()
          else clocks.toggleTimer()
        }
      }
    }

    // Skip to next session (Pomodoro)
    IconButton {
      visible: clocks.isPomodoro
      glyph: "󰒭"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: clocks.skipPomodoro()
    }

    // Cancel / Reset
    IconButton {
      glyph: "󰅖"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: {
        if (clocks.isPomodoro) clocks.resetPomodoro()
        else if (view.timer) clocks.cancelTimer()
        else clocks.resetStopwatch()
        island.collapse()
      }
    }
  }
}
