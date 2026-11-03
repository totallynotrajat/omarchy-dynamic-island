import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons

// Shelf: drop files or folders, then copy their path, open a terminal there,
// or take them off the shelf.
Item {
  id: view

  property var island: null
  readonly property int pad: island ? island.s(22) : 22
  readonly property string home: Quickshell.env("HOME") || ""
  property var stagedItems: []

  Process {
    id: shelfCmdRunner
  }

  function prettyDir(p) {
    var dir = String(p).replace(/\/[^\/]*$/, "") || "/"
    if (home && (dir === home || dir.indexOf(home + "/") === 0)) dir = "~" + dir.slice(home.length)
    return dir
  }

  function copyPath(p) {
    // Path goes in as an argument so $ or backticks in names stay literal
    shelfCmdRunner.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", p]
    shelfCmdRunner.running = true
    if (island) island.showHud({
      key: "shelf",
      layout: "toast",
      title: "Path copied",
      message: p,
      icon: "󰆏",
      color: island.accentColor,
      duration: 1500
    })
  }

  function openInTerminal(p, isDir) {
    var dir = isDir ? p : (p.substring(0, p.lastIndexOf("/")) || "/")
    Quickshell.execDetached(["alacritty", "--working-directory", dir])
  }

  function removeItem(index) {
    var copy = []
    for (var i = 0; i < view.stagedItems.length; i++) {
      if (i !== index) copy.push(view.stagedItems[i])
    }
    view.stagedItems = copy
  }

  function clearAll() {
    view.stagedItems = []
  }

  function addPath(p) {
    if (!p) return
    var trimmed = decodeURIComponent(String(p).trim().replace(/^file:\/\//, "")).replace(/(.)\/+$/, "$1")
    var parts = trimmed.split("/")
    var name = parts[parts.length - 1] || trimmed
    var list = view.stagedItems.slice()
    list.unshift({ name: name, path: trimmed, isDir: !name.includes(".") })
    view.stagedItems = list
  }

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
        text: "Shelf"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(13) : 13
        font.weight: Font.DemiBold
        color: island ? island.fg : "#F7E8B2"
      }

      Text {
        visible: view.stagedItems.length > 0
        anchors.baseline: titleText.baseline
        text: String(view.stagedItems.length)
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(12) : 12
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
      }
    }

    Rectangle {
      visible: view.stagedItems.length > 0
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: clearText.implicitWidth + (island ? island.s(20) : 20)
      height: island ? island.s(26) : 26
      radius: height / 2
      color: Util.alpha(island ? island.fg : "#F7E8B2", clearMouse.containsMouse ? 0.08 : 0)

      Text {
        id: clearText
        anchors.centerIn: parent
        text: "Clear"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(11) : 11
        color: clearMouse.containsMouse ? (island ? island.fg : "#F7E8B2") : (island ? island.fgDim : "#C1C497")
      }

      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.clearAll()
      }
    }
  }

  // ------------------------------------------------------------ Drop target + list
  DropArea {
    id: dropArea
    x: island ? island.s(12) : 12
    y: header.y + header.height + (island ? island.s(8) : 8)
    width: parent.width - x * 2
    height: parent.height - y - (island ? island.s(18) : 18)

    onDropped: function(drop) {
      if (drop.hasUrls) {
        for (var i = 0; i < drop.urls.length; i++) view.addPath(drop.urls[i])
        drop.acceptProposedAction()
      }
    }

    // Empty: one dashed target
    Item {
      anchors.fill: parent
      anchors.leftMargin: island ? island.s(6) : 6
      anchors.rightMargin: island ? island.s(6) : 6
      visible: view.stagedItems.length === 0 || dropArea.containsDrag

      Rectangle {
        anchors.fill: parent
        radius: island ? island.s(16) : 16
        color: Util.alpha(island ? island.accentColor : "#2DD5B7", dropArea.containsDrag ? 0.06 : 0)
        Behavior on color { ColorAnimation { duration: 140 } }
      }

      Shape {
        id: dash
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: island ? island.s(16) : 16

        ShapePath {
          strokeWidth: 1
          strokeStyle: ShapePath.DashLine
          dashPattern: [4, 4]
          strokeColor: dropArea.containsDrag
            ? Util.alpha(island ? island.accentColor : "#2DD5B7", 0.6)
            : Util.alpha(island ? island.fg : "#F7E8B2", 0.13)
          fillColor: "transparent"
          PathRectangle {
            x: 0.5; y: 0.5
            width: dash.width - 1; height: dash.height - 1
            radius: dash.r
          }
        }
      }

      Column {
        anchors.centerIn: parent
        spacing: island ? island.s(6) : 6

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰇚"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : "sans-serif"
          font.pixelSize: island ? island.f(20) : 20
          color: dropArea.containsDrag
            ? (island ? island.accentColor : "#2DD5B7")
            : Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Drop files"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(11) : 11
          color: dropArea.containsDrag
            ? (island ? island.accentColor : "#2DD5B7")
            : Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
        }
      }
    }

    ListView {
      id: shelfList
      anchors.fill: parent
      visible: view.stagedItems.length > 0 && !dropArea.containsDrag
      clip: true
      spacing: 0
      boundsBehavior: Flickable.StopAtBounds
      model: view.stagedItems

      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool hot: rowHover.hovered

        width: shelfList.width
        height: island ? island.s(42) : 42

        HoverHandler { id: rowHover }

        Rectangle {
          anchors.fill: parent
          radius: island ? island.s(10) : 10
          color: Util.alpha(island ? island.fg : "#F7E8B2", row.hot ? 0.045 : 0)
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
          visible: row.index > 0 && !row.hot
          x: island ? island.s(10) : 10
          width: parent.width - x * 2
          height: 1
          color: Util.alpha(island ? island.fg : "#F7E8B2", 0.07)
        }

        Text {
          id: kindIcon
          x: island ? island.s(10) : 10
          width: island ? island.s(28) : 28
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.isDir ? "󰉋" : "󰈔"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : "sans-serif"
          font.pixelSize: island ? island.f(15) : 15
          color: row.modelData.isDir ? (island ? island.accentColor : "#2DD5B7") : (island ? island.fgDim : "#C1C497")
        }

        Column {
          anchors.left: kindIcon.right
          anchors.right: actions.left
          anchors.rightMargin: island ? island.s(10) : 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: island ? island.s(1) : 1

          Text {
            width: parent.width
            text: row.modelData.name
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(12) : 12
            font.weight: Font.Medium
            color: island ? island.fg : "#F7E8B2"
          }

          Text {
            width: parent.width
            text: view.prettyDir(row.modelData.path)
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
          opacity: row.hot ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 120 } }

          IconButton {
            glyph: "󰆏"
            glyphSize: island ? island.f(13) : 13
            color: island ? island.fgDim : "#C1C497"
            fontFamily: island ? island.fontFamily : "sans-serif"
            onClicked: view.copyPath(row.modelData.path)
          }

          IconButton {
            glyph: "󰞷"
            glyphSize: island ? island.f(13) : 13
            color: island ? island.fgDim : "#C1C497"
            fontFamily: island ? island.fontFamily : "sans-serif"
            onClicked: view.openInTerminal(row.modelData.path, row.modelData.isDir)
          }

          IconButton {
            glyph: "󰅖"
            glyphSize: island ? island.f(12) : 12
            color: island ? island.fgDim : "#C1C497"
            fontFamily: island ? island.fontFamily : "sans-serif"
            onClicked: view.removeItem(row.index)
          }
        }
      }
    }
  }
}
