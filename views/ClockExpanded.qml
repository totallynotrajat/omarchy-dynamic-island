import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / Pomodoro / stopwatch:
// - Radial progress ring with session phase indicator
// - Large digital readout (never overlapping buttons)
// - Preset duration chips: [ 25m ] [ 50m ] [ 5m ] [ 15m ]
// - Editable task label for the active sprint
// - 4 Cycle progress capsules
// - Transport controls (+5m, Play/Pause, Skip, Dismiss)
// - Zero emojis: clean typography and Material symbols only
Item {
  id: view

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timer: !!(clocks && clocks.timerActive)
  readonly property bool paused: timer ? clocks.timerPaused : (!clocks || !clocks.stopwatchRunning)
  readonly property bool isBreak: !!(clocks && clocks.isPomodoro && (clocks.timerLabel.indexOf("Break") !== -1 || clocks.timerLabel.indexOf("break") !== -1))
  readonly property color tone: paused && !timer ? island.fgDim : (timer ? (isBreak ? island.greenColor : island.orangeColor) : island.accentColor)
  readonly property int pad: island ? island.s(20) : 20

  readonly property string sessionTitle: clocks ? (clocks.timerLabel || (clocks.stopwatchActive ? "Stopwatch" : "Pomodoro Focus")) : "Focus"
  readonly property string timeDisplay: clocks ? (clocks.stopwatchActive ? Model.formatClock(clocks.stopwatchElapsed / 1000, true)
    : Model.formatClock(Math.ceil(clocks.timerLeft / 1000))) : "25:00"

  readonly property real progress: clocks ? clocks.timerProgress : 0
  readonly property int activeCycle: {
    if (!clocks) return 1
    var c = clocks.completedSessions
    return (c % 4 === 0 && c > 0) ? 4 : (c % 4)
  }

  // ------------------------------------------------------------ Left: Radial Dial
  Item {
    id: ringContainer
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    width: island ? island.s(76) : 76
    height: width

    Shape {
      id: ringShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: island ? island.s(4) : 4
        strokeColor: Util.alpha(island ? island.fg : "#ffffff", 0.08)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: ringContainer.width / 2
        startY: island ? island.s(2) : 2
        PathAngleArc {
          centerX: ringContainer.width / 2
          centerY: ringContainer.height / 2
          radiusX: ringContainer.width / 2 - (island ? island.s(2) : 2)
          radiusY: ringContainer.height / 2 - (island ? island.s(2) : 2)
          startAngle: -90
          sweepAngle: 360
        }
      }

      ShapePath {
        strokeWidth: island ? island.s(4) : 4
        strokeColor: view.tone
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: ringContainer.width / 2
        startY: island ? island.s(2) : 2
        PathAngleArc {
          centerX: ringContainer.width / 2
          centerY: ringContainer.height / 2
          radiusX: ringContainer.width / 2 - (island ? island.s(2) : 2)
          radiusY: ringContainer.height / 2 - (island ? island.s(2) : 2)
          startAngle: -90
          sweepAngle: Math.max(1, view.progress * 360)
        }
      }
    }

    Text {
      anchors.centerIn: parent
      text: view.timer ? (view.isBreak ? "" : "󰔛") : "󱎫"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(22) : 22
      color: view.tone
    }
  }

  // ------------------------------------------------------------ Right: Transport Controls
  Row {
    id: buttonRow
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(8) : 8

    // +5m button
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(36) : 36
      height: width
      radius: width / 2
      color: Util.alpha(island ? island.fg : "#ffffff", add5Mouse.containsMouse ? 0.14 : 0.06)

      Text {
        anchors.centerIn: parent
        text: "+5"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        font.weight: Font.DemiBold
        color: island ? island.fg : "#ffffff"
      }

      MouseArea {
        id: add5Mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (view.clocks) view.clocks.addToTimer(300)
      }
    }

    // Play / Pause Primary Button
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(44) : 44
      height: width
      radius: width / 2
      color: playMouse.pressed
        ? Qt.darker(island ? island.accentColor : "#2DD5B7", 1.2)
        : (playMouse.containsMouse ? Qt.lighter(island ? island.accentColor : "#2DD5B7", 1.1) : (island ? island.accentColor : "#2DD5B7"))

      Text {
        anchors.centerIn: parent
        text: view.paused ? "󰐊" : "󰏤"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(18) : 18
        color: island ? island.surface : "#000000"
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!view.clocks) return
          if (view.clocks.stopwatchActive) view.clocks.toggleStopwatch()
          else view.clocks.toggleTimer()
        }
      }
    }

    // Skip Cycle Button
    Rectangle {
      visible: view.timer && view.clocks && view.clocks.isPomodoro
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(36) : 36
      height: width
      radius: width / 2
      color: Util.alpha(island ? island.fg : "#ffffff", skipMouse.containsMouse ? 0.14 : 0.06)

      Text {
        anchors.centerIn: parent
        text: "󰒭"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(14) : 14
        color: island ? island.fg : "#ffffff"
      }

      MouseArea {
        id: skipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (view.clocks) view.clocks.skipPomodoro()
      }
    }

    // Dismiss / Reset Button (resets active timer or stopwatch)
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(36) : 36
      height: width
      radius: width / 2
      color: Util.alpha(island ? island.fg : "#ffffff", dismissMouse.containsMouse ? 0.14 : 0.06)

      Text {
        anchors.centerIn: parent
        text: "󰅖"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(13) : 13
        color: island ? island.fgDim : "#aaaaaa"
      }

      MouseArea {
        id: dismissMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (view.clocks) view.clocks.dismissActive()
      }
    }
  }

  // ------------------------------------------------------------ Center: Readout & Controls
  Item {
    anchors.left: ringContainer.right
    anchors.leftMargin: island ? island.s(14) : 14
    anchors.right: buttonRow.left
    anchors.rightMargin: island ? island.s(14) : 14
    anchors.verticalCenter: parent.verticalCenter
    height: island ? island.s(88) : 88

    // Row 1: Session Status & 4 Cycle Progress Capsules
    Row {
      id: headerRow
      anchors.top: parent.top
      anchors.left: parent.left
      spacing: island ? island.s(8) : 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.sessionTitle.toUpperCase()
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(10) : 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
        color: view.tone
      }

      // 4 Cycle Capsules
      Row {
        visible: view.timer && view.clocks && view.clocks.isPomodoro
        anchors.verticalCenter: parent.verticalCenter
        spacing: island ? island.s(3) : 3

        Repeater {
          model: 4

          Rectangle {
            required property int index
            readonly property bool filled: (index + 1) <= view.activeCycle
            width: island ? island.s(12) : 12
            height: island ? island.s(4) : 4
            radius: height / 2
            color: filled ? view.tone : Util.alpha(island ? island.fg : "#ffffff", 0.15)
          }
        }
      }
    }

    // Row 2: Large Digital Countdown
    Text {
      id: timeText
      anchors.top: headerRow.bottom
      anchors.topMargin: island ? island.s(2) : 2
      anchors.left: parent.left
      anchors.right: parent.right
      elide: Text.ElideRight
      text: view.timeDisplay
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : "sans-serif"
      font.pixelSize: island ? island.f(30) : 30
      font.weight: Font.Medium
      font.features: { "tnum": 1 }
      color: island ? island.fg : "#ffffff"

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!view.clocks) return
          if (view.clocks.stopwatchActive) view.clocks.toggleStopwatch()
          else view.clocks.toggleTimer()
        }
      }
    }

    // Row 3: Presets & Task Label Row
    Row {
      anchors.top: timeText.bottom
      anchors.topMargin: island ? island.s(2) : 2
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: island ? island.s(4) : 4

      // Duration Presets: [ 25m ] [ 50m ] [ 5m ] [ 15m ]
      Repeater {
        model: [
          { min: 25, label: "25m", name: "Focus 25m" },
          { min: 50, label: "50m", name: "Deep Work 50m" },
          { min: 5, label: "5m", name: "Short Break" },
          { min: 15, label: "15m", name: "Long Break" }
        ]

        Rectangle {
          id: pBtn
          required property var modelData
          width: pText.implicitWidth + (island ? island.s(10) : 10)
          height: island ? island.s(18) : 18
          radius: height / 2
          color: Util.alpha(island ? island.fg : "#ffffff", pMouse.containsMouse ? 0.14 : 0.06)

          Text {
            id: pText
            anchors.centerIn: parent
            text: pBtn.modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(9) : 9
            font.weight: Font.Medium
            color: island ? island.fg : "#ffffff"
          }

          MouseArea {
            id: pMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (view.clocks) view.clocks.startTimer(pBtn.modelData.min * 60, pBtn.modelData.name)
            }
          }
        }
      }
    }
  }
}
