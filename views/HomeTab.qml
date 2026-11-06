import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.Commons

// The open notch's Home tab, after Boring Notch: the player on the left
// (cover with a soft glow of itself, title, artist, scrubber, controls)
// and the calendar column on the right. "Play on" swaps the player for
// the list of audio outputs.
Item {
  id: home

  property var island: null
  readonly property var player: island ? island.player : null
  readonly property bool showCalendar: !!island && island.setting("calendar", true) !== false
  readonly property real gap: island ? island.s(16) : 16
  readonly property real artSide: Math.min(height - (island ? island.s(6) : 6), island ? island.s(92) : 92)

  // ------------------------------------------------------------ player
  Item {
    id: playerArea
    x: 0
    y: 0
    width: home.showCalendar ? parent.width - calendarArea.width - home.gap : parent.width
    height: parent.height
    visible: !island.outputsOpen

    // Nothing playing.
    Column {
      visible: !island.hasMedia
      anchors.centerIn: parent
      spacing: island.s(4)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "󰝚"
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(26)
        color: island.fgDim
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Nothing playing"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(12)
        color: island.fgDim
      }
    }

    Item {
      id: art
      visible: island.hasMedia
      x: island.s(2)
      anchors.verticalCenter: parent.verticalCenter
      width: home.artSide
      height: width

      // The cover's own glow behind it while playing.
      Image {
        id: glowSource
        anchors.centerIn: parent
        width: parent.width * 1.25
        height: parent.height * 1.3
        source: island.mediaArt
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 64
        sourceSize.height: 64
        asynchronous: true
        visible: false
      }

      MultiEffect {
        source: glowSource
        anchors.fill: glowSource
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        autoPaddingEnabled: true
        opacity: island.mediaPlaying && island.mediaArt ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Style.duration(400) } }
      }

      AlbumArt {
        anchors.fill: parent
        radius: island.s(13)
        source: island.mediaArt
        tint: island.accentColor
        fontFamily: island.fontFamily
        scale: island.mediaPlaying ? 1 : 0.88
        opacity: island.mediaPlaying ? 1 : 0.55
        Behavior on scale { NumberAnimation { duration: Style.duration(260); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Style.duration(260) } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: island.raisePlayer()
      }
    }

    Column {
      id: info
      visible: island.hasMedia
      anchors.left: art.right
      anchors.leftMargin: island.s(14)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(4)

      Marquee {
        width: parent.width
        height: island.s(17)
        text: island.mediaTitle || "Unknown"
        color: island.fg
        fontFamily: island.fontFamily
        pixelSize: island.f(13)
        bold: true
        moving: island.mediaPlaying
        speed: island.s(26)
        gap: island.s(40)
        fadeColor: island.surface
        fadeWidth: island.s(10)
      }

      Marquee {
        width: parent.width
        height: island.s(15)
        text: island.mediaArtist
        color: island.artworkTint ? island.mediaTint : island.fgDim
        fontFamily: island.fontFamily
        pixelSize: island.f(12)
        moving: island.mediaPlaying
        speed: island.s(26)
        gap: island.s(40)
        fadeColor: island.surface
        fadeWidth: island.s(10)
      }

      MusicSlider {
        width: parent.width
        island: home.island
        position: island.mediaPosition
        length: island.mediaLength
        seekable: island.mediaCanSeek
        color: island.artworkTint ? island.mediaTint : island.fg
        onSeek: function(f) { island.mediaSeek(f) }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: island.s(6)

        NotchButton {
          island: home.island
          glyph: "󰒝"
          glyphSize: island.f(14)
          available: !!home.player && home.player.shuffleSupported
          color: home.player && home.player.shuffle ? island.accentColor : island.fg
          onClicked: home.player.shuffle = !home.player.shuffle
        }

        NotchButton {
          island: home.island
          glyph: "󰒮"
          available: island.mediaCanPrevious
          onClicked: island.mediaPrevious()
        }

        NotchButton {
          island: home.island
          glyph: island.mediaPlaying ? "󰏤" : "󰐊"
          glyphSize: island.f(20)
          onClicked: island.mediaToggle()
        }

        NotchButton {
          island: home.island
          glyph: "󰒭"
          available: island.mediaCanNext
          onClicked: island.mediaNext()
        }

        NotchButton {
          island: home.island
          glyph: home.player && home.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
          glyphSize: island.f(14)
          available: !!home.player && home.player.loopSupported
          color: home.player && home.player.loopState !== MprisLoopState.None ? island.accentColor : island.fg
          onClicked: {
            var p = home.player
            p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
              : (p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
          }
        }

        NotchButton {
          island: home.island
          glyph: island.outputGlyph(island.sink)
          glyphSize: island.f(14)
          available: island.audioOutputs.length > 1
          onClicked: island.openOutputs()
        }
      }
    }
  }

  // ------------------------------------------------------------ "Play on"
  Item {
    id: outputs
    visible: island.outputsOpen
    x: 0
    width: playerArea.width
    height: parent.height

    Row {
      id: outputsHead
      spacing: island.s(6)

      NotchButton {
        island: home.island
        glyph: "󰁍"
        glyphSize: island.f(13)
        onClicked: island.closeOutputs()
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "PLAY ON"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(10)
        font.letterSpacing: 1
        font.bold: true
        color: island.fgDim
      }
    }

    ListView {
      id: outputList
      anchors.top: outputsHead.bottom
      anchors.topMargin: island.s(4)
      anchors.bottom: parent.bottom
      width: parent.width
      clip: true
      spacing: island.s(2)
      model: island.audioOutputs
      boundsBehavior: Flickable.StopAtBounds

      delegate: Item {
        id: outRow
        required property var modelData
        readonly property bool current: island.sink === modelData
        width: outputList.width
        height: island.s(30)

        Rectangle {
          anchors.fill: parent
          radius: island.s(8)
          color: Util.alpha(island.fg, outRow.current ? 0.12 : (outMouse.containsMouse ? 0.06 : 0))
        }

        Text {
          id: outGlyph
          x: island.s(10)
          anchors.verticalCenter: parent.verticalCenter
          text: island.outputGlyph(outRow.modelData)
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(14)
          color: outRow.current ? island.accentColor : island.fg
        }

        Text {
          anchors.left: outGlyph.right
          anchors.leftMargin: island.s(10)
          anchors.right: parent.right
          anchors.rightMargin: island.s(10)
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: island.outputLabel(outRow.modelData)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          color: island.fg
        }

        MouseArea {
          id: outMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: island.selectOutput(outRow.modelData)
        }
      }
    }
  }

  // ------------------------------------------------------------ calendar
  DayAgenda {
    id: calendarArea
    visible: home.showCalendar
    anchors.right: parent.right
    width: island.s(208)
    height: parent.height
    island: home.island
  }
}
