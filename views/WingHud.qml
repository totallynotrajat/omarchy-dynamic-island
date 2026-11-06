import QtQuick
import qs.Commons

// One wing of a transient HUD in the closed notch.
//
// sneak  (volume, brightness, keyboard light, mic): the glyph and what it is
//        on the leading side, a level bar and percent on the trailing side.
// expand (charging, a timer finishing, a track change, toasts): what
//        happened on the leading side, the detail on the trailing side.
//
// HUDs are glances: they take no clicks of their own and the notch does
// not open under the pointer while one is up.
Item {
  id: wing

  property var island: null
  property bool leading: true
  readonly property var hud: island && island.hud ? island.hud : ({})
  readonly property bool sneak: hud.layout === "progress"
  readonly property bool track: hud.layout === "track"
  readonly property color tone: hud.color || (island ? island.fg : "white")
  readonly property real pad: island ? island.s(10) : 10
  readonly property real level: Math.max(0, Math.min(1, Number(hud.value) || 0))

  function sneakName() {
    if (hud.key === "volume") return "Volume"
    if (hud.key === "brightness") return "Brightness"
    var i = String(hud.icon || "")
    if (i === "󰌌" || i === "󰌐") return "Keyboard"
    return hud.label || ""
  }

  // ------------------------------------------------------- leading side
  Row {
    visible: wing.leading
    anchors.left: parent.left
    anchors.leftMargin: wing.pad
    anchors.right: parent.right
    anchors.rightMargin: island ? island.s(6) : 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(7) : 7

    AlbumArt {
      visible: wing.track
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.barHeight - island.s(10) : 18
      height: width
      radius: island ? island.s(4) : 4
      source: island ? island.mediaArt : ""
      tint: island ? island.accentColor : "white"
      fontFamily: island ? island.fontFamily : Style.font.family
    }

    Text {
      id: glyph
      visible: !wing.track
      anchors.verticalCenter: parent.verticalCenter
      text: wing.hud.icon || "󰂚"
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(14) : 14
      color: wing.sneak ? (island ? island.fg : "white") : wing.tone
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - (wing.track ? (island ? island.barHeight - island.s(3) : 25) : glyph.width + parent.spacing)
      elide: Text.ElideRight
      text: wing.sneak ? wing.sneakName()
        : (wing.track ? (island ? island.mediaTitle : "") : (wing.hud.title || wing.hud.label || ""))
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(12) : 12
      font.bold: !wing.sneak
      color: island ? island.fg : "white"
    }
  }

  // ------------------------------------------------------ trailing side
  // sneak: a level bar, then the percent.
  Row {
    visible: !wing.leading && wing.sneak
    anchors.right: parent.right
    anchors.rightMargin: wing.pad
    anchors.left: parent.left
    anchors.leftMargin: island ? island.s(6) : 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(7) : 7

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - pct.width - parent.spacing
      height: island ? island.s(5) : 5
      radius: height / 2
      color: Util.alpha(island ? island.fg : "white", 0.18)

      Rectangle {
        width: Math.round(parent.width * wing.level)
        height: parent.height
        radius: parent.radius
        color: wing.hud.dim ? Util.alpha(island ? island.fg : "white", 0.4) : (island ? island.fg : "white")
        Behavior on width { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }
    }

    Text {
      id: pct
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(30) : 30
      horizontalAlignment: Text.AlignRight
      text: wing.hud.valueText || ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(11) : 11
      font.features: { "tnum": 1 }
      color: island ? island.fgDim : "gray"
    }
  }

  // expand: the detail, right-aligned; a track change also gets the
  // equalizer.
  Row {
    visible: !wing.leading && !wing.sneak
    anchors.right: parent.right
    anchors.rightMargin: wing.pad
    anchors.verticalCenter: parent.verticalCenter
    layoutDirection: Qt.RightToLeft
    spacing: island ? island.s(8) : 8

    Visualizer {
      visible: wing.track
      anchors.verticalCenter: parent.verticalCenter
      playing: !!island && island.mediaPlaying && visible
      color: island ? island.mediaTint : "white"
      bars: 4
      barWidth: island ? Math.max(2, island.s(2)) : 2
      maxHeight: island ? island.s(12) : 12
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, wing.width - wing.pad - (island ? island.s(30) : 30))
      elide: Text.ElideRight
      text: wing.track ? (island ? island.mediaArtist : "") : (wing.hud.body || wing.hud.valueText || "")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(12) : 12
      font.features: { "tnum": 1 }
      color: wing.track ? (island ? island.fgDim : "gray") : wing.tone
    }
  }
}
