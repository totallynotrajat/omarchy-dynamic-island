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
  readonly property int pad: island ? island.s(20) : 20

  // Dragging the scrubber only moves a local preview; the player is sent a
  // single seek when the pointer is released.
  property bool scrubbing: false
  property real scrubFraction: 0
  readonly property real playerProgress: island && island.mediaLength > 0
    ? Math.max(0, Math.min(1, island.mediaPosition / island.mediaLength)) : 0
  readonly property real progress: scrubbing ? scrubFraction : playerProgress
  readonly property real shownPosition: island ? (scrubbing ? scrubFraction * island.mediaLength : island.mediaPosition) : 0

  readonly property real corner: island ? (island.notch ? island.s(26) : island.s(38)) : 26

  Image {
    id: washSource
    visible: false
    width: view.width
    height: view.height
    source: island ? island.mediaArt : ""
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
    opacity: 0.22
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillItem: washTexture
      PathRectangle {
        x: 0; y: 0; width: view.width; height: view.height
        topLeftRadius: island && island.notch ? 0 : view.corner
        topRightRadius: island && island.notch ? 0 : view.corner
        bottomLeftRadius: view.corner
        bottomRightRadius: view.corner
      }
    }
  }

  // Ambient bars along the card floor, inset from the rounded corners and
  // kept under the transport so they never compete with it
  Row {
    id: bgAuraVisualizer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.leftMargin: view.corner + (island ? island.s(2) : 2)
    anchors.right: parent.right
    anchors.rightMargin: view.corner + (island ? island.s(2) : 2)
    height: island ? island.s(22) : 22
    spacing: island ? island.s(3) : 3
    z: 0
    opacity: island && island.mediaPlaying ? 1 : 0.3
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Repeater {
      id: bgBars
      model: 34

      Rectangle {
        required property int index
        property real barLevel: 0.25
        anchors.bottom: parent.bottom
        width: Math.max(2, (bgAuraVisualizer.width - 33 * bgAuraVisualizer.spacing) / 34)
        radius: Math.min(width / 2, island ? island.s(2) : 2)
        height: Math.max(island ? island.s(2) : 2, bgAuraVisualizer.height * (island && island.mediaPlaying ? barLevel : 0.12))
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: Util.alpha(island ? (island.mediaTint || island.accentColor) : "#2DD5B7", 0.22) }
        }
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutSine } }
      }
    }

    Timer {
      interval: 200
      repeat: true
      running: island && island.mediaPlaying && view.visible
      onTriggered: {
        for (var i = 0; i < bgBars.count; i++) {
          var b = bgBars.itemAt(i)
          if (b) b.barLevel = 0.15 + Math.random() * 0.85
        }
      }
    }
  }

  // Row 1: art, title, artist
  AlbumArt {
    id: art
    x: view.pad
    y: island ? island.s(20) : 20
    width: island ? island.s(56) : 56
    height: width
    radius: island ? island.s(12) : 12
    source: island ? island.mediaArt : ""
    tint: island ? island.accentColor : "#2DD5B7"
    fontFamily: island ? island.fontFamily : ""
  }

  Column {
    anchors.left: art.right
    anchors.leftMargin: island ? island.s(14) : 14
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.verticalCenter: art.verticalCenter
    spacing: island ? island.s(3) : 3
    z: 2

    Text {
      width: parent.width
      text: (island && island.mediaTitle) ? island.mediaTitle : "Nothing playing"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island ? island.textFamily : ""
      font.pixelSize: island ? island.f(14) : 14
      font.weight: Font.DemiBold
      color: island ? island.fg : "#F7E8B2"
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: island ? island.mediaArtist : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island ? island.textFamily : ""
      font.pixelSize: island ? island.f(12) : 12
      color: island ? island.fgDim : "#C1C497"
    }
  }

  // Row 2: scrubber, times underneath
  Item {
    id: progressRow
    x: view.pad
    width: parent.width - view.pad * 2
    y: art.y + art.height + (island ? island.s(12) : 12)
    height: island ? island.s(28) : 28
    visible: island && island.mediaLength > 0
    z: 2

    readonly property bool hot: seek.containsMouse || view.scrubbing

    Item {
      id: track
      width: parent.width
      height: island ? island.s(14) : 14

      Rectangle {
        id: rail
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: progressRow.hot ? (island ? island.s(5) : 5) : (island ? island.s(3) : 3)
        radius: height / 2
        color: Util.alpha(island ? island.fg : "#F7E8B2", 0.12)
        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
          id: played
          height: parent.height
          radius: height / 2
          width: Math.max(view.progress > 0 ? height : 0, parent.width * view.progress)
          color: island ? island.accentColor : "#2DD5B7"
        }
      }

      // Playhead knob, only while hovering or scrubbing
      Rectangle {
        readonly property real d: island ? island.s(11) : 11
        width: d
        height: d
        radius: d / 2
        x: Math.max(0, Math.min(track.width - d, played.width - d / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: island ? island.fg : "#F7E8B2"
        opacity: progressRow.hot ? 1 : 0
        scale: progressRow.hot ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }

      MouseArea {
        id: seek
        anchors.fill: parent
        anchors.topMargin: -(island ? island.s(4) : 4)
        anchors.bottomMargin: -(island ? island.s(4) : 4)
        hoverEnabled: true
        enabled: island && island.mediaCanSeek
        cursorShape: (island && island.mediaCanSeek) ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        function fractionAt(x) { return Math.max(0, Math.min(1, x / width)) }

        onPressed: function(mouse) {
          view.scrubFraction = fractionAt(mouse.x)
          view.scrubbing = true
        }
        onPositionChanged: function(mouse) {
          if (view.scrubbing) view.scrubFraction = fractionAt(mouse.x)
        }
        onReleased: function(mouse) {
          if (!view.scrubbing) return
          view.scrubFraction = fractionAt(mouse.x)
          if (island) island.mediaSeek(view.scrubFraction)
          view.scrubbing = false
        }
        onCanceled: view.scrubbing = false
      }
    }

    Text {
      anchors.left: parent.left
      anchors.top: track.bottom
      text: Model.formatTime(view.shownPosition)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : ""
      font.pixelSize: island ? island.f(10) : 10
      font.features: { "tnum": 1 }
      color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
    }

    Text {
      anchors.right: parent.right
      anchors.top: track.bottom
      text: island ? ("-" + Model.formatTime(island.mediaLength - view.shownPosition)) : "-0:00"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.textFamily : ""
      font.pixelSize: island ? island.f(10) : 10
      font.features: { "tnum": 1 }
      color: Util.alpha(island ? island.fg : "#F7E8B2", 0.34)
    }
  }

  // Row 3: transport, output switcher in the right gutter
  Row {
    id: transport
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island ? island.s(18) : 18
    spacing: island ? island.s(18) : 18
    z: 2

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒮"
      glyphSize: island ? island.f(20) : 20
      color: island ? island.fg : "#F7E8B2"
      fontFamily: island ? island.fontFamily : ""
      available: island && island.mediaCanPrevious
      onClicked: if (island) island.mediaPrevious()
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(44) : 44
      height: width
      radius: width / 2
      color: island ? island.accentColor : "#2DD5B7"
      scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.04 : 1)

      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: (island && island.mediaPlaying) ? 0 : (island ? island.s(1) : 1)
        text: (island && island.mediaPlaying) ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : ""
        font.pixelSize: island ? island.f(18) : 18
        color: island ? island.surfaceBottom : "#090F0D"
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (island) island.mediaToggle()
      }
    }

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒭"
      glyphSize: island ? island.f(20) : 20
      color: island ? island.fg : "#F7E8B2"
      fontFamily: island ? island.fontFamily : ""
      available: island && island.mediaCanNext
      onClicked: if (island) island.mediaNext()
    }
  }

  IconButton {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - (island ? island.s(6) : 6)
    anchors.verticalCenter: transport.verticalCenter
    glyph: island ? island.outputGlyph(island.sink) : "󰕾"
    glyphSize: island ? island.f(14) : 14
    color: island ? island.fgDim : "#C1C497"
    fontFamily: island ? island.fontFamily : ""
    z: 2
    onClicked: if (island) island.openOutputs()
  }
}
