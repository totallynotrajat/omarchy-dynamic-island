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
  readonly property string home: Quickshell.env("HOME") || ""

  function shortDir(d) {
    return home && d.indexOf(home) === 0 ? "~" + d.slice(home.length) : d
  }

  function refresh() {
    portScanner.running = false
    portScanner.running = true
  }

  Process {
    id: portScanner
    running: true
    command: ["python3", Qt.resolvedUrl("../sources/smart-port-scanner.py").toString().replace(/^file:\/\//, "")]
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
  }

  function killProcess(pid, port) {
    if (pid && pid !== "-") {
      Quickshell.execDetached(["kill", "-15", pid])
      view.statusMessage = "Stopped :" + port
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
        text: "Ports"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(13) : 13
        font.weight: Font.DemiBold
        color: island ? island.fg : "#F7E8B2"
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
          text: String(view.portsList.length)
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
      color: refMouse.containsMouse ? Util.alpha(island ? island.fg : "#F7E8B2", 0.15) : "transparent"

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

    Text {
      visible: view.portsList.length === 0
      anchors.centerIn: parent
      text: "No listening ports"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : "sans-serif"
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.fgDim : "#F7E8B2"
      opacity: 0.7
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
        radius: island ? island.s(10) : 10
        color: Util.alpha(island ? island.fg : "#F7E8B2", rowHover.hovered ? 0.08 : 0.04)

        HoverHandler { id: rowHover }

        Row {
          anchors.left: parent.left
          anchors.right: actions.left
          anchors.rightMargin: island ? island.s(8) : 8
          anchors.leftMargin: island ? island.s(8) : 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: island ? island.s(8) : 8

          // Port chip, with a minimum width so names line up
          Rectangle {
            id: portChip
            width: Math.max(island ? island.s(52) : 52, portLabel.implicitWidth + (island ? island.s(12) : 12))
            height: island ? island.s(22) : 22
            radius: height / 2
            color: Util.alpha(island ? island.accentColor : "#2DD5B7", 0.16)
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
            width: parent.width - portChip.width - parent.spacing
            spacing: 1

            Text {
              width: parent.width
              text: portDelegate.modelData.process
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.DemiBold
              color: island ? island.fg : "#F7E8B2"
              elide: Text.ElideRight
            }

            Text {
              visible: text !== ""
              width: parent.width
              text: [view.shortDir(portDelegate.modelData.dir), portDelegate.modelData.pid !== "-" ? portDelegate.modelData.pid : ""]
                .filter(function(t) { return t }).join("  ·  ")
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(9) : 9
              color: island ? island.fgDim : "#F7E8B2"
              elide: Text.ElideMiddle
            }
          }
        }

        // Action Buttons
        Row {
          id: actions
          anchors.right: parent.right
          anchors.rightMargin: island ? island.s(8) : 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: island ? island.s(6) : 6

          // Open in Browser Button
          Rectangle {
            width: island ? island.s(26) : 26
            height: width
            radius: width / 2
            color: Util.alpha(island ? island.accentColor : "#2DD5B7", openMouse.containsMouse ? 0.28 : 0.12)

            Text {
              anchors.centerIn: parent
              text: "󰏌"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(12) : 12
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
            width: portDelegate.confirmingKill ? (confirmText.implicitWidth + (island ? island.s(16) : 16)) : (island ? island.s(26) : 26)
            height: island ? island.s(26) : 26
            radius: height / 2
            color: portDelegate.confirmingKill
              ? Util.alpha(island ? island.urgentColor : "#ff4444", 0.32)
              : Util.alpha(island ? island.urgentColor : "#ff4444", killMouse.containsMouse ? 0.24 : 0.08)

            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Text {
              id: confirmText
              anchors.centerIn: parent
              text: portDelegate.confirmingKill ? "Stop" : "󰅖"
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
