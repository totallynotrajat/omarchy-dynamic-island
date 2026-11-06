import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Boring Notch's calendar column: month and year, a strip of days that
// scrolls and snaps to the middle, and the chosen day's events under it.
// Today is the accent dot; the chosen day sits in a soft pill.
Item {
  id: agenda

  property var island: null
  readonly property var cal: island ? island.calendar : null

  property date selected: new Date()
  readonly property double dayMs: 86400000
  // Days shown in the strip: a week back, two weeks ahead.
  readonly property int past: 7
  readonly property int future: 14
  readonly property var days: {
    var out = []
    var t = new Date()
    var base = new Date(t.getFullYear(), t.getMonth(), t.getDate())
    for (var i = -past; i <= future; i++)
      out.push(new Date(base.getFullYear(), base.getMonth(), base.getDate() + i))
    return out
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  // Events for every day the strip (and the chosen day) can show, read once
  // per month touched rather than per cell.
  readonly property var eventMap: {
    if (!cal) return ({})
    var map = {}
    var seen = {}
    var probes = [days[0], days[days.length - 1], selected]
    for (var i = 0; i < probes.length; i++) {
      var k = probes[i].getFullYear() + "-" + probes[i].getMonth()
      if (seen[k]) continue
      seen[k] = true
      var m = cal.month(probes[i].getFullYear(), probes[i].getMonth())
      for (var d in m) if (!map[d]) map[d] = m[d]
    }
    return map
  }
  readonly property var dayEvents: eventMap[Model.dayKey(selected.getTime())] || []

  function reset() {
    selected = new Date()
    strip.positionViewAtIndex(past, ListView.Center)
  }

  Component.onCompleted: reset()

  // ---- month / year
  Column {
    id: heading
    x: 0
    y: 0
    width: island ? island.s(40) : 40

    Text {
      text: agenda.selected.toLocaleDateString(Qt.locale(), "MMM")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(15) : 15
      font.bold: true
      color: island ? island.fg : "white"
    }

    Text {
      text: agenda.selected.getFullYear()
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(13) : 13
      color: island ? island.fgDim : "gray"
    }
  }

  // ---- day strip
  ListView {
    id: strip
    anchors.left: heading.right
    anchors.leftMargin: island ? island.s(4) : 4
    anchors.right: parent.right
    y: 0
    height: island ? island.s(44) : 44
    orientation: ListView.Horizontal
    clip: true
    model: agenda.days
    snapMode: ListView.SnapToItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (width - cellWidth) / 2
    preferredHighlightEnd: (width + cellWidth) / 2
    boundsBehavior: Flickable.StopAtBounds
    readonly property real cellWidth: island ? island.s(30) : 30

    onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < agenda.days.length) agenda.selected = agenda.days[currentIndex]

    delegate: Item {
      id: dayCell
      required property var modelData
      required property int index
      readonly property bool isToday: agenda.sameDay(modelData, new Date())
      readonly property bool isSelected: agenda.sameDay(modelData, agenda.selected)
      readonly property bool hasEvents: (agenda.eventMap[Model.dayKey(modelData.getTime())] || []).length > 0
      width: strip.cellWidth
      height: strip.height

      Rectangle {
        anchors.fill: parent
        anchors.margins: island ? island.s(1) : 1
        radius: island ? island.s(8) : 8
        color: dayCell.isSelected ? Util.alpha(island ? island.fg : "white", 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.duration(140) } }
      }

      Column {
        anchors.centerIn: parent
        spacing: island ? island.s(3) : 3

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: dayCell.modelData.toLocaleDateString(Qt.locale(), "ddd").substring(0, 2)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : Style.font.family
          font.pixelSize: island ? island.f(10) : 10
          color: dayCell.isSelected ? (island ? island.fg : "white") : (island ? island.fgDim : "gray")
        }

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: island ? island.s(20) : 20
          height: width

          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: dayCell.isToday ? (island ? island.accentColor : "white") : "transparent"
          }

          Text {
            anchors.centerIn: parent
            text: dayCell.modelData.getDate()
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.fontFamily : Style.font.family
            font.pixelSize: island ? island.f(12) : 12
            font.bold: dayCell.isToday || dayCell.isSelected
            font.features: { "tnum": 1 }
            color: dayCell.isToday ? (island ? island.surface : "black")
              : (dayCell.isSelected ? (island ? island.fg : "white") : (island ? island.fgDim : "gray"))
          }

          // A day with events gets a dot under its number.
          Rectangle {
            visible: dayCell.hasEvents && !dayCell.isToday
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            width: island ? island.s(3) : 3
            height: width
            radius: width / 2
            color: island ? island.accentColor : "white"
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.currentIndex = dayCell.index
      }
    }
  }

  // Edge fades: the strip melts out at both ends.
  EdgeFade {
    target: strip
    size: island ? island.s(14) : 14
  }

  // ---- the chosen day's events
  Item {
    anchors.top: strip.bottom
    anchors.topMargin: island ? island.s(6) : 6
    anchors.bottom: parent.bottom
    width: parent.width

    Column {
      visible: agenda.dayEvents.length === 0
      anchors.centerIn: parent
      spacing: island ? island.s(2) : 2

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: agenda.sameDay(agenda.selected, new Date()) ? "No events today" : "No events"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(12) : 12
        color: island ? island.fg : "white"
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: agenda.cal && agenda.cal.sources.length === 0 ? "Add a calendar in the Calendar tab" : "Enjoy your free time"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(10) : 10
        color: island ? island.fgDim : "gray"
      }
    }

    ListView {
      id: events
      anchors.fill: parent
      clip: true
      spacing: island ? island.s(2) : 2
      model: agenda.dayEvents
      boundsBehavior: Flickable.StopAtBounds

      delegate: EventRow {
        required property var modelData
        width: events.width
        island: agenda.island
        event: modelData
      }
    }
  }
}
