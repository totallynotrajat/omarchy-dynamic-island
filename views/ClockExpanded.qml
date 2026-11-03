import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Opened Pomodoro Focus / Timer / Stopwatch view.
// When Focusd is active, displays session state, cycle dots, streak, goal,
// and rich playback controls (Pause, Next, Reset, +5m).
Item {
  id: view

  property var island: null
  readonly property var clocks: island.clocks
  readonly property bool isFocusd: clocks.isFocusd
  readonly property bool timer: clocks.timerActive
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property bool isBreak: isFocusd && (clocks.focusSession === "short-break" || clocks.focusSession === "long-break")
  readonly property color tone: paused ? island.fgDim : (timer ? (isBreak ? island.greenColor : island.orangeColor) : island.accentColor)
  readonly property int pad: island.s(22)

  // Focusd Session metadata
  readonly property string sessionTitle: isFocusd ? clocks.focusSessionLabel : (view.timer ? (view.clocks.timerLabel || "Timer") : "Stopwatch")
  readonly property string timeDisplay: isFocusd ? clocks.focusRemainingText : (view.timer ? Model.formatClock(Math.ceil(view.clocks.timerLeft / 1000)) : Model.formatClock(view.clocks.stopwatchElapsed / 1000, true))

  // --------------------------------------------------------------------------
  // Left: Session Info & Big Time Readout
  // --------------------------------------------------------------------------
  Column {
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(3)

    // Top badges: Session Label, Streak, Daily Goal
    Row {
      spacing: island.s(8)

      Text {
        text: (isFocusd ? (isBreak ? " " : " ") : "") + view.sessionTitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(12)
        font.weight: Font.DemiBold
        color: view.tone
      }

      Text {
        visible: isFocusd && clocks.currentStreak > 0
        text: " " + clocks.currentStreak + "d"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(11)
        color: island.orangeColor
      }

      // Jump to Calendar
      Rectangle {
        height: island.s(20)
        width: calJumpLabel.implicitWidth + island.s(12)
        radius: height / 2
        color: Util.alpha(island.accentColor, 0.18)

        Text {
          id: calJumpLabel
          anchors.centerIn: parent
          text: "󰃭 Calendar"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(10)
          font.weight: Font.DemiBold
          color: island.accentColor
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: island.openCalendar()
        }
      }

      Text {
        visible: isFocusd && clocks.dailyGoal !== "" && clocks.dailyGoal !== "0s"
        text: "󰓾 " + clocks.dailyGoal
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(11)
        color: island.fgDim
      }
    }

    // Time readout
    Text {
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

    // Cycle Dots (for Pomodoro work sessions before long break)
    Row {
      visible: isFocusd && clocks.hasSessionData
      spacing: island.s(5)

      Repeater {
        model: isFocusd ? clocks.workSessionsBeforeLongBreak : 0

        Rectangle {
          required property int index
          width: island.s(6)
          height: width
          radius: width / 2
          color: index < clocks.completedSessions ? view.tone : Util.alpha(island.fg, 0.2)
        }
      }

      Text {
        visible: isFocusd && clocks.focusedToday !== "" && clocks.focusedToday !== "0s"
        text: "  ·  " + clocks.focusedToday + " today"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(10)
        color: island.fgDim
      }
    }
  }

  // --------------------------------------------------------------------------
  // Right: Action Controls
  // --------------------------------------------------------------------------
  Row {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(4)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(8)

    // +5 min (or +1 min)
    IconButton {
      glyph: isFocusd ? "󰐕" : (view.timer ? "󰐕" : "󰑓")
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: isFocusd ? view.clocks.addMinutesFocusd(5) : (view.timer ? view.clocks.addToTimer(60) : view.clocks.resetStopwatch())
    }

    // Play / Pause toggle
    Rectangle {
      width: island.s(46)
      height: width
      radius: width / 2
      color: Util.alpha(view.tone, pp.pressed ? 0.4 : 0.24)
      scale: pp.pressed ? 0.92 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }
      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: view.paused ? "󰐊" : "󰏤"
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
        onClicked: view.timer ? view.clocks.toggleTimer() : view.clocks.toggleStopwatch()
      }
    }

    // Skip to next session (Focusd)
    IconButton {
      visible: isFocusd
      glyph: "󰒭"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: view.clocks.skipFocusd()
    }

    // Reset / Cancel
    IconButton {
      glyph: isFocusd ? "󰑓" : "󰅖"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: {
        if (isFocusd) {
          view.clocks.resetFocusd()
        } else if (view.timer) {
          view.clocks.cancelTimer()
          island.collapse()
        } else {
          view.clocks.resetStopwatch()
          island.collapse()
        }
      }
    }
  }
}
