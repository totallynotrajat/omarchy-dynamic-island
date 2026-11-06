import QtQuick
import qs.Commons

// One calendar event: an accent bar, the title, and its time. Events with a
// link (a meeting URL) open it on click.
Item {
  id: row

  property var island: null
  property var event: null
  readonly property bool past: event && !event.allDay && event.end < Date.now()
  readonly property bool hasLink: !!(event && event.url)

  height: island ? island.s(30) : 30

  function timeText() {
    if (!event) return ""
    if (event.allDay) return "All day"
    var s = new Date(event.start), e = new Date(event.end)
    var f = "HH:mm"
    return s.toLocaleTimeString(Qt.locale(), f) + " – " + e.toLocaleTimeString(Qt.locale(), f)
  }

  Rectangle {
    anchors.fill: parent
    radius: island ? island.s(6) : 6
    color: Util.alpha(island ? island.fg : "white", mouse.containsMouse && row.hasLink ? 0.07 : 0)
  }

  Rectangle {
    id: bar
    x: island ? island.s(4) : 4
    anchors.verticalCenter: parent.verticalCenter
    width: island ? island.s(3) : 3
    height: parent.height - (island ? island.s(10) : 10)
    radius: width / 2
    color: row.event && row.event.allDay ? (island ? island.greenColor : "green") : (island ? island.accentColor : "white")
    opacity: row.past ? 0.4 : 1
  }

  Column {
    anchors.left: bar.right
    anchors.leftMargin: island ? island.s(7) : 7
    anchors.right: parent.right
    anchors.rightMargin: island ? island.s(4) : 4
    anchors.verticalCenter: parent.verticalCenter
    opacity: row.past ? 0.5 : 1

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: row.event ? row.event.title : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.fg : "white"
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: row.timeText() + (row.hasLink ? "  󰌷" : "")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(10) : 10
      font.features: { "tnum": 1 }
      color: island ? island.fgDim : "gray"
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: row.hasLink
    cursorShape: row.hasLink ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: island.openLink(row.event.url)
  }
}
