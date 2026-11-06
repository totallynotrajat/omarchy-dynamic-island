import QtQuick
import qs.Commons

// The right of the open notch's header: what the system is doing. A volume
// or brightness change, or a message (path copied, charging, a timer done),
// shows here while the notch is open instead of waiting for it to close;
// otherwise recording (click to stop) and the battery.
Item {
  id: status

  property var island: null
  readonly property var hud: island && island.hud && island.hud.layout !== "track" ? island.hud : null
  readonly property bool progress: !!hud && hud.layout === "progress"
  readonly property string message: !hud || progress ? "" : String(hud.title || hud.label || "")
  readonly property real level: hud ? Math.max(0, Math.min(1, Number(hud.value) || 0)) : 0

  implicitHeight: island ? island.s(28) : 28

  // ---- an OSD change while open
  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(7) : 7
    opacity: status.hud ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: status.hud ? (status.hud.icon || "") : ""
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(14) : 14
      color: island ? island.fg : "white"
    }

    Rectangle {
      visible: status.progress
      anchors.verticalCenter: parent.verticalCenter
      width: island ? island.s(70) : 70
      height: island ? island.s(5) : 5
      radius: height / 2
      color: Util.alpha(island ? island.fg : "white", 0.18)

      Rectangle {
        width: Math.round(parent.width * status.level)
        height: parent.height
        radius: parent.radius
        color: island ? island.fg : "white"
        Behavior on width { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: status.progress ? (status.hud.valueText || "") : status.message
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      width: Math.min(implicitWidth, status.width - (island ? island.s(28) : 28))
      elide: Text.ElideRight
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(11) : 11
      font.features: { "tnum": 1 }
      color: status.progress ? (island ? island.fgDim : "gray") : (status.hud && status.hud.color ? status.hud.color : (island ? island.fg : "white"))
    }
  }

  // ---- recording and battery
  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: island ? island.s(4) : 4
    opacity: status.hud ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }

    NotchButton {
      visible: !!island && island.recordingActivity
      anchors.verticalCenter: parent.verticalCenter
      island: status.island
      glyph: "󰻃"
      label: island ? island.formatElapsed(island.recordingElapsed) : ""
      color: island ? island.urgentColor : "red"
      glyphSize: island ? island.f(12) : 12
      onClicked: island.stopRecording()
    }

    Row {
      visible: !!island && island.hasBattery
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(4) : 4
      rightPadding: island ? island.s(4) : 4

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island ? island.batteryPercentText : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(11) : 11
        font.features: { "tnum": 1 }
        color: island ? island.fgDim : "gray"
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: island ? island.batteryGlyph : ""
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(15) : 15
        color: island && island.charging ? island.greenColor
          : (island && island.batteryLevel <= 0.2 ? island.urgentColor : (island ? island.fg : "white"))
      }
    }
  }
}
