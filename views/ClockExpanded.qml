import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / Pomodoro / stopwatch: phase and cycle capsules over a large
// countdown and the preset chips on the left; play/pause wrapped in the
// progress ring on the right, with +5m, skip and reset beside it.
Item {
  id: view

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timer: !!(clocks && clocks.timerActive)
  readonly property bool stopwatch: !!(clocks && clocks.stopwatchActive)
  readonly property bool paused: stopwatch ? !clocks.stopwatchRunning : (!timer || clocks.timerPaused)
  readonly property bool isBreak: !!(clocks && clocks.isBreak && !stopwatch)
  readonly property color accent: island ? island.accentColor : "#2DD5B7"
  readonly property color tone: stopwatch ? accent
    : (!timer ? (island ? island.fgDim : "#F7E8B2") : (isBreak ? island.greenColor : island.orangeColor))
  readonly property int pad: island ? island.s(20) : 20

  readonly property string sessionTitle: !clocks ? "" : (stopwatch ? "Stopwatch" : clocks.timerLabel)
  readonly property string timeDisplay: !clocks ? "25:00"
    : (stopwatch ? Model.formatClock(clocks.stopwatchElapsed / 1000, true) : clocks.timeDisplay)
  readonly property real progress: clocks && !stopwatch ? clocks.timerProgress : 0
  readonly property int activeCycle: {
    if (!clocks) return 0
    var c = clocks.completedSessions
    return (c % 4 === 0 && c > 0) ? 4 : (c % 4)
  }

  function toggle() {
    if (!clocks) return
    if (stopwatch) clocks.toggleStopwatch()
    else clocks.toggleTimer()
  }

  // ------------------------------------------------------------ Left: readout
  Column {
    id: readout
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    width: controls.x - x - (island ? island.s(14) : 14)
    spacing: island ? island.s(4) : 4

    Row {
      spacing: island ? island.s(8) : 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.sessionTitle.toUpperCase()
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(10) : 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: view.tone
      }

      Row {
        visible: !view.stopwatch
        anchors.verticalCenter: parent.verticalCenter
        spacing: island ? island.s(3) : 3

        Repeater {
          model: 4

          Rectangle {
            required property int index
            width: island ? island.s(10) : 10
            height: island ? island.s(3) : 3
            radius: height / 2
            color: index < view.activeCycle ? view.tone : Util.alpha(island ? island.fg : "#F7E8B2", 0.14)
          }
        }
      }
    }

    Text {
      text: view.timeDisplay
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(34) : 34
      font.weight: Font.Medium
      font.features: { "tnum": 1 }
      color: island ? island.fg : "#F7E8B2"
      opacity: view.paused && view.timer ? 0.6 : 1

      Behavior on opacity { NumberAnimation { duration: 200 } }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.toggle()
      }
    }

    Row {
      spacing: island ? island.s(5) : 5

      Repeater {
        model: [
          { min: 25, label: "25m", name: "Focus", aliases: ["Focus", "Pomodoro", "Work"] },
          { min: 50, label: "50m", name: "Deep Work", aliases: ["Deep Work"] },
          { min: 5, label: "5m", name: "Short Break", aliases: ["Short Break"] },
          { min: 15, label: "15m", name: "Long Break", aliases: ["Long Break"] }
        ]

        Rectangle {
          id: chip
          required property var modelData
          readonly property bool current: view.timer && !view.stopwatch
            && modelData.aliases.indexOf(view.clocks.timerLabel) !== -1
          width: chipText.implicitWidth + (island ? island.s(14) : 14)
          height: island ? island.s(20) : 20
          radius: height / 2
          color: current ? Util.alpha(view.tone, 0.2)
            : Util.alpha(island ? island.fg : "#F7E8B2", chipMouse.containsMouse ? 0.12 : 0.05)
          border.width: current ? 1 : 0
          border.color: Util.alpha(view.tone, 0.6)

          Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.fontFamily : "sans-serif"
            font.pixelSize: island ? island.f(10) : 10
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: chip.current ? view.tone : (island ? island.fgDim : "#F7E8B2")
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (view.clocks) view.clocks.startTimer(chip.modelData.min * 60, chip.modelData.name)
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ Right: ring + transport
  Row {
    id: controls
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(12) : 12

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(6) : 6

      Repeater {
        model: [
          { key: "add", glyph: "+5", text: true },
          { key: "skip", glyph: "󰒭", text: false },
          { key: "reset", glyph: "󰅖", text: false }
        ]

        Rectangle {
          id: small
          required property var modelData
          readonly property bool shown: modelData.key === "add" ? view.timer
            : (modelData.key === "skip" ? !!(view.timer && view.clocks.isPomodoro) : (view.timer || view.stopwatch))
          width: island ? island.s(28) : 28
          height: width
          radius: width / 2
          opacity: shown ? 1 : 0.3
          color: Util.alpha(island ? island.fg : "#F7E8B2", smallMouse.containsMouse && shown ? 0.14 : 0.06)

          Text {
            anchors.centerIn: parent
            text: small.modelData.glyph
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: small.modelData.text ? (island ? island.textFamily : "sans-serif") : (island ? island.fontFamily : "sans-serif")
            font.pixelSize: small.modelData.text ? (island ? island.f(10) : 10) : (island ? island.f(12) : 12)
            font.weight: Font.DemiBold
            color: island ? island.fg : "#F7E8B2"
          }

          MouseArea {
            id: smallMouse
            anchors.fill: parent
            enabled: small.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!view.clocks) return
              if (small.modelData.key === "add") view.clocks.addToTimer(300)
              else if (small.modelData.key === "skip") view.clocks.skipPomodoro()
              else view.clocks.dismissActive()
            }
          }
        }
      }
    }

    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(88) : 88
      height: width

      ProgressRing {
        anchors.fill: parent
        progress: view.progress
        color: view.timer ? view.tone : view.accent
        lineWidth: island ? island.s(4) : 4
      }

      Rectangle {
        anchors.centerIn: parent
        width: island ? island.s(56) : 56
        height: width
        radius: width / 2
        color: view.accent
        scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.05 : 1)

        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

        Text {
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: view.paused ? (island ? island.s(1) : 1) : 0
          text: view.paused ? "󰐊" : "󰏤"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : "sans-serif"
          font.pixelSize: island ? island.f(22) : 22
          color: island ? island.surfaceBottom : "#090F0D"
        }

        MouseArea {
          id: playMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.toggle()
        }
      }
    }
  }
}
