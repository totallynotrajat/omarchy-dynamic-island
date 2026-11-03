import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / Pomodoro / stopwatch: time large, clickable, and its controls.
// Displays Pomodoro work/break cycles, cycle dots, and rich controls.
Item {
  id: view

  property var island: null
  readonly property var clocks: island ? island.clocks : null
  readonly property bool timer: clocks && clocks.timerActive
  readonly property bool paused: timer ? clocks.timerPaused : (!clocks || !clocks.stopwatchRunning)
  readonly property bool isBreak: clocks && clocks.isPomodoro && (clocks.timerLabel.indexOf("Break") !== -1 || clocks.timerLabel.indexOf("break") !== -1)
  readonly property color tone: paused && !timer ? island.fgDim : (timer ? (isBreak ? island.greenColor : island.orangeColor) : island.accentColor)
  readonly property int pad: island.s(22)

  readonly property string sessionTitle: clocks ? (clocks.timerLabel || (clocks.stopwatchActive ? "Stopwatch" : "Pomodoro Focus")) : "Focus"
  readonly property string timeDisplay: clocks ? (clocks.stopwatchActive ? Model.formatClock(clocks.stopwatchElapsed / 1000, true)
    : Model.formatClock(Math.ceil(clocks.timerLeft / 1000))) : "25:00"

  readonly property real totalDuration: clocks && clocks.timerDuration > 0
    ? clocks.timerDuration : (clocks && clocks.isPomodoro ? (isBreak ? 300000 : 1500000) : 1500000)
  readonly property real progress: timer && totalDuration > 0
    ? Math.max(0, Math.min(1, 1 - (clocks.timerLeft / totalDuration)))
    : (clocks && clocks.stopwatchActive ? ((clocks.stopwatchElapsed % 60000) / 60000) : 0)

  // Subtle radial progress ring on the left
  Item {
    id: ringContainer
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(76)
    height: width

    Shape {
      id: ringShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      // Background track
      ShapePath {
        strokeWidth: island.s(4)
        strokeColor: Util.alpha(island.fg, 0.1)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: ringContainer.width / 2
        startY: island.s(2)
        PathAngleArc {
          centerX: ringContainer.width / 2
          centerY: ringContainer.height / 2
          radiusX: ringContainer.width / 2 - island.s(2)
          radiusY: ringContainer.height / 2 - island.s(2)
          startAngle: -90
          sweepAngle: 360
        }
      }

      // Progress active arc
      ShapePath {
        strokeWidth: island.s(4.5)
        strokeColor: view.tone
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: ringContainer.width / 2
        startY: island.s(2)
        PathAngleArc {
          centerX: ringContainer.width / 2
          centerY: ringContainer.height / 2
          radiusX: ringContainer.width / 2 - island.s(2)
          radiusY: ringContainer.height / 2 - island.s(2)
          startAngle: -90
          sweepAngle: Math.max(2, 360 * view.progress)
        }
      }
    }

    // Glyph / status inside radial progress
    Text {
      anchors.centerIn: parent
      text: clocks && clocks.stopwatchActive ? "󱎫" : (clocks && clocks.isPomodoro ? (view.isBreak ? "" : "") : "󰔛")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(22)
      color: view.tone
    }
  }

  // Center column: Session label, big monospace digits, and cycle capsules
  Column {
    anchors.left: ringContainer.right
    anchors.leftMargin: island.s(16)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(2)

    // Session label & cycle count
    Row {
      spacing: island.s(8)
      anchors.left: parent.left

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: island.s(6)
        height: width
        radius: width / 2
        color: view.tone
        opacity: view.paused ? 0.4 : 1.0

        SequentialAnimation on opacity {
          running: !view.paused
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
        }
      }

      Text {
        text: (clocks && clocks.isPomodoro ? (view.isBreak ? "Break · " : "Focus · ") : "") + view.sessionTitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(12)
        font.weight: Font.DemiBold
        color: view.tone
      }
    }

    // Big Time Readout - Tabular monospace digits, clickable
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
        font.pixelSize: island.f(38)
        font.weight: Font.Light
        font.letterSpacing: -1
        font.features: { "tnum": 1 }
        color: view.tone
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks && clocks.stopwatchActive) {
            clocks.toggleStopwatch()
          } else if (clocks) {
            clocks.toggleTimer()
          }
        }
      }
    }

    // 4 Minimalist cycle progress capsules for Pomodoro
    Row {
      visible: clocks && clocks.isPomodoro
      spacing: island.s(6)
      anchors.left: parent.left

      Repeater {
        model: 4
        Rectangle {
          required property int index
          readonly property bool isCurrent: clocks && index === (clocks.completedSessions % 4)
          readonly property bool isDone: clocks && index < (clocks.completedSessions % 4)

          width: island.s(22)
          height: island.s(4)
          radius: height / 2
          color: isDone ? view.tone : (isCurrent ? Util.alpha(view.tone, 0.7) : Util.alpha(island.fg, 0.15))

          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }
    }
  }

  // Right-hand tactile action buttons
  Row {
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(8)

    // +5 min / Reset stopwatch button
    Rectangle {
      width: island.s(36)
      height: width
      radius: width / 2
      color: Util.alpha(island.fg, addHover.containsMouse ? 0.12 : 0.06)
      border.width: 1
      border.color: Util.alpha(island.fg, 0.1)

      Text {
        anchors.centerIn: parent
        text: clocks && clocks.stopwatchActive ? "󰑓" : "+5m"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: clocks && clocks.stopwatchActive ? island.f(16) : island.f(10)
        font.weight: Font.Medium
        color: island.fg
      }

      MouseArea {
        id: addHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks && clocks.stopwatchActive) clocks.resetStopwatch()
          else if (clocks) clocks.addToTimer(300)
        }
      }
    }

    // Primary Play / Pause disc
    Rectangle {
      id: playBtn
      width: island.s(44)
      height: width
      radius: width / 2
      color: view.tone
      scale: pp.pressed ? 0.92 : (pp.containsMouse ? 1.05 : 1.0)

      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: (view.timer && !view.paused) || (clocks && clocks.stopwatchRunning) ? 0 : island.s(1)
        text: (view.timer && !view.paused) || (clocks && clocks.stopwatchRunning) ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(18)
        color: island.surfaceBottom || "#090F0D"
      }

      MouseArea {
        id: pp
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks && clocks.stopwatchActive) clocks.toggleStopwatch()
          else if (clocks) clocks.toggleTimer()
        }
      }
    }

    // Skip Pomodoro cycle
    Rectangle {
      visible: clocks && clocks.isPomodoro
      width: island.s(36)
      height: width
      radius: width / 2
      color: Util.alpha(island.fg, skipHover.containsMouse ? 0.12 : 0.06)
      border.width: 1
      border.color: Util.alpha(island.fg, 0.1)

      Text {
        anchors.centerIn: parent
        text: "󰒭"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(16)
        color: island.fg
      }

      MouseArea {
        id: skipHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (clocks) clocks.skipPomodoro()
      }
    }

    // Dismiss / Cancel
    Rectangle {
      width: island.s(36)
      height: width
      radius: width / 2
      color: Util.alpha(island.fg, dismissHover.containsMouse ? 0.12 : 0.06)
      border.width: 1
      border.color: Util.alpha(island.fg, 0.1)

      Text {
        anchors.centerIn: parent
        text: "󰅖"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(16)
        color: island.fgDim
      }

      MouseArea {
        id: dismissHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clocks && clocks.isPomodoro) clocks.resetPomodoro()
          else if (view.timer && clocks) clocks.cancelTimer()
          else if (clocks) clocks.resetStopwatch()
          if (island) island.collapse()
        }
      }
    }
  }
}
