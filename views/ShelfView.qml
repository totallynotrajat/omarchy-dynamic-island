import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: view

  property var island: null
  readonly property int pad: island ? island.s(18) : 18
  property var stagedItems: [
    { name: "package.json", path: "/home/tnr/package.json", isDir: false },
    { name: "projects", path: "/home/tnr/projects", isDir: true }
  ]

  Process {
    id: shelfCmdRunner
  }

  function copyPath(p) {
    shelfCmdRunner.command = ["sh", "-c", "printf '%s' " + JSON.stringify(p) + " | wl-copy"]
    shelfCmdRunner.running = true
    if (island) island.showHud({
      key: "shelf",
      layout: "toast",
      title: "Path Copied",
      message: p,
      icon: "󰆏",
      color: island.accentColor,
      duration: 1500
    })
  }

  function openInTerminal(p) {
    shelfCmdRunner.command = ["sh", "-c", "alacritty --working-directory " + JSON.stringify(p) + " &"]
    shelfCmdRunner.running = true
    if (island) island.showHud({
      key: "shelf",
      layout: "toast",
      title: "Terminal Opened",
      message: p,
      icon: "󰞷",
      color: island.accentColor,
      duration: 1500
    })
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
    var trimmed = String(p).trim().replace(/^file:\/\//, "")
    var parts = trimmed.split("/")
    var name = parts[parts.length - 1] || trimmed
    var list = view.stagedItems.slice()
    list.unshift({ name: name, path: trimmed, isDir: !name.includes(".") })
    view.stagedItems = list
    if (island) island.showHud({
      key: "shelf",
      layout: "toast",
      title: "Staged to Shelf",
      message: name,
      icon: "󰉋",
      color: island.accentColor,
      duration: 1400
    })
  }

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
        text: "󰉋"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(15)
        color: island.accentColor
      }

      Text {
        text: "File & Folder Shelf"
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
          text: String(view.stagedItems.length) + " staged"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(10)
          font.weight: Font.DemiBold
          color: island.accentColor
        }
      }
    }

    // Actions
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(8)

      Rectangle {
        visible: view.stagedItems.length > 0
        width: clearText.implicitWidth + island.s(12)
        height: island.s(22)
        radius: island.s(6)
        color: clearMouse.containsMouse ? Util.alpha(island.urgentColor, 0.25) : Util.alpha(island.fg, 0.08)

        Text {
          id: clearText
          anchors.centerIn: parent
          text: "Clear All"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(10)
          color: clearMouse.containsMouse ? island.urgentColor : island.fgDim
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
  }

  // Drop zone / list container
  DropArea {
    id: dropArea
    x: view.pad
    y: header.y + header.height + island.s(10)
    width: parent.width - view.pad * 2
    height: parent.height - y - view.pad

    onDropped: function(drop) {
      if (drop.hasUrls) {
        for (var i = 0; i < drop.urls.length; i++) {
          view.addPath(drop.urls[i])
        }
        drop.acceptProposedAction()
      }
    }

    // Empty state dropzone
    Rectangle {
      anchors.fill: parent
      visible: view.stagedItems.length === 0
      radius: island.s(10)
      color: dropArea.containsDrag ? Util.alpha(island.accentColor, 0.15) : Util.alpha(island.surfaceTop, 0.4)
      border.width: 1
      border.color: dropArea.containsDrag ? island.accentColor : Util.alpha(island.rim, 0.8)

      Column {
        anchors.centerIn: parent
        spacing: island.s(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰉋"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(24)
          color: dropArea.containsDrag ? island.accentColor : island.fgDim
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Drag & drop files or folders here"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(12)
          color: island.fg
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Staged for rapid path copying or CLI operations"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(10)
          color: Util.alpha(island.fg, 0.4)
        }
      }
    }

    // List of Staged items
    ListView {
      id: shelfList
      anchors.fill: parent
      visible: view.stagedItems.length > 0
      clip: true
      spacing: island.s(6)
      model: view.stagedItems

      delegate: Rectangle {
        required property var modelData
        required property int index
        width: shelfList.width
        height: island.s(36)
        radius: island.s(8)
        color: Util.alpha(island.surfaceTop, 0.6)
        border.width: 1
        border.color: Util.alpha(island.rim, 0.8)

        Row {
          anchors.left: parent.left
          anchors.leftMargin: island.s(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: island.s(8)

          Text {
            text: modelData.isDir ? "󰉋" : "󰈔"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(14)
            color: modelData.isDir ? island.accentColor : island.fgDim
          }

          Text {
            text: modelData.name
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.textFamily
            font.pixelSize: island.f(12)
            font.weight: Font.Medium
            color: island.fg
            elide: Text.ElideRight
            width: island.s(160)
          }
        }

        // Action Buttons
        Row {
          anchors.right: parent.right
          anchors.rightMargin: island.s(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: island.s(6)

          // Copy Path
          Rectangle {
            width: copyText.implicitWidth + island.s(10)
            height: island.s(22)
            radius: island.s(6)
            color: copyMouse.containsMouse ? Util.alpha(island.accentColor, 0.25) : Util.alpha(island.fg, 0.08)

            Text {
              id: copyText
              anchors.centerIn: parent
              text: "󰆏 Copy"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(10)
              color: copyMouse.containsMouse ? island.accentColor : island.fgDim
            }

            MouseArea {
              id: copyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.copyPath(modelData.path)
            }
          }

          // Open Terminal (if folder or parent)
          Rectangle {
            width: island.s(22)
            height: island.s(22)
            radius: island.s(6)
            color: termMouse.containsMouse ? Util.alpha(island.accentColor, 0.25) : Util.alpha(island.fg, 0.08)

            Text {
              anchors.centerIn: parent
              text: "󰞷"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.fontFamily
              font.pixelSize: island.f(11)
              color: termMouse.containsMouse ? island.accentColor : island.fgDim
            }

            MouseArea {
              id: termMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.openInTerminal(modelData.path)
            }
          }

          // Remove
          Rectangle {
            width: island.s(22)
            height: island.s(22)
            radius: island.s(6)
            color: remMouse.containsMouse ? Util.alpha(island.urgentColor, 0.25) : Util.alpha(island.fg, 0.08)

            Text {
              anchors.centerIn: parent
              text: "✕"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.fontFamily
              font.pixelSize: island.f(10)
              color: remMouse.containsMouse ? island.urgentColor : island.fgDim
            }

            MouseArea {
              id: remMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.removeItem(index)
            }
          }
        }
      }
    }
  }
}
