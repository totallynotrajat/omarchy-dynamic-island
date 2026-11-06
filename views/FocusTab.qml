import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The open notch's Focus tab.
//
// Left: the Pomodoro. The time left, which session it is, the round's
// sessions as small bars, and play/pause, skip, reset and +5 minutes.
// Runs on focusd when the daemon is up (its cycle, goal and streak),
// otherwise on the island's own 25/5/15 cycle.
// Right: today's focus numbers, quick kitchen timers and the stopwatch.
Item {
  id: tab

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property var focusd: clocks ? clocks.focusdSource : null
  readonly property bool onBreak: !!clocks && clocks.pomoBreak
  readonly property color tone: onBreak ? island.greenColor : island.orangeColor
  readonly property color labelColor: Util.alpha(island.fg, 0.55)

  // ------------------------------------------------------------ Pomodoro
  Item {
    id: pomo
    x: 0
    width: parent.width * 0.52
    height: parent.height

    Text {
      id: sessionLabel
      y: island.s(2)
      text: (tab.clocks.pomoLabel + (tab.clocks.pomoPaused ? " · paused" : (tab.clocks.pomoActive ? "" : " · ready"))).toUpperCase()
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(10)
      font.letterSpacing: 1
      font.bold: true
      color: tab.clocks.pomoActive ? tab.tone : tab.labelColor
    }

    Text {
      id: big
      anchors.top: sessionLabel.bottom
      anchors.topMargin: island.s(2)
      text: Model.formatClock(tab.clocks.pomoLeftSeconds)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(40)
      font.bold: true
      font.features: { "tnum": 1 }
      color: island.fg
      opacity: tab.clocks.pomoPaused ? 0.6 : 1
    }

    // Progress through the session.
    Rectangle {
      id: progress
      anchors.top: big.bottom
      anchors.topMargin: island.s(4)
      width: parent.width - island.s(10)
      height: island.s(4)
      radius: height / 2
      color: Util.alpha(island.fg, 0.14)

      Rectangle {
        width: Math.round(parent.width * tab.clocks.pomoProgress)
        height: parent.height
        radius: parent.radius
        color: tab.tone
        Behavior on width { NumberAnimation { duration: Style.duration(400) } }
      }
    }

    // The round: one bar per work session before the long break.
    Row {
      id: round
      anchors.top: progress.bottom
      anchors.topMargin: island.s(8)
      spacing: island.s(4)

      Repeater {
        model: tab.clocks.pomoTarget
        Rectangle {
          required property int index
          anchors.verticalCenter: parent.verticalCenter
          width: island.s(16)
          height: island.s(4)
          radius: height / 2
          color: index < tab.clocks.pomoCycleDone ? tab.tone
            : (index === tab.clocks.pomoCycleDone && !tab.onBreak && tab.clocks.pomoActive ? Util.alpha(tab.tone, 0.5) : Util.alpha(island.fg, 0.14))
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: island.s(4)
        text: "Next · " + tab.clocks.nextLabel
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(10)
        color: island.fgDim
      }
    }

    Row {
      anchors.bottom: parent.bottom
      spacing: island.s(4)

      NotchButton {
        island: tab.island
        glyph: tab.clocks.pomoRunning ? "󰏤" : "󰐊"
        label: tab.clocks.pomoRunning ? "Pause" : (tab.clocks.pomoPaused ? "Resume" : "Start")
        glyphSize: island.f(13)
        selected: true
        color: tab.clocks.pomoRunning ? island.fg : tab.tone
        onClicked: tab.clocks.pomoToggle()
      }

      NotchButton {
        island: tab.island
        glyph: "󰒭"
        glyphSize: island.f(13)
        available: tab.clocks.pomoActive || tab.clocks.usesFocusd
        onClicked: tab.clocks.pomoSkip()
      }

      NotchButton {
        island: tab.island
        glyph: "󰑐"
        glyphSize: island.f(13)
        available: tab.clocks.pomoActive
        onClicked: tab.clocks.pomoReset()
      }

      NotchButton {
        island: tab.island
        label: "+5m"
        available: tab.clocks.pomoActive
        onClicked: tab.clocks.pomoAddMinutes(5)
      }
    }
  }

  Rectangle {
    id: rule
    anchors.left: pomo.right
    anchors.leftMargin: island.s(8)
    y: island.s(4)
    width: 1
    height: parent.height - y * 2
    color: Util.alpha(island.fg, 0.1)
  }

  // ------------------------------------------------------------ right column
  Column {
    anchors.left: rule.right
    anchors.leftMargin: island.s(16)
    anchors.right: parent.right
    spacing: island.s(5)

    // Today (focusd keeps these).
    Text {
      text: "TODAY"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(10)
      font.letterSpacing: 1
      font.bold: true
      color: tab.labelColor
    }

    Row {
      spacing: island.s(16)
      visible: tab.clocks.usesFocusd

      Repeater {
        model: [
          { label: "Focused", value: tab.focusd ? (tab.focusd.focusedToday || "0s") : "" },
          { label: "Goal", value: tab.focusd ? (tab.focusd.dailyGoal || "–") : "" },
          { label: "Sessions", value: tab.focusd ? String(tab.focusd.sessionsToday) : "" },
          { label: "Streak", value: tab.focusd ? tab.focusd.currentStreak + "d" : "" }
        ]

        Column {
          required property var modelData
          spacing: island.s(1)

          Text {
            text: modelData.value
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(14)
            font.bold: true
            font.features: { "tnum": 1 }
            color: island.fg
          }

          Text {
            text: modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(10)
            color: island.fgDim
          }
        }
      }
    }

    Text {
      visible: !tab.clocks.usesFocusd
      text: tab.clocks.pomoCycleDone + " of 4 focus sessions this round"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      color: island.fgDim
    }

    Item { width: 1; height: island.s(4) }

    // Kitchen timer.
    Text {
      text: tab.clocks.rawTimerActive ? ("TIMER · " + (tab.clocks.rawTimerLabel || "Timer").toUpperCase()) : "TIMER"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(10)
      font.letterSpacing: 1
      font.bold: true
      color: tab.labelColor
    }

    Row {
      spacing: island.s(4)

      Text {
        visible: tab.clocks.rawTimerActive
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: island.s(6)
        text: Model.formatClock(Math.ceil(tab.clocks.rawTimerLeft / 1000))
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(14)
        font.bold: true
        font.features: { "tnum": 1 }
        color: island.orangeColor
        opacity: tab.clocks.rawTimerPaused ? 0.6 : 1
      }

      Repeater {
        model: tab.clocks.rawTimerActive ? [] : [5, 15, 25]
        NotchButton {
          required property int modelData
          island: tab.island
          label: modelData + "m"
          onClicked: tab.clocks.startTimer(modelData * 60, modelData + " min")
        }
      }

      NotchButton {
        visible: tab.clocks.rawTimerActive
        island: tab.island
        glyph: tab.clocks.rawTimerPaused ? "󰐊" : "󰏤"
        glyphSize: island.f(13)
        onClicked: tab.clocks.toggleTimer()
      }

      NotchButton {
        visible: tab.clocks.rawTimerActive
        island: tab.island
        label: "+1m"
        onClicked: tab.clocks.addToTimer(60)
      }

      NotchButton {
        visible: tab.clocks.rawTimerActive
        island: tab.island
        glyph: "󰅖"
        glyphSize: island.f(13)
        onClicked: tab.clocks.cancelTimer()
      }
    }

    // Stopwatch.
    Row {
      spacing: island.s(4)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: island.s(6)
        text: island.formatStopwatch(tab.clocks.stopwatchElapsed)
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(14)
        font.bold: true
        font.features: { "tnum": 1 }
        color: tab.clocks.stopwatchActive ? island.fg : island.fgDim
      }

      NotchButton {
        island: tab.island
        glyph: tab.clocks.stopwatchRunning ? "󰏤" : "󱎫"
        glyphSize: island.f(13)
        onClicked: tab.clocks.toggleStopwatch()
      }

      NotchButton {
        island: tab.island
        glyph: "󰑐"
        glyphSize: island.f(13)
        available: tab.clocks.stopwatchActive
        onClicked: tab.clocks.resetStopwatch()
      }
    }
  }
}
