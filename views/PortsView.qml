import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: view

  property var island: null
  readonly property int pad: island ? island.s(18) : 18
  property var portsList: []

  function refresh() {
    portScanner.running = false
    portScanner.running = true
  }

  Process {
    id: portScanner
    running: true
    command: ["python3", "/home/tnr/.config/omarchy/plugins/omarchy-dynamic-island/sources/smart-port-scanner.py"]
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = String(text || "").trim()
        var items = []
        if (raw.length > 0) {
          var lines = raw.split("\n")
          for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length >= 3) {
              items.push({
                port: parts[0],
                process: parts[1],
                pid: parts[2]
              })
            }
          }
        }
        view.portsList = items
      }
    }
  }

  Process {
    id: portActionRunner
  }

  function openBrowser(port) {
    portActionRunner.command = ["xdg-open", "http://localhost:" + port]
    portActionRunner.running = true
    if (island) island.showHud({
      key: "ports",
      layout: "toast",
      title: "Opening Localhost",
      message: "http://localhost:" + port,
      icon: "󰈀",
      color: island.accentColor,
      duration: 1500
    })
  }

  function killProcess(pid, port) {
    if (pid && pid !== "-") {
      portActionRunner.command = ["kill", "-9", pid]
      portActionRunner.running = true
      if (island) island.showHud({
        key: "ports",
        layout: "toast",
        title: "Process Terminated",
        message: "Killed PID " + pid + " on :" + port,
        icon: "󰅖",
        color: island.urgentColor,
        duration: 1600
      })
      refreshTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: 350
    onTriggered: view.refresh()
  }

  Timer {
    interval: 3000
    running: view.visible
    repeat: true
    onTriggered: view.refresh()
  }

  onVisibleChanged: if (visible) refresh()

  // Header Row
  Item {
    id: header
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: island.s(24)

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(8)

      Text {
        text: "󰈀"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(15)
        color: island.accentColor
      }

      Text {
        text: "Port Watcher"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(13)
        font.weight: Font.DemiBold
        color: island.fg
      }

      Rectangle {
        width: countText.implicitWidth + island.s(10)
        height: island.s(18)
        radius: height / 2
        color: Util.alpha(island.accentColor, 0.2)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: countText
          anchors.centerIn: parent
          text: String(view.portsList.length) + " active"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(10)
          font.weight: Font.DemiBold
          color: island.accentColor
        }
      }
    }

    // Refresh icon button
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: island.s(26)
      height: width
      radius: width / 2
      color: refMouse.containsMouse ? Util.alpha(island.fg, 0.15) : "transparent"

      Text {
        anchors.centerIn: parent
        text: "󰑐"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(14)
        color: refMouse.containsMouse ? island.fg : island.fgDim
      }

      MouseArea {
        id: refMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.refresh()
      }
    }
  }

  // Content Area
  Item {
    id: body
    x: view.pad
    y: header.y + header.height + island.s(10)
    width: parent.width - view.pad * 2
    height: parent.height - y - view.pad

    // Empty State
    Item {
      anchors.fill: parent
      visible: view.portsList.length === 0

      Column {
        anchors.centerIn: parent
        spacing: island.s(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No active dev servers"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(13)
          color: island.fgDim
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Start a server on :3000, :8080 to monitor here"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(11)
          color: Util.alpha(island.fg, 0.4)
        }
      }
    }

    // Port Rows
    ListView {
      id: list
      anchors.fill: parent
      visible: view.portsList.length > 0
      clip: true
      spacing: island.s(6)
      model: view.portsList

      delegate: Rectangle {
        required property var modelData
        width: list.width
        height: island.s(36)
        radius: island.s(8)
        color: Util.alpha(island.surfaceTop, 0.6)
        border.width: 1
        border.color: Util.alpha(island.rim, 0.8)

        Row {
          anchors.left: parent.left
          anchors.leftMargin: island.s(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: island.s(10)

          // Port chip
          Rectangle {
            width: portLabel.implicitWidth + island.s(12)
            height: island.s(22)
            radius: island.s(6)
            color: Util.alpha(island.accentColor, 0.18)
            border.width: 1
            border.color: Util.alpha(island.accentColor, 0.35)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: portLabel
              anchors.centerIn: parent
              text: ":" + modelData.port
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.fontFamily
              font.pixelSize: island.f(12)
              font.weight: Font.Bold
              color: island.accentColor
            }
          }

          // Process Name
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.process + (modelData.pid !== "-" ? " (PID " + modelData.pid + ")" : "")
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.textFamily
            font.pixelSize: island.f(12)
            color: island.fg
            elide: Text.ElideRight
            width: island.s(170)
          }
        }

        // Action Buttons
        Row {
          anchors.right: parent.right
          anchors.rightMargin: island.s(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: island.s(6)

          // Open in Browser Button
          Rectangle {
            width: openText.implicitWidth + island.s(12)
            height: island.s(24)
            radius: island.s(6)
            color: openMouse.containsMouse ? Util.alpha(island.accentColor, 0.3) : Util.alpha(island.accentColor, 0.12)
            border.width: 1
            border.color: Util.alpha(island.accentColor, 0.35)

            Text {
              id: openText
              anchors.centerIn: parent
              text: "Open ↗"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(11)
              font.weight: Font.Medium
              color: island.accentColor
            }

            MouseArea {
              id: openMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.openBrowser(modelData.port)
            }
          }

          // Kill Process Button
          Rectangle {
            visible: modelData.pid !== "-"
            width: island.s(24)
            height: island.s(24)
            radius: island.s(6)
            color: killMouse.containsMouse ? Util.alpha(island.urgentColor, 0.3) : Util.alpha(island.urgentColor, 0.1)
            border.width: 1
            border.color: Util.alpha(island.urgentColor, 0.35)

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.fontFamily
              font.pixelSize: island.f(11)
              font.weight: Font.Bold
              color: island.urgentColor
            }

            MouseArea {
              id: killMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.killProcess(modelData.pid, modelData.port)
            }
          }
        }
      }
    }
  }
}
