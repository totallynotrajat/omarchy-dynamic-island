import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / Pomodoro / stopwatch.
// Left: phase + cycle dashes, the countdown, preset track.
// Right: secondary ghost actions, then play/pause wrapped in the progress ring.
Item {
  id: view

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timer: !!(clocks && clocks.timerActive)
  readonly property bool stopwatch: !!(clocks && !timer && clocks.stopwatchActive)
  readonly property bool running: timer ? !clocks.timerPaused : !!(clocks && clocks.stopwatchRunning)
  readonly property bool isPomodoro: !!(clocks && clocks.isPomodoro)
  readonly property bool isBreak: timer && !!clocks.isBreak
  readonly property color fg: island ? island.fg : "#F7E8B2"
  readonly property color tone: timer ? (isBreak ? island.greenColor : island.orangeColor)
    : (stopwatch ? island.accentColor : Util.alpha(fg, 0.34))
  readonly property int pad: island ? island.s(24) : 24

  readonly property string phase: {
    if (stopwatch) return "Stopwatch"
    if (!timer) return "Focus"
    var l = String(clocks.timerLabel || "")
    if (l === "Pomodoro" || l === "Work" || l === "") return "Focus"
    if (l === "Deep Work") return "Deep work"
    if (l === "Short Break") return "Short break"
    if (l === "Long Break") return "Long break"
    return l
  }

  readonly property string timeDisplay: !clocks ? "25:00"
    : (stopwatch ? Model.formatClock(clocks.stopwatchElapsed / 1000, true)
                 : Model.formatClock(Math.ceil(clocks.timerLeft / 1000)))

  readonly property real progress: !clocks ? 0
    : (timer ? clocks.timerProgress
             : (stopwatch ? (clocks.stopwatchElapsed % 60000) / 60000 : 0))

  readonly property int activeCycle: {
    if (!clocks) return 0
    var c = clocks.completedSessions
    return (c % 4 === 0 && c > 0) ? 4 : (c % 4)
  }

  function toggle() {
    if (!clocks) return
    if (clocks.stopwatchActive && !clocks.timerActive) clocks.toggleStopwatch()
    else clocks.toggleTimer()
  }

  // ------------------------------------------------------------ Left: readout
  Column {
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Row {
      height: island ? island.s(14) : 14
      spacing: island ? island.s(8) : 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.phase
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        font.weight: Font.DemiBold
        color: view.timer || view.stopwatch ? view.tone : island.fgDim
        Behavior on color { ColorAnimation { duration: 140 } }
      }

      Row {
        visible: view.isPomodoro
        anchors.verticalCenter: parent.verticalCenter
        spacing: island ? island.s(3) : 3

        Repeater {
          model: 4

          Rectangle {
            required property int index
            width: island ? island.s(10) : 10
            height: island ? island.s(3) : 3
            radius: height / 2
            color: index < view.activeCycle ? view.tone : Util.alpha(view.fg, 0.14)
          }
        }
      }
    }

    Text {
      id: countdown
      text: view.timeDisplay
      height: island ? island.s(48) : 48
      verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(40) : 40
      font.weight: Font.Medium
      font.letterSpacing: -0.5
      font.features: { "tnum": 1 }
      color: view.timer || view.stopwatch ? view.fg : Util.alpha(view.fg, 0.6)

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.toggle()
      }
    }

    Item { width: 1; height: island ? island.s(6) : 6 }

    // Preset track
    Rectangle {
      width: presetRow.implicitWidth + (island ? island.s(4) : 4)
      height: island ? island.s(22) : 22
      radius: height / 2
      color: Util.alpha(view.fg, 0.05)

      Row {
        id: presetRow
        anchors.centerIn: parent
        spacing: island ? island.s(2) : 2

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
            readonly property bool on: view.timer && modelData.aliases.indexOf(view.clocks.timerLabel) !== -1
            width: chipText.implicitWidth + (island ? island.s(18) : 18)
            height: island ? island.s(18) : 18
            radius: height / 2
            color: on ? Util.alpha(view.tone, 0.16)
              : Util.alpha(view.fg, chipMouse.containsMouse ? 0.07 : 0)
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
              id: chipText
              anchors.centerIn: parent
              text: chip.modelData.label
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              font.weight: chip.on ? Font.DemiBold : Font.Normal
              font.features: { "tnum": 1 }
              color: chip.on ? view.tone : (island ? island.fgDim : "#C1C497")
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
  }

  // ------------------------------------------------------------ Right: ring + play
  Item {
    id: dial
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: parent.verticalCenter
    width: island ? island.s(68) : 68
    height: width

    readonly property real stroke: island ? island.s(3) : 3
    readonly property real r: width / 2 - stroke / 2

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: dial.stroke
        strokeColor: Util.alpha(view.fg, 0.08)
        fillColor: "transparent"
        PathAngleArc {
          centerX: dial.width / 2; centerY: dial.height / 2
          radiusX: dial.r; radiusY: dial.r
          startAngle: -90; sweepAngle: 360
        }
      }

      ShapePath {
        strokeWidth: dial.stroke
        strokeColor: view.tone
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.width / 2; centerY: dial.height / 2
          radiusX: dial.r; radiusY: dial.r
          startAngle: -90
          sweepAngle: view.progress > 0 ? Math.max(1, view.progress * 360) : 0
        }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: island ? island.s(50) : 50
      height: width
      radius: width / 2
      color: view.timer ? view.tone : (island ? island.accentColor : "#2DD5B7")
      scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.04 : 1)
      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 140 } }

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: view.running ? 0 : (island ? island.s(1) : 1)
        text: view.running ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(20) : 20
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

  // ------------------------------------------------------------ Secondary actions
  Row {
    anchors.right: dial.left
    anchors.rightMargin: island ? island.s(12) : 12
    anchors.verticalCenter: dial.verticalCenter
    spacing: island ? island.s(2) : 2

    // +5 min
    Rectangle {
      visible: view.timer
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(28) : 28
      height: width
      radius: width / 2
      color: Util.alpha(view.fg, add5Mouse.pressed ? 0.14 : (add5Mouse.containsMouse ? 0.08 : 0))

      Text {
        anchors.centerIn: parent
        text: "+5"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: add5Mouse.containsMouse ? view.fg : (island ? island.fgDim : "#C1C497")
      }

      MouseArea {
        id: add5Mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (view.clocks) view.clocks.addToTimer(300)
      }
    }

    IconButton {
      visible: view.timer && view.isPomodoro
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒭"
      glyphSize: island ? island.f(14) : 14
      color: island ? island.fgDim : "#C1C497"
      fontFamily: island ? island.fontFamily : "sans-serif"
      onClicked: if (view.clocks) view.clocks.skipPomodoro()
    }

    IconButton {
      visible: view.timer || view.stopwatch
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰅖"
      glyphSize: island ? island.f(13) : 13
      color: island ? island.fgDim : "#C1C497"
      fontFamily: island ? island.fontFamily : "sans-serif"
      onClicked: if (view.clocks) view.clocks.dismissActive()
    }
  }
}
