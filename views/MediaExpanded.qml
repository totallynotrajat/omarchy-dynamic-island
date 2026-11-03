import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import "../IslandModel.js" as Model

// The full player the island opens into: art, title and artist, a seekable
// progress bar with elapsed/remaining time, and transport controls.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(22)
  readonly property real progress: island.mediaLength > 0
    ? Math.max(0, Math.min(1, island.mediaPosition / island.mediaLength)) : 0

  // The cover, blurred into a soft wash behind the player (Apple Music
  // style). Only this backdrop goes through a blur; it is painted into a
  // vector shape with the island's corners, so the edges stay crisp.
  readonly property real corner: island.s(42)

  Image {
    id: washSource
    visible: false
    width: view.width
    height: view.height
    source: island.mediaArt
    sourceSize.width: 96
    sourceSize.height: 96
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  MultiEffect {
    id: washBlur
    width: view.width
    height: view.height
    source: washSource
    blurEnabled: true
    blur: 1.0
    blurMax: 64
    saturation: 0.45
  }

  ShaderEffectSource {
    id: washTexture
    sourceItem: washBlur
    hideSource: true
    visible: false
  }

  Shape {
    anchors.fill: parent
    visible: washSource.status === Image.Ready
    opacity: 0.42
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillItem: washTexture
      PathRectangle {
        x: 0; y: 0; width: view.width; height: view.height
        topLeftRadius: island.notch ? 0 : view.corner
        topRightRadius: island.notch ? 0 : view.corner
        bottomLeftRadius: view.corner
        bottomRightRadius: view.corner
      }
    }
  }

  AlbumArt {
    id: art
    x: view.pad
    y: island.s(20)
    width: island.s(58)
    height: width
    source: island.mediaArt
    tint: island.accentColor
    fontFamily: island.fontFamily
  }

  // Card-Background Integrated Audio Spectrum Visualizer
  // Anchored to the bottom floor of the card and fading ~halfway up
  Row {
    id: bgAuraVisualizer
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(2)
    anchors.left: parent.left
    anchors.leftMargin: island.s(12)
    anchors.right: parent.right
    anchors.rightMargin: island.s(12)
    height: island.s(60)
    spacing: island.s(4)
    z: 0
    opacity: island.mediaPlaying ? 0.35 : 0.12
    Behavior on opacity { NumberAnimation { duration: 300 } }

    Repeater {
      id: bgBars
      model: 28

      Rectangle {
        required property int index
        property real barLevel: 0.35
        anchors.bottom: parent.bottom
        width: Math.max(2, (bgAuraVisualizer.width - 27 * island.s(4)) / 28)
        radius: island.s(2)
        height: Math.max(island.s(4), island.s(55) * (island.mediaPlaying ? barLevel : 0.12))
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.45; color: Util.alpha(island.mediaTint || island.accentColor, 0.25) }
          GradientStop { position: 1.0; color: Util.alpha(island.mediaTint || island.accentColor, 0.75) }
        }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
      }
    }

    Timer {
      interval: 180
      repeat: true
      running: island.mediaPlaying && view.visible
      onTriggered: {
        for (var i = 0; i < bgBars.count; i++) {
          var b = bgBars.itemAt(i)
          if (b) b.barLevel = 0.15 + Math.random() * 0.85
        }
      }
    }
  }

  Column {
    anchors.left: art.right
    anchors.leftMargin: island.s(14)
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: art.verticalCenter
    spacing: island.s(3)
    z: 2

    Text {
      width: parent.width
      text: island.mediaTitle || "Not playing"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(15)
      font.weight: Font.DemiBold
      color: island.fg
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: island.mediaArtist
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(13)
      color: island.fgDim
    }
  }

  // Elapsed · bar · remaining
  Item {
    id: progressRow
    x: view.pad
    width: parent.width - view.pad * 2
    y: art.y + art.height + island.s(16)
    height: island.s(16)
    visible: island.mediaLength > 0

    Text {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Model.formatTime(island.mediaPosition)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      font.features: { "tnum": 1 }
      color: island.fgDim
    }

    Text {
      id: remaining
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "-" + Model.formatTime(island.mediaLength - island.mediaPosition)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      font.features: { "tnum": 1 }
      color: island.fgDim
    }

    Item {
      id: track
      anchors.left: elapsed.right
      anchors.leftMargin: island.s(10)
      anchors.right: remaining.left
      anchors.rightMargin: island.s(10)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height

      readonly property real barHeight: seek.containsMouse ? island.s(7) : island.s(5)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: track.barHeight
        radius: height / 2
        color: Util.alpha(island.fg, 0.16)

        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
          id: played
          height: parent.height
          radius: height / 2
          width: Math.max(view.progress > 0 ? height : 0, parent.width * view.progress)
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Util.alpha(island.fg, 0.55) }
            GradientStop { position: 1; color: island.fg }
          }
        }

        // The playhead.
        Rectangle {
          property real d: seek.containsMouse ? island.s(13) : island.s(9)
          width: d
          height: d
          radius: d / 2
          x: played.width - d / 2
          anchors.verticalCenter: parent.verticalCenter
          color: island.fg
          border.width: Math.max(1, island.s(2))
          border.color: island.bodyAt(0.6)

          Behavior on d { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
      }

      MouseArea {
        id: seek
        anchors.fill: parent
        hoverEnabled: true
        enabled: island.mediaCanSeek
        cursorShape: island.mediaCanSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) { island.mediaSeek(mouse.x / width) }
      }
    }
  }

  // Where the sound goes (speakers, headphones, Bluetooth, HDMI).
  IconButton {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(8)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(16)
    glyph: island.outputGlyph(island.sink)
    glyphSize: island.f(15)
    color: island.fgDim
    fontFamily: island.fontFamily
    onClicked: island.openOutputs()
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(14)
    spacing: island.s(26)

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒮"
      glyphSize: island.f(22)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaCanPrevious
      onClicked: island.mediaPrevious()
    }

    // Play / pause is the one solid control: a disc in the text color.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island.s(44)
      height: width
      radius: width / 2
      color: island.fg
      scale: playMouse.pressed ? 0.9 : (playMouse.containsMouse ? 1.05 : 1)

      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: island.mediaPlaying ? 0 : island.s(1)
        text: island.mediaPlaying ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(22)
        color: island.bodyAt(0.5)
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.mediaToggle()
      }
    }

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒭"
      glyphSize: island.f(22)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaCanNext
      onClicked: island.mediaNext()
    }
  }
}
