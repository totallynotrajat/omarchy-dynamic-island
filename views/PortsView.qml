import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: view

  property var island: null
  readonly property int pad: island ? island.s(18) : 18
  property var portsList: []
  property string lastRaw: ""
  property string statusMessage: ""

  function refresh() {
    portScanner.running = false
    portScanner.running = true
  }

  Process {
    id: portScanner
    running: true
    command: ["python3", Qt.resolvedUrl("../sources/smart-port-scanner.py").replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === view.lastRaw) return
        view.lastRaw = raw
        var items = []
        if (raw.length > 0) {
          var lines = raw.split("\n")
          for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length >= 3) {
              items.push({
                port: parts[0],
                process: parts[1],
                pid: parts[2],
                dir: parts.length > 3 ? parts[3] : ""
              })
            }
          }
        }
        view.portsList = items
      }
    }
  }

  function openBrowser(port) {
    Quickshell.execDetached(["xdg-open", "http://localhost:" + port])
    view.statusMessage = "Opening http://localhost:" + port
    msgTimer.restart()
  }

  function killProcess(pid, port) {
    if (pid && pid !== "-") {
      Quickshell.execDetached(["kill", "-15", pid])
      view.statusMessage = "Sent SIGTERM to PID " + pid + " (:" + port + ")"
      msgTimer.restart()
      refreshTimer.restart()
    }
  }

  Timer {
    id: msgTimer
    interval: 2500
    onTriggered: view.statusMessage = ""
  }

  Timer {
    id: refreshTimer
    interval: 400
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
    height: island ? island.s(24) : 24

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(8) : 8

      Text {
        text: "󰈀"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(15) : 15
        color: island ? island.accentColor : "#2DD5B7"
      }

      Text {
        text: "Port Watcher"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(13) : 13
        font.weight: Font.DemiBold
        color: island ? island.fg : "#ffffff"
      }

      Rectangle {
        width: countText.implicitWidth + (island ? island.s(10) : 10)
        height: island ? island.s(18) : 18
        radius: height / 2
        color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.2)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: countText
          anchors.centerIn: parent
          text: String(view.portsList.length) + " active"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : "sans-serif"
          font.pixelSize: island ? island.f(10) : 10
          font.weight: Font.DemiBold
          color: island ? island.accentColor : "#2DD5B7"
        }
      }
    }

    // Refresh icon button
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(26) : 26
      height: width
      radius: width / 2
      color: refMouse.containsMouse ? Util.alpha(island ? island.fg : "#ffffff", 0.15) : "transparent"

      Text {
        anchors.centerIn: parent
        text: "󰑐"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "sans-serif"
        font.pixelSize: island ? island.f(14) : 14
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
    y: header.y + header.height + (island ? island.s(8) : 8)
    width: parent.width - view.pad * 2
    height: parent.height - y - view.pad - (view.statusMessage !== "" ? (island ? island.s(20) : 20) : 0)

    // Empty State
    Item {
      anchors.fill: parent
      visible: view.portsList.length === 0

      Column {
        anchors.centerIn: parent
        spacing: island ? island.s(4) : 4

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No active dev servers"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(12) : 12
          color: island ? island.fgDim : "#888888"
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Start a server on :3000, :8080 to monitor here"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(10) : 10
          color: island ? island.fgDim : "#888888"
          opacity: 0.6
        }
      }
    }

    // Port Rows
    ListView {
      id: list
      anchors.fill: parent
      visible: view.portsList.length > 0
      clip: true
      spacing: island ? island.s(5) : 5
      boundsBehavior: Flickable.StopAtBounds
      model: view.portsList

      delegate: Rectangle {
        id: portDelegate
        required property var modelData
        property bool confirmingKill: false

        width: list.width
        height: island ? island.s(40) : 40
        radius: island ? island.s(8) : 8
        color: Util.alpha(island ? island.surfaceTop : "#111C18", 0.6)
        border.width: 1
        border.color: Util.alpha(island ? island.rim : "#ffffff", 0.6)

        Row {
          anchors.left: parent.left
          anchors.leftMargin: island ? island.s(8) : 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: island ? island.s(8) : 8

          // Port chip
          Rectangle {
            width: portLabel.implicitWidth + (island ? island.s(10) : 10)
            height: island ? island.s(22) : 22
            radius: island ? island.s(6) : 6
            color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.18)
            border.width: 1
            border.color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.35)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: portLabel
              anchors.centerIn: parent
              text: ":" + portDelegate.modelData.port
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.Bold
              font.features: { "tnum": 1 }
              color: island ? island.accentColor : "#2DD5B7"
            }
          }

          // Process Name & Directory
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: island ? island.s(170) : 170
            spacing: 1

            Text {
              width: parent.width
              text: portDelegate.modelData.process + (portDelegate.modelData.pid !== "-" ? " · " + portDelegate.modelData.pid : "")
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.DemiBold
              color: island ? island.fg : "#ffffff"
              elide: Text.ElideRight
            }

            Text {
              visible: portDelegate.modelData.dir !== ""
              width: parent.width
              text: portDelegate.modelData.dir
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(9) : 9
              color: island ? island.fgDim : "#888888"
              elide: Text.ElideMiddle
            }
          }
        }

        // Action Buttons
        Row {
          anchors.right: parent.right
          anchors.rightMargin: island ? island.s(8) : 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: island ? island.s(6) : 6

          // Open in Browser Button
          Rectangle {
            width: openText.implicitWidth + (island ? island.s(12) : 12)
            height: island ? island.s(24) : 24
            radius: island ? island.s(6) : 6
            color: openMouse.containsMouse ? Util.alpha(island ? island.accentColor : "#2DD5B7", 0.3) : Util.alpha(island ? island.accentColor : "#2DD5B7", 0.12)
            border.width: 1
            border.color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.35)

            Text {
              id: openText
              anchors.centerIn: parent
              text: "Open 󰏌"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              font.weight: Font.Medium
              color: island ? island.accentColor : "#2DD5B7"
            }

            MouseArea {
              id: openMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.openBrowser(portDelegate.modelData.port)
            }
          }

          // Kill Process Button (with Confirmation)
          Rectangle {
            visible: portDelegate.modelData.pid !== "-"
            width: portDelegate.confirmingKill ? (confirmText.implicitWidth + (island ? island.s(12) : 12)) : (island ? island.s(24) : 24)
            height: island ? island.s(24) : 24
            radius: island ? island.s(6) : 6
            color: portDelegate.confirmingKill
              ? Util.alpha(island ? island.urgentColor : "#ff4444", 0.35)
              : (killMouse.containsMouse ? Util.alpha(island ? island.urgentColor : "#ff4444", 0.25) : Util.alpha(island ? island.urgentColor : "#ff4444", 0.1))
            border.width: 1
            border.color: Util.alpha(island ? island.urgentColor : "#ff4444", 0.45)

            Text {
              id: confirmText
              anchors.centerIn: parent
              text: portDelegate.confirmingKill ? "Kill?" : "󰅖"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              font.weight: Font.Bold
              color: island ? island.urgentColor : "#ff4444"
            }

            MouseArea {
              id: killMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!portDelegate.confirmingKill) {
                  portDelegate.confirmingKill = true
                  cancelTimer.restart()
                } else {
                  view.killProcess(portDelegate.modelData.pid, portDelegate.modelData.port)
                  portDelegate.confirmingKill = false
                }
              }
            }

            Timer {
              id: cancelTimer
              interval: 3000
              onTriggered: portDelegate.confirmingKill = false
            }
          }
        }
      }
    }
  }

  // Inline Feedback Banner
  Text {
    visible: view.statusMessage !== ""
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island ? island.s(4) : 4
    anchors.horizontalCenter: parent.horizontalCenter
    text: view.statusMessage
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.textFamily : "sans-serif"
    font.pixelSize: island ? island.f(10) : 10
    color: island ? island.accentColor : "#2DD5B7"
  }
}
