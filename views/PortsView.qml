import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Listening ports: port number, the app behind it, and what it runs on.
// Rows open in the browser or stop the process (two-step).
Item {
  id: view

  property var island: null
  readonly property int pad: island ? island.s(22) : 22
  property var portsList: []
  property string lastRaw: ""

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
                app: parts[1],
                pid: parts[2],
                dir: parts.length > 3 ? parts[3] : "",
                kind: parts.length > 4 ? parts[4] : ""
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

  function killProcess(pid) {
    if (!pid || pid === "-") return
    Quickshell.execDetached(["kill", "-15", pid])
    refreshTimer.restart()
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

  // ------------------------------------------------------------ Header
  Item {
    id: header
    x: view.pad
    y: island ? island.s(14) : 14
    width: parent.width - view.pad - (island ? island.s(14) : 14)
    height: island ? island.s(28) : 28

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(7) : 7

      Text {
        id: titleText
        text: "Ports"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(13) : 13
        font.weight: Font.DemiBold
        color: island ? island.fg : "#F7E8B2"
      }

      Text {
        visible: view.portsList.length > 0
        anchors.baseline: titleText.baseline
        text: String(view.portsList.length)
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(12) : 12
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
      }
    }

    IconButton {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰑐"
      glyphSize: island ? island.f(13) : 13
      color: island ? island.fgDim : "#C1C497"
      fontFamily: island ? island.fontFamily : "sans-serif"
      onClicked: view.refresh()
    }
  }

  // ------------------------------------------------------------ Empty state
  Text {
    visible: view.portsList.length === 0
    anchors.centerIn: parent
    anchors.verticalCenterOffset: island ? island.s(10) : 10
    text: "No listening ports"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.textFamily : "sans-serif"
    font.pixelSize: island ? island.f(11) : 11
    color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
  }

  // ------------------------------------------------------------ Port rows
  ListView {
    id: list
    x: island ? island.s(12) : 12
    y: header.y + header.height + (island ? island.s(8) : 8)
    width: parent.width - x * 2
    height: parent.height - y - (island ? island.s(16) : 16)
    visible: view.portsList.length > 0
    clip: true
    spacing: 0
    boundsBehavior: Flickable.StopAtBounds
    model: view.portsList

    delegate: Item {
      id: row
      required property var modelData
      required property int index
      property bool confirmingKill: false
      readonly property bool hot: rowHover.hovered || confirmingKill
      readonly property string subtitle: {
        var bits = []
        if (modelData.kind) bits.push(modelData.kind)
        if (modelData.dir) bits.push(modelData.dir)
        return bits.join("  ·  ")
      }

      width: list.width
      height: island ? island.s(42) : 42

      HoverHandler { id: rowHover }

      Rectangle {
        anchors.fill: parent
        radius: island ? island.s(10) : 10
        color: Util.alpha(island ? island.fg : "#F7E8B2", row.hot ? 0.045 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      // Hairline between rows, hidden around the hovered one
      Rectangle {
        visible: row.index > 0 && !row.hot
        x: island ? island.s(10) : 10
        width: parent.width - x * 2
        height: 1
        color: Util.alpha(island ? island.fg : "#F7E8B2", 0.07)
      }

      Text {
        id: portLabel
        x: island ? island.s(10) : 10
        width: island ? island.s(62) : 62
        anchors.verticalCenter: parent.verticalCenter
        text: ":" + row.modelData.port
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : "monospace"
        font.pixelSize: island ? island.f(13) : 13
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: island ? island.accentColor : "#2DD5B7"
      }

      Column {
        anchors.left: portLabel.right
        anchors.right: actions.left
        anchors.rightMargin: island ? island.s(10) : 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: island ? island.s(1) : 1

        Text {
          width: parent.width
          text: row.modelData.app
          elide: Text.ElideRight
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(12) : 12
          font.weight: Font.Medium
          color: island ? island.fg : "#F7E8B2"
        }

        Text {
          visible: row.subtitle !== ""
          width: parent.width
          text: row.subtitle
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(10) : 10
          color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
        }
      }

      Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: island ? island.s(6) : 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: island ? island.s(2) : 2
        opacity: row.hot ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: 120 } }

        IconButton {
          anchors.verticalCenter: parent.verticalCenter
          glyph: "󰏌"
          glyphSize: island ? island.f(13) : 13
          color: island ? island.accentColor : "#2DD5B7"
          fontFamily: island ? island.fontFamily : "sans-serif"
          onClicked: view.openBrowser(row.modelData.port)
        }

        // Stop: close glyph, then a red confirm pill
        Item {
          visible: row.modelData.pid !== "-"
          anchors.verticalCenter: parent.verticalCenter
          width: row.confirmingKill ? stopPill.width : (island ? island.s(26) : 26)
          height: island ? island.s(26) : 26

          IconButton {
            visible: !row.confirmingKill
            anchors.centerIn: parent
            glyph: "󰅖"
            glyphSize: island ? island.f(13) : 13
            color: island ? island.fgDim : "#C1C497"
            fontFamily: island ? island.fontFamily : "sans-serif"
            onClicked: {
              row.confirmingKill = true
              cancelTimer.restart()
            }
          }

          Rectangle {
            id: stopPill
            visible: row.confirmingKill
            anchors.verticalCenter: parent.verticalCenter
            width: stopText.implicitWidth + (island ? island.s(22) : 22)
            height: island ? island.s(24) : 24
            radius: height / 2
            color: Util.alpha(island ? island.urgentColor : "#FF5345", stopMouse.containsMouse ? 0.26 : 0.16)

            Text {
              id: stopText
              anchors.centerIn: parent
              text: "Stop"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.DemiBold
              color: island ? island.urgentColor : "#FF5345"
            }

            MouseArea {
              id: stopMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                view.killProcess(row.modelData.pid)
                row.confirmingKill = false
              }
            }
          }

          Timer {
            id: cancelTimer
            interval: 3000
            onTriggered: row.confirmingKill = false
          }
        }
      }
    }
  }

  ListFade {
    flick: list
    tone: island ? island.surfaceBottom : "black"
    size: island ? island.s(18) : 18
  }
}
