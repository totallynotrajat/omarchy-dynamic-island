import QtQuick
import QtQuick.Controls
import qs.Commons
import "../IslandModel.js" as Model

// Calendar View supporting 4 segmented view modes:
// 1. Month: Dual-pane month matrix on the left, selected day events on the right.
// 2. Week: 7-day schedule columns with events and meeting links.
// 3. 3-Day: 3-column timeline (Yesterday / Today / Tomorrow) with meeting cards.
// 4. Today: Focused schedule with a Hero Next Meeting card and Join Call action.
// Zero emojis: strictly clean typography and Material symbols.
Item {
  id: view

  property var island: null
  readonly property var cal: island ? island.calendar : null
  readonly property int pad: island ? island.s(16) : 16

  // Live current date updated across midnight
  property date currentDate: new Date()
  Timer {
    interval: 30000
    repeat: true
    running: view.visible
    triggeredOnStart: true
    onTriggered: view.currentDate = new Date()
  }

  // Month navigation state
  property int year: currentDate.getFullYear()
  property int monthIndex: currentDate.getMonth()
  property double selected: new Date(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate()).getTime()
  readonly property bool adding: island ? island.calendarAdding : false

  // View mode: "month", "week", "three-day", "today"
  property string viewMode: "month"

  // Browsed month map (for Month mode) and Current month map (for Week/3-Day/Today)
  readonly property var days: cal ? cal.month(year, monthIndex) : ({})
  readonly property var currentMonthDays: cal ? cal.month(currentDate.getFullYear(), currentDate.getMonth()) : ({})

  readonly property var dayEvents: days[Model.dayKey(selected)] || []
  readonly property var todayEvents: currentMonthDays[Model.dayKey(currentDate.getTime())] || []
  readonly property bool hasCalendars: cal && cal.sources.length > 0
  property bool pickingHolidays: false

  // Monday or Sunday first, whatever the locale says
  readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
  readonly property int leadingBlanks: (new Date(year, monthIndex, 1).getDay() - firstWeekday + 7) % 7

  onVisibleChanged: {
    if (!visible) return
    currentDate = new Date()
    year = currentDate.getFullYear()
    monthIndex = currentDate.getMonth()
    selected = new Date(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate()).getTime()
    if (adding) Qt.callLater(function() { input.forceActiveFocus() })
  }
  onAddingChanged: {
    pickingHolidays = false
    if (adding && visible) Qt.callLater(function() { input.forceActiveFocus() })
  }

  function shiftMonth(delta) {
    var d = new Date(year, monthIndex + delta, 1)
    year = d.getFullYear()
    monthIndex = d.getMonth()
  }

  function timeText(t) {
    if (!t) return ""
    var fmt = island && island.activeClockFormat && island.activeClockFormat.indexOf("AP") !== -1 ? "h:mm AP" : "HH:mm"
    return Qt.formatDateTime(new Date(t), fmt)
  }

  function eventsForDate(targetDate) {
    var k = Model.dayKey(targetDate.getTime())
    var evs = currentMonthDays[k]
    if (evs) return evs
    if (days[k]) return days[k]
    if (cal && cal.raw) {
      var d0 = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate()).getTime()
      var d1 = d0 + 86400000
      var parsed = Model.parseIcs(cal.raw, d0, d1, true)
      return parsed
    }
    return []
  }

  // ------------------------------------------------------------ Header / Tab Switcher Bar
  Item {
    id: topNav
    x: view.pad
    y: island ? island.s(10) : 10
    width: parent.width - view.pad * 2
    height: island ? island.s(28) : 28

    // Segmented Mode Switcher: [ Month ] [ Week ] [ 3-Day ] [ Today ]
    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(4) : 4

      Repeater {
        model: [
          { mode: "month", label: "Month" },
          { mode: "week", label: "Week" },
          { mode: "three-day", label: "3-Day" },
          { mode: "today", label: "Today" }
        ]

        Rectangle {
          id: tabBtn
          required property var modelData
          readonly property bool active: view.viewMode === modelData.mode
          width: tabText.implicitWidth + (island ? island.s(18) : 18)
          height: island ? island.s(24) : 24
          radius: height / 2
          color: active
            ? Util.alpha(island.accentColor, 0.22)
            : (tabMouse.containsMouse ? Util.alpha(island.fg, 0.08) : "transparent")
          border.width: active ? 1 : 0
          border.color: island.accentColor

          Text {
            id: tabText
            anchors.centerIn: parent
            text: tabBtn.modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.weight: tabBtn.active ? Font.DemiBold : Font.Normal
            color: tabBtn.active ? island.accentColor : island.fgDim
          }

          MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              view.viewMode = tabBtn.modelData.mode
              if (island) island.calendarAdding = false
            }
          }
        }
      }
    }

    // Right Controls: Add Calendar button
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: island ? island.s(6) : 6

      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: view.adding ? "󰅖" : "󰐕"
        glyphSize: island ? island.f(12) : 12
        color: island.fg
        fontFamily: island ? island.fontFamily : "sans-serif"
        onClicked: {
          if (island) island.calendarAdding = !island.calendarAdding
        }
      }
    }
  }

  // ------------------------------------------------------------ Main Content Container
  Item {
    id: contentArea
    x: view.pad
    y: topNav.y + topNav.height + (island ? island.s(8) : 8)
    width: parent.width - view.pad * 2
    height: parent.height - y - (island ? island.s(12) : 12)

    // ============================================================ MODE 1: MONTH (Dual Pane)
    Item {
      id: monthContainer
      visible: view.viewMode === "month" && !view.adding
      anchors.fill: parent

      // Left Column: Month matrix
      Item {
        id: monthPane
        width: island ? island.s(7 * 32) : 224
        height: parent.height

        Item {
          id: monthHeader
          width: parent.width
          height: island ? island.s(24) : 24

          Text {
            anchors.left: parent.left
            anchors.leftMargin: island ? island.s(4) : 4
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().standaloneMonthName(view.monthIndex) + " " + view.year
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(13) : 13
            font.weight: Font.DemiBold
            color: island.fg
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: island ? island.s(4) : 4

            IconButton {
              glyph: "󰅁"
              glyphSize: island ? island.f(11) : 11
              color: island.fg
              fontFamily: island ? island.fontFamily : "sans-serif"
              onClicked: view.shiftMonth(-1)
            }
            IconButton {
              glyph: "󰅂"
              glyphSize: island ? island.f(11) : 11
              color: island.fg
              fontFamily: island ? island.fontFamily : "sans-serif"
              onClicked: view.shiftMonth(1)
            }
          }
        }

        Row {
          id: weekdaysRow
          y: monthHeader.height + (island ? island.s(4) : 4)

          Repeater {
            model: 7
            Text {
              required property int index
              width: island ? island.s(32) : 32
              horizontalAlignment: Text.AlignHCenter
              text: Qt.locale().dayName((view.firstWeekday + index) % 7, Locale.NarrowFormat)
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              color: island.fgDim
            }
          }
        }

        Grid {
          y: weekdaysRow.y + weekdaysRow.height + (island ? island.s(4) : 4)
          columns: 7

          Repeater {
            model: 42

            Item {
              id: cell
              required property int index
              readonly property date cellDate: new Date(view.year, view.monthIndex, 1 - view.leadingBlanks + index)
              readonly property double time: cellDate.getTime()
              readonly property bool inMonth: cellDate.getMonth() === view.monthIndex
              readonly property bool isToday: Model.dayKey(time) === Model.dayKey(view.currentDate.getTime())
              readonly property bool isSelected: time === view.selected
              readonly property bool busy: !!view.days[Model.dayKey(time)]

              width: island ? island.s(32) : 32
              height: island ? island.s(25) : 25

              Rectangle {
                anchors.centerIn: parent
                width: island ? island.s(22) : 22
                height: width
                radius: width / 2
                color: cell.isToday
                  ? island.accentColor
                  : (dayMouse.containsMouse ? Util.alpha(island.fg, 0.1) : "transparent")
                border.width: cell.isSelected && !cell.isToday ? Math.max(1, island ? island.s(1.5) : 1.5) : 0
                border.color: island.accentColor
              }

              Text {
                anchors.centerIn: parent
                text: cell.cellDate.getDate()
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.fontFamily : "sans-serif"
                font.pixelSize: island ? island.f(11) : 11
                font.bold: cell.isToday || cell.isSelected
                font.features: { "tnum": 1 }
                color: cell.isToday ? island.surface : island.fg
                opacity: cell.inMonth ? 1 : 0.3
              }

              Rectangle {
                visible: cell.busy
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: island ? island.s(3.5) : 3.5
                height: width
                radius: width / 2
                color: cell.isToday ? island.fg : island.orangeColor
                opacity: cell.inMonth ? 1 : 0.4
              }

              MouseArea {
                id: dayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  view.selected = cell.time
                  if (island) island.calendarAdding = false
                  if (!cell.inMonth) view.shiftMonth(cell.cellDate < new Date(view.year, view.monthIndex, 1) ? -1 : 1)
                }
              }
            }
          }
        }
      }

      // Right Column: Events for selected day
      Item {
        anchors.left: monthPane.right
        anchors.leftMargin: island ? island.s(16) : 16
        anchors.right: parent.right
        height: parent.height

        Text {
          id: selectedDayLabel
          anchors.top: parent.top
          text: Qt.formatDateTime(new Date(view.selected), "dddd, d MMMM")
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(12) : 12
          font.weight: Font.DemiBold
          color: island.fg
        }

        ListView {
          anchors.top: selectedDayLabel.bottom
          anchors.topMargin: island ? island.s(8) : 8
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          clip: true
          spacing: island ? island.s(4) : 4
          boundsBehavior: Flickable.StopAtBounds
          model: view.dayEvents

          delegate: Rectangle {
            id: eventItem
            required property var modelData
            readonly property bool past: !modelData.allDay && modelData.end < Date.now()
            width: ListView.view.width
            height: island ? island.s(38) : 38
            radius: island ? island.s(10) : 10
            color: Util.alpha(island.fg, evMouse.containsMouse ? 0.09 : 0.04)
            opacity: past ? 0.5 : 1

            Rectangle {
              x: island ? island.s(8) : 8
              anchors.verticalCenter: parent.verticalCenter
              width: island ? island.s(3) : 3
              height: parent.height - (island ? island.s(14) : 14)
              radius: width / 2
              color: eventItem.modelData.allDay ? island.orangeColor : island.accentColor
            }

            Column {
              x: island ? island.s(18) : 18
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - (island ? island.s(26) : 26)
              spacing: 1

              Text {
                width: parent.width
                text: eventItem.modelData.title || "Busy"
                elide: Text.ElideRight
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(11) : 11
                font.weight: Font.DemiBold
                color: island.fg
              }

              Text {
                text: eventItem.modelData.allDay ? "All day"
                  : view.timeText(eventItem.modelData.start) + " – " + view.timeText(eventItem.modelData.end)
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(10) : 10
                color: island.fgDim
              }
            }

            Text {
              visible: !!eventItem.modelData.url
              anchors.right: parent.right
              anchors.rightMargin: island ? island.s(10) : 10
              anchors.verticalCenter: parent.verticalCenter
              text: "󰏌"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(12) : 12
              color: island.accentColor
            }

            MouseArea {
              id: evMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: eventItem.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: if (eventItem.modelData.url && island) island.openLink(eventItem.modelData.url)
            }
          }
        }

        Text {
          visible: view.dayEvents.length === 0
          anchors.centerIn: parent
          text: "No events scheduled"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(11) : 11
          color: island.fgDim
        }
      }
    }

    // ============================================================ MODE 2: WEEK (7 Columns)
    Item {
      id: weekContainer
      visible: view.viewMode === "week" && !view.adding
      anchors.fill: parent

      Row {
        anchors.fill: parent
        spacing: island ? island.s(6) : 6

        Repeater {
          model: 7

          Rectangle {
            id: weekCol
            required property int index
            readonly property date colDate: {
              var curr = view.currentDate
              var diff = (curr.getDay() - view.firstWeekday + 7) % 7
              return new Date(curr.getFullYear(), curr.getMonth(), curr.getDate() - diff + index)
            }
            readonly property bool isToday: Model.dayKey(colDate.getTime()) === Model.dayKey(view.currentDate.getTime())
            readonly property var colEvents: view.eventsForDate(colDate)

            width: (weekContainer.width - 6 * (island ? island.s(6) : 6)) / 7
            height: parent.height
            radius: island ? island.s(10) : 10
            color: isToday
              ? Util.alpha(island.accentColor, 0.08)
              : Util.alpha(island.fg, 0.03)
            border.width: isToday ? 1 : 0
            border.color: Util.alpha(island.accentColor, 0.4)

            // Column Header
            Rectangle {
              id: colHead
              width: parent.width
              height: island ? island.s(26) : 26
              radius: island ? island.s(10) : 10
              color: weekCol.isToday ? island.accentColor : "transparent"

              Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(weekCol.colDate, "ddd d")
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(10) : 10
                font.weight: Font.DemiBold
                color: weekCol.isToday ? island.surface : island.fg
              }
            }

            ListView {
              anchors.top: colHead.bottom
              anchors.topMargin: island ? island.s(4) : 4
              anchors.bottom: parent.bottom
              anchors.bottomMargin: island ? island.s(4) : 4
              anchors.left: parent.left
              anchors.leftMargin: island ? island.s(3) : 3
              anchors.right: parent.right
              anchors.rightMargin: island ? island.s(3) : 3
              clip: true
              spacing: island ? island.s(3) : 3
              boundsBehavior: Flickable.StopAtBounds
              model: weekCol.colEvents

              delegate: Rectangle {
                id: weekEv
                required property var modelData
                width: ListView.view.width
                height: island ? island.s(34) : 34
                radius: island ? island.s(6) : 6
                color: Util.alpha(island.fg, wMouse.containsMouse ? 0.12 : 0.06)

                Column {
                  anchors.fill: parent
                  anchors.margins: island ? island.s(3) : 3
                  spacing: 1

                  Text {
                    width: parent.width
                    text: weekEv.modelData.title || "Busy"
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(9) : 9
                    font.weight: Font.DemiBold
                    color: island.fg
                  }

                  Text {
                    text: weekEv.modelData.allDay ? "All day" : view.timeText(weekEv.modelData.start)
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(8) : 8
                    color: island.accentColor
                  }
                }

                MouseArea {
                  id: wMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: weekEv.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: if (weekEv.modelData.url && island) island.openLink(weekEv.modelData.url)
                }
              }
            }

            Text {
              visible: weekCol.colEvents.length === 0
              anchors.centerIn: parent
              text: "—"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              color: island.fgDim
              opacity: 0.4
            }
          }
        }
      }
    }

    // ============================================================ MODE 3: 3-DAY (Yesterday, Today, Tomorrow)
    Item {
      id: threeDayContainer
      visible: view.viewMode === "three-day" && !view.adding
      anchors.fill: parent

      Row {
        anchors.fill: parent
        spacing: island ? island.s(8) : 8

        Repeater {
          model: 3

          Rectangle {
            id: threeDayCol
            required property int index
            readonly property date colDate: {
              var curr = view.currentDate
              return new Date(curr.getFullYear(), curr.getMonth(), curr.getDate() - 1 + index)
            }
            readonly property bool isToday: index === 1
            readonly property var colEvents: view.eventsForDate(colDate)

            width: (threeDayContainer.width - 2 * (island ? island.s(8) : 8)) / 3
            height: parent.height
            radius: island ? island.s(12) : 12
            color: isToday
              ? Util.alpha(island.accentColor, 0.08)
              : Util.alpha(island.fg, 0.03)
            border.width: isToday ? 1 : 0
            border.color: Util.alpha(island.accentColor, 0.4)

            // Column Header: Yesterday, Today, Tomorrow
            Item {
              id: tHeader
              width: parent.width
              height: island ? island.s(30) : 30

              Text {
                anchors.left: parent.left
                anchors.leftMargin: island ? island.s(10) : 10
                anchors.verticalCenter: parent.verticalCenter
                text: threeDayCol.index === 0 ? "Yesterday" : (threeDayCol.index === 1 ? "Today" : "Tomorrow")
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(12) : 12
                font.weight: Font.DemiBold
                color: threeDayCol.isToday ? island.accentColor : island.fg
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: island ? island.s(10) : 10
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(threeDayCol.colDate, "MMM d")
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(10) : 10
                color: island.fgDim
              }
            }

            ListView {
              anchors.top: tHeader.bottom
              anchors.bottom: parent.bottom
              anchors.bottomMargin: island ? island.s(6) : 6
              anchors.left: parent.left
              anchors.leftMargin: island ? island.s(6) : 6
              anchors.right: parent.right
              anchors.rightMargin: island ? island.s(6) : 6
              clip: true
              spacing: island ? island.s(4) : 4
              boundsBehavior: Flickable.StopAtBounds
              model: threeDayCol.colEvents

              delegate: Rectangle {
                id: threeEv
                required property var modelData
                width: ListView.view.width
                height: island ? island.s(44) : 44
                radius: island ? island.s(8) : 8
                color: Util.alpha(island.fg, tdMouse.containsMouse ? 0.1 : 0.05)

                Rectangle {
                  x: island ? island.s(6) : 6
                  anchors.verticalCenter: parent.verticalCenter
                  width: island ? island.s(3) : 3
                  height: parent.height - (island ? island.s(14) : 14)
                  radius: width / 2
                  color: threeEv.modelData.allDay ? island.orangeColor : island.accentColor
                }

                Column {
                  x: island ? island.s(14) : 14
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - x - (threeEv.modelData.url ? (island ? island.s(28) : 28) : (island ? island.s(8) : 8))
                  spacing: 1

                  Text {
                    width: parent.width
                    text: threeEv.modelData.title || "Busy"
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(11) : 11
                    font.weight: Font.DemiBold
                    color: island.fg
                  }

                  Text {
                    text: threeEv.modelData.allDay ? "All day"
                      : view.timeText(threeEv.modelData.start) + " – " + view.timeText(threeEv.modelData.end)
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(9) : 9
                    color: island.fgDim
                  }
                }

                Text {
                  visible: !!threeEv.modelData.url
                  anchors.right: parent.right
                  anchors.rightMargin: island ? island.s(8) : 8
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰏌"
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island ? island.fontFamily : "sans-serif"
                  font.pixelSize: island ? island.f(12) : 12
                  color: island.accentColor
                }

                MouseArea {
                  id: tdMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: threeEv.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: if (threeEv.modelData.url && island) island.openLink(threeEv.modelData.url)
                }
              }
            }

            Text {
              visible: threeDayCol.colEvents.length === 0
              anchors.centerIn: parent
              text: "No events"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              color: island.fgDim
            }
          }
        }
      }
    }

    // ============================================================ MODE 4: TODAY (Hero Card + Agenda)
    Item {
      id: todayContainer
      visible: view.viewMode === "today" && !view.adding
      anchors.fill: parent

      // Only show hero if the event is actually today
      readonly property var heroEvent: {
        if (!cal || !cal.next) return null
        var nowKey = Model.dayKey(view.currentDate.getTime())
        var nextKey = Model.dayKey(cal.next.start)
        return nowKey === nextKey ? cal.next : null
      }

      // Hero Upcoming Meeting Card
      Rectangle {
        id: heroCard
        anchors.top: parent.top
        width: parent.width
        height: island ? island.s(68) : 68
        radius: island ? island.s(12) : 12
        color: Util.alpha(island.accentColor, 0.12)
        border.width: 1
        border.color: Util.alpha(island.accentColor, 0.35)

        Row {
          x: island ? island.s(12) : 12
          y: island ? island.s(10) : 10
          spacing: island ? island.s(6) : 6

          Rectangle {
            width: island ? island.s(6) : 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: island.accentColor
          }

          Text {
            text: todayContainer.heroEvent ? "UPCOMING MEETING · " + Model.untilText(todayContainer.heroEvent.start, Date.now()) : "NO UPCOMING MEETINGS TODAY"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(10) : 10
            font.weight: Font.DemiBold
            color: island.accentColor
          }
        }

        Column {
          x: island ? island.s(12) : 12
          y: island ? island.s(28) : 28
          width: parent.width - (todayContainer.heroEvent && todayContainer.heroEvent.url ? (island ? island.s(130) : 130) : (island ? island.s(24) : 24))
          spacing: 2

          Text {
            width: parent.width
            text: todayContainer.heroEvent ? todayContainer.heroEvent.title : "Schedule clear for today"
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(13) : 13
            font.weight: Font.DemiBold
            color: island.fg
          }

          Text {
            visible: !!todayContainer.heroEvent
            text: todayContainer.heroEvent ? view.timeText(todayContainer.heroEvent.start) + " – " + view.timeText(todayContainer.heroEvent.end) : ""
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(10) : 10
            color: island.fgDim
          }
        }

        // Join CTA Button
        Rectangle {
          visible: todayContainer.heroEvent && !!todayContainer.heroEvent.url
          anchors.right: parent.right
          anchors.rightMargin: island ? island.s(12) : 12
          anchors.verticalCenter: parent.verticalCenter
          width: joinText.implicitWidth + (island ? island.s(20) : 20)
          height: island ? island.s(30) : 30
          radius: height / 2
          color: joinMouse.pressed ? Qt.darker(island.accentColor, 1.2)
            : (joinMouse.containsMouse ? Qt.lighter(island.accentColor, 1.1) : island.accentColor)

          Text {
            id: joinText
            anchors.centerIn: parent
            text: "Join Call 󰏌"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.weight: Font.DemiBold
            color: island.surface
          }

          MouseArea {
            id: joinMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (todayContainer.heroEvent && todayContainer.heroEvent.url && island) island.openLink(todayContainer.heroEvent.url)
          }
        }
      }

      // Today's Agenda List
      ListView {
        anchors.top: heroCard.bottom
        anchors.topMargin: island ? island.s(8) : 8
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        spacing: island ? island.s(4) : 4
        boundsBehavior: Flickable.StopAtBounds
        model: view.todayEvents

        delegate: Rectangle {
          id: tdEv
          required property var modelData
          width: ListView.view.width
          height: island ? island.s(36) : 36
          radius: island ? island.s(8) : 8
          color: Util.alpha(island.fg, tdAgendaMouse.containsMouse ? 0.09 : 0.04)

          Rectangle {
            x: island ? island.s(8) : 8
            anchors.verticalCenter: parent.verticalCenter
            width: island ? island.s(3) : 3
            height: parent.height - (island ? island.s(14) : 14)
            radius: width / 2
            color: tdEv.modelData.allDay ? island.orangeColor : island.accentColor
          }

          Column {
            x: island ? island.s(18) : 18
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (tdEv.modelData.url ? (island ? island.s(28) : 28) : (island ? island.s(8) : 8))
            spacing: 1

            Text {
              width: parent.width
              text: tdEv.modelData.title || "Busy"
              elide: Text.ElideRight
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.DemiBold
              color: island.fg
            }

            Text {
              text: tdEv.modelData.allDay ? "All day"
                : view.timeText(tdEv.modelData.start) + " – " + view.timeText(tdEv.modelData.end)
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              color: island.fgDim
            }
          }

          Text {
            visible: !!tdEv.modelData.url
            anchors.right: parent.right
            anchors.rightMargin: island ? island.s(10) : 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰏌"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.fontFamily : "sans-serif"
            font.pixelSize: island ? island.f(12) : 12
            color: island.accentColor
          }

          MouseArea {
            id: tdAgendaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: tdEv.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (tdEv.modelData.url && island) island.openLink(tdEv.modelData.url)
          }
        }
      }
    }

    // ============================================================ ADD / HOLIDAYS DRAWER
    Item {
      id: addDrawer
      visible: view.adding
      anchors.fill: parent

      // --- holiday country picker
      ListView {
        id: countries
        visible: view.pickingHolidays
        anchors.fill: parent
        clip: true
        spacing: island ? island.s(3) : 3
        boundsBehavior: Flickable.StopAtBounds
        model: [{ code: "off", name: "No holidays" }].concat(Model.holidayCalendars)

        delegate: Rectangle {
          id: country
          required property var modelData
          readonly property bool chosen: (modelData.code === "off" && view.cal.holidayCountry === "")
            || modelData.code === view.cal.holidayCountry
          width: ListView.view.width
          height: island ? island.s(26) : 26
          radius: height / 2
          color: chosen ? Util.alpha(island.accentColor, 0.22)
            : Util.alpha(island.fg, countryMouse.containsMouse ? 0.1 : 0.03)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: island ? island.s(12) : 12
            anchors.verticalCenter: parent.verticalCenter
            text: country.modelData.name + (country.modelData.code === view.cal.detectedCountry ? "  (your timezone)" : "")
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.bold: country.chosen
            color: island.fg
          }

          MouseArea {
            id: countryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              view.cal.setHolidays(country.modelData.code === view.cal.detectedCountry ? "auto" : country.modelData.code)
              view.pickingHolidays = false
            }
          }
        }
      }

      // --- add / remove calendars
      Column {
        visible: !view.pickingHolidays
        anchors.fill: parent
        spacing: island ? island.s(6) : 6

        Item {
          width: parent.width
          height: island ? island.s(30) : 30

          Rectangle {
            id: pasteButton
            anchors.right: parent.right
            width: pasteLabel.implicitWidth + (island ? island.s(22) : 22)
            height: parent.height
            radius: height / 2
            color: Util.alpha(island.accentColor, pasteMouse.pressed ? 0.34 : (pasteMouse.containsMouse ? 0.26 : 0.18))

            Text {
              id: pasteLabel
              anchors.centerIn: parent
              text: "󰆒 Paste"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              font.weight: Font.DemiBold
              color: island.accentColor
            }

            MouseArea {
              id: pasteMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (island) island.addCalendarFromClipboard()
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: pasteButton.left
            anchors.rightMargin: island ? island.s(6) : 6
            height: parent.height
            radius: height / 2
            color: Util.alpha(island.fg, 0.08)
            border.width: input.activeFocus ? 1 : 0
            border.color: island.accentColor

            TextInput {
              id: input
              anchors.left: parent.left
              anchors.leftMargin: island ? island.s(12) : 12
              anchors.right: parent.right
              anchors.rightMargin: island ? island.s(12) : 12
              anchors.verticalCenter: parent.verticalCenter
              clip: true
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(11) : 11
              color: island.fg
              selectionColor: Util.alpha(island.accentColor, 0.5)
              renderType: Text.NativeRendering
              selectByMouse: true

              function commit() {
                var link = text.trim()
                if (!link) return
                if (island) {
                  island.addCalendar(link)
                  island.calendarAdding = false
                }
                text = ""
              }

              Keys.onReturnPressed: commit()
              Keys.onEnterPressed: commit()
              Keys.onEscapePressed: if (island) island.calendarAdding = false

              Text {
                anchors.fill: parent
                visible: input.text === ""
                text: "Calendar link (.ics)"
                elide: Text.ElideRight
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font: input.font
                color: island.fgDim
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onClicked: input.forceActiveFocus()
              enabled: !input.activeFocus
            }
          }
        }

        // Holidays button
        Rectangle {
          width: parent.width
          height: island ? island.s(26) : 26
          radius: height / 2
          color: Util.alpha(island.orangeColor, holidaysMouse.containsMouse ? 0.24 : 0.14)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: island ? island.s(12) : 12
            anchors.right: parent.right
            anchors.rightMargin: island ? island.s(12) : 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃭  Holidays: " + (view.cal && view.cal.holidayName ? view.cal.holidayName : "off") + "  ›"
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.weight: Font.DemiBold
            color: island.orangeColor
          }

          MouseArea {
            id: holidaysMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.pickingHolidays = true
          }
        }

        // Calendars list
        Repeater {
          model: view.cal ? view.cal.sources.filter(function(l) { return l !== view.cal.holidayLink }) : []

          Rectangle {
            id: source
            required property var modelData
            width: parent.width
            height: island ? island.s(26) : 26
            radius: height / 2
            color: Util.alpha(island.fg, 0.05)

            Text {
              anchors.left: parent.left
              anchors.leftMargin: island ? island.s(12) : 12
              anchors.right: remove.left
              anchors.rightMargin: island ? island.s(6) : 6
              anchors.verticalCenter: parent.verticalCenter
              text: String(source.modelData).replace(/^[a-z]+:\/\//, "").replace(/\?.*$/, "")
              elide: Text.ElideMiddle
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              color: island.fg
            }

            IconButton {
              id: remove
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              glyph: "󰅖"
              glyphSize: island ? island.f(10) : 10
              color: island.fg
              fontFamily: island ? island.fontFamily : "sans-serif"
              onClicked: if (island) island.removeCalendar(source.modelData)
            }
          }
        }
      }
    }
  }
}
