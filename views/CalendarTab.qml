import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The open notch's Calendar tab, drawn the way Omarchy's own clock calendar
// is: a month grid with ISO week numbers, letter-spaced small-caps labels,
// today outlined in the accent. Days with events carry a dot; clicking a
// day lists its events on the right. The wheel steps months.
Item {
  id: tab

  property var island: null
  readonly property var cal: island ? island.calendar : null

  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property date selected: today
  // Monday first, like the ISO weeks beside it.
  readonly property int weekStart: 1

  readonly property var monthMap: cal ? cal.month(viewYear, viewMonth) : ({})
  readonly property var selectedEvents: {
    var key = Model.dayKey(selected.getTime())
    if (selected.getFullYear() === viewYear && selected.getMonth() === viewMonth) return monthMap[key] || []
    var m = cal ? cal.month(selected.getFullYear(), selected.getMonth()) : ({})
    return m[key] || []
  }

  function step(n) {
    var d = new Date(viewYear, viewMonth + n, 1)
    viewYear = d.getFullYear()
    viewMonth = d.getMonth()
  }

  function backToToday() {
    today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    selected = today
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  function isoWeek(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    var day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - y0) / 86400000 + 1) / 7)
  }

  // Six rows of seven days, starting on the week that holds the 1st.
  readonly property var weeks: {
    var first = new Date(viewYear, viewMonth, 1)
    var offset = (first.getDay() - weekStart + 7) % 7
    var start = new Date(viewYear, viewMonth, 1 - offset)
    var rows = []
    for (var r = 0; r < 6; r++) {
      var days = []
      for (var c = 0; c < 7; c++) {
        var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + r * 7 + c)
        days.push(d)
      }
      rows.push({ week: isoWeek(days[0]), days: days })
    }
    return rows
  }

  readonly property color labelColor: island ? Util.alpha(island.fg, 0.55) : "gray"
  readonly property real cellW: island ? island.s(26) : 26
  readonly property real cellH: island ? island.s(17) : 17
  readonly property real weekW: island ? island.s(22) : 22

  WheelHandler {
    target: null
    onWheel: function(e) { tab.step(e.angleDelta.y > 0 ? -1 : 1) }
  }

  // ------------------------------------------------------------ month grid
  Column {
    id: grid
    x: 0
    y: 0
    spacing: island ? island.s(1) : 1

    // MONTH YEAR  ‹ ›
    Item {
      width: tab.weekW + 7 * tab.cellW
      height: island ? island.s(20) : 20

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: new Date(tab.viewYear, tab.viewMonth, 1, 12).toLocaleDateString(Qt.locale(), "MMMM yyyy").toUpperCase()
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(11) : 11
        font.letterSpacing: 1
        font.bold: true
        color: island ? island.fg : "white"
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        NotchButton {
          island: tab.island
          glyph: "󰁍"
          glyphSize: island ? island.f(11) : 11
          scale: 0.8
          onClicked: tab.step(-1)
        }

        NotchButton {
          island: tab.island
          glyph: "󰃭"
          glyphSize: island ? island.f(11) : 11
          scale: 0.8
          available: !(tab.viewYear === new Date().getFullYear() && tab.viewMonth === new Date().getMonth())
          onClicked: tab.backToToday()
        }

        NotchButton {
          island: tab.island
          glyph: "󰁔"
          glyphSize: island ? island.f(11) : 11
          scale: 0.8
          onClicked: tab.step(1)
        }
      }
    }

    // WK  MO TU WE ...
    Row {
      Text {
        width: tab.weekW
        height: tab.cellH
        verticalAlignment: Text.AlignVCenter
        text: "WK"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(9) : 9
        font.letterSpacing: 1
        font.bold: true
        color: tab.labelColor
      }

      Repeater {
        model: 7
        Text {
          required property int index
          width: tab.cellW
          height: tab.cellH
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: Qt.locale().dayName((index + tab.weekStart) % 7, Locale.ShortFormat).substring(0, 2).toUpperCase()
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : Style.font.family
          font.pixelSize: island ? island.f(9) : 9
          font.letterSpacing: 1
          font.bold: true
          color: tab.labelColor
        }
      }
    }

    Repeater {
      model: tab.weeks

      Row {
        id: weekRow
        required property var modelData

        Text {
          width: tab.weekW
          height: tab.cellH
          verticalAlignment: Text.AlignVCenter
          text: weekRow.modelData.week
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : Style.font.family
          font.pixelSize: island ? island.f(9) : 9
          font.features: { "tnum": 1 }
          color: Util.alpha(island ? island.fg : "white", 0.35)
        }

        Repeater {
          model: weekRow.modelData.days

          Item {
            id: dayCell
            required property var modelData
            readonly property bool inMonth: modelData.getMonth() === tab.viewMonth
            readonly property bool isToday: tab.sameDay(modelData, new Date())
            readonly property bool isSelected: tab.sameDay(modelData, tab.selected)
            readonly property bool hasEvents: inMonth && (tab.monthMap[Model.dayKey(modelData.getTime())] || []).length > 0
            width: tab.cellW
            height: tab.cellH

            Rectangle {
              anchors.centerIn: parent
              width: parent.width - (island ? island.s(2) : 2)
              height: parent.height
              radius: island ? island.s(4) : 4
              color: dayCell.isSelected && !dayCell.isToday ? Util.alpha(island ? island.fg : "white", 0.12)
                : (dayMouse.containsMouse ? Util.alpha(island ? island.fg : "white", 0.06) : "transparent")
              border.width: dayCell.isToday ? 1 : 0
              border.color: island ? island.accentColor : "white"
            }

            Text {
              anchors.centerIn: parent
              text: dayCell.modelData.getDate()
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : Style.font.family
              font.pixelSize: island ? island.f(11) : 11
              font.bold: dayCell.isToday
              font.features: { "tnum": 1 }
              color: dayCell.isToday ? (island ? island.accentColor : "white")
                : (dayCell.inMonth ? (island ? island.fg : "white") : Util.alpha(island ? island.fg : "white", 0.28))
            }

            Rectangle {
              visible: dayCell.hasEvents
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: island ? island.s(1) : 1
              width: island ? island.s(3) : 3
              height: width
              radius: width / 2
              color: island ? island.accentColor : "white"
            }

            MouseArea {
              id: dayMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: tab.selected = dayCell.modelData
            }
          }
        }
      }
    }
  }

  // Hairline between the grid and the agenda, as in Omarchy's panels.
  Rectangle {
    id: rule
    anchors.left: grid.right
    anchors.leftMargin: island ? island.s(14) : 14
    y: island ? island.s(4) : 4
    width: 1
    height: parent.height - y * 2
    color: Util.alpha(island ? island.fg : "white", 0.1)
  }

  // ------------------------------------------------------------ agenda
  Item {
    id: agenda
    anchors.left: rule.right
    anchors.leftMargin: island ? island.s(14) : 14
    anchors.right: parent.right
    height: parent.height

    Row {
      id: dayHead
      spacing: island ? island.s(8) : 8

      Text {
        anchors.baseline: dayName.baseline
        text: tab.selected.getDate()
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(22) : 22
        font.bold: true
        font.features: { "tnum": 1 }
        color: tab.sameDay(tab.selected, new Date()) ? (island ? island.accentColor : "white") : (island ? island.fg : "white")
      }

      Text {
        id: dayName
        anchors.verticalCenter: parent.verticalCenter
        text: tab.selected.toLocaleDateString(Qt.locale(), "dddd").toUpperCase()
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(10) : 10
        font.letterSpacing: 1
        font.bold: true
        color: tab.labelColor
      }
    }

    Text {
      visible: tab.selectedEvents.length === 0
      anchors.top: dayHead.bottom
      anchors.topMargin: island ? island.s(12) : 12
      text: tab.cal && tab.cal.sources.length === 0 ? "No calendars yet" : "Nothing scheduled"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island ? island.fontFamily : Style.font.family
      font.pixelSize: island ? island.f(11) : 11
      color: island ? island.fgDim : "gray"
    }

    ListView {
      id: list
      anchors.top: dayHead.bottom
      anchors.topMargin: island ? island.s(4) : 4
      anchors.bottom: footer.top
      anchors.bottomMargin: island ? island.s(4) : 4
      width: parent.width
      clip: true
      spacing: island ? island.s(2) : 2
      model: tab.selectedEvents
      boundsBehavior: Flickable.StopAtBounds

      delegate: EventRow {
        required property var modelData
        width: list.width
        island: tab.island
        event: modelData
      }
    }

    // Calendars: how many, and a one-click add from the clipboard (no
    // typing, so the notch never has to take the keyboard).
    Row {
      id: footer
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      spacing: island ? island.s(6) : 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
          if (!tab.cal) return ""
          var n = tab.cal.sources.length
          var holiday = tab.cal.holidayName ? 1 : 0
          var own = Math.max(0, n - holiday)
          return own + (own === 1 ? " calendar" : " calendars") + (tab.cal.holidayName ? " · " + tab.cal.holidayName + " holidays" : "")
        }
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.fontFamily : Style.font.family
        font.pixelSize: island ? island.f(10) : 10
        color: island ? island.fgDim : "gray"
      }

      NotchButton {
        island: tab.island
        glyph: "󰐕"
        label: "Paste link"
        glyphSize: island ? island.f(11) : 11
        scale: 0.9
        onClicked: island.addCalendarFromClipboard()
      }
    }
  }

  Connections {
    target: island
    function onUserExpandedChanged() { if (island.userExpanded) tab.backToToday() }
  }
}
