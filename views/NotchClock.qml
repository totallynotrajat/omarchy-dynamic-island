import QtQuick
import qs.Commons

// The clock in the middle of the notch: Omarchy's own bar clock, in the
// bar's font, size and text color, so at rest the notch reads as the bar.
// It stays in place in every mode; the notch grows around it.
Item {
  id: clock

  property var island: null

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  TextMetrics {
    id: metrics
    font: label.font
    text: "0"
  }

  Text {
    id: label
    anchors.centerIn: parent
    // Centre the figure height, not the line box (as Omarchy's bar does), so
    // the digits sit on the bar's middle.
    anchors.verticalCenterOffset: Math.round((fm.descent - fm.ascent + metrics.tightBoundingRect.height) / 2)
    text: island ? island.formattedClockText : ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island ? island.fontFamily : Style.font.family
    font.pixelSize: island ? island.clockPixelSize : Style.font.body
    color: island ? island.clockColor : Color.bar.text

    FontMetrics { id: fm; font: label.font }

    Behavior on color { ColorAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
  }
}
