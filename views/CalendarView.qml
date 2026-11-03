import QtQuick
import QtQuick.Controls
import qs.Commons
import "../IslandModel.js" as Model

// Calendar with four modes: Month (grid + selected day), Week (seven
// columns), 3-Day (yesterday / today / tomorrow) and Today (next meeting +
// agenda). The add drawer manages feeds and the holiday calendar.
// Rows lead with the time, then a 2px bar (jade timed, amber all-day).
Item {
  id: view

  property var island: null
  readonly property var cal: island ? island.calendar : null
  readonly property int pad: island ? island.s(18) : 18

  readonly property color fg: island ? island.fg : "#F7E8B2"
  readonly property color faint: Util.alpha(fg, 0.34)
  readonly property color hairline: Util.alpha(fg, 0.07)
  readonly property bool twelveHour: !!(island && island.activeClockFormat && island.activeClockFormat.indexOf("AP") !== -1)
  readonly property int timeColumn: island ? island.s(twelveHour ? 54 : 40) : 40

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

  readonly property date weekStart: {
    var c = currentDate
    var diff = (c.getDay() - firstWeekday + 7) % 7
    return new Date(c.getFullYear(), c.getMonth(), c.getDate() - diff)
  }

  readonly property string contextLabel: {
    if (viewMode === "week") {
      var a = weekStart
      return rangeText(a, new Date(a.getFullYear(), a.getMonth(), a.getDate() + 6))
    }
    if (viewMode === "three-day") {
      var c = currentDate
      return rangeText(new Date(c.getFullYear(), c.getMonth(), c.getDate() - 1),
                       new Date(c.getFullYear(), c.getMonth(), c.getDate() + 1))
    }
    return ""
  }

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
    return Qt.formatDateTime(new Date(t), twelveHour ? "h:mm AP" : "HH:mm")
  }

  // "Nov 2 – 8", or "Oct 30 – Nov 5" across a month boundary
  function rangeText(a, b) {
    if (a.getMonth() === b.getMonth()) return Qt.formatDateTime(a, "MMM d") + " – " + b.getDate()
    return Qt.formatDateTime(a, "MMM d") + " – " + Qt.formatDateTime(b, "MMM d")
  }

  // cal.month() spans a week before and two weeks after the month, which
  // covers every day the Week and 3-Day modes show around today.
  function eventsForDate(targetDate) {
    return currentMonthDays[Model.dayKey(targetDate.getTime())] || []
  }

  function isPast(ev) {
    return !ev.allDay && ev.end < currentDate.getTime()
  }

  // ------------------------------------------------------------ Shared rows
  // Inline components can't see this file's ids, so they take the view in.
  component EventRow: Item {
    id: evRow
    property var host: null
    property var ev: ({})
    property bool compact: false
    readonly property var isl: host ? host.island : null
    readonly property bool linked: !!ev.url

    height: isl ? isl.s(compact ? 32 : 36) : 36
    opacity: host && host.isPast(ev) ? 0.4 : 1

    HoverHandler { id: evHover }

    Rectangle {
      anchors.fill: parent
      radius: isl ? isl.s(10) : 10
      color: Util.alpha(host ? host.fg : "#F7E8B2", evHover.hovered ? 0.045 : 0)
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
      id: evTime
      x: isl ? isl.s(compact ? 6 : 8) : 8
      width: host ? host.timeColumn - (compact ? (isl ? isl.s(6) : 6) : 0) : 40
      anchors.verticalCenter: parent.verticalCenter
      text: evRow.ev.allDay ? "All day" : (host ? host.timeText(evRow.ev.start) : "")
      elide: Text.ElideRight
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: isl ? isl.textFamily : "sans-serif"
      font.pixelSize: isl ? isl.f(evRow.ev.allDay ? 10 : (compact ? 10.5 : 11)) : 11
      font.features: { "tnum": 1 }
      color: isl ? isl.fgDim : "#C1C497"
    }

    Rectangle {
      id: evBar
      anchors.left: evTime.right
      anchors.leftMargin: isl ? isl.s(compact ? 4 : 6) : 6
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(2, isl ? isl.s(2) : 2)
      height: isl ? isl.s(18) : 18
      radius: width / 2
      color: evRow.ev.allDay ? (isl ? isl.orangeColor : "#E5C736") : (isl ? isl.accentColor : "#2DD5B7")
    }

    Text {
      anchors.left: evBar.right
      anchors.leftMargin: isl ? isl.s(compact ? 8 : 10) : 10
      anchors.right: evLink.visible ? evLink.left : parent.right
      anchors.rightMargin: isl ? isl.s(8) : 8
      anchors.verticalCenter: parent.verticalCenter
      text: evRow.ev.title || "Busy"
      elide: Text.ElideRight
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: isl ? isl.textFamily : "sans-serif"
      font.pixelSize: isl ? isl.f(compact ? 11.5 : 12) : 12
      font.weight: Font.Medium
      color: host ? host.fg : "#F7E8B2"
    }

    Text {
      id: evLink
      visible: evRow.linked && !evRow.compact
      anchors.right: parent.right
      anchors.rightMargin: isl ? isl.s(10) : 10
      anchors.verticalCenter: parent.verticalCenter
      text: "󰏌"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: isl ? isl.fontFamily : "sans-serif"
      font.pixelSize: isl ? isl.f(12) : 12
      color: isl ? isl.accentColor : "#2DD5B7"
      opacity: evHover.hovered ? 1 : 0.7
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: evRow.linked ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (evRow.linked && evRow.isl) evRow.isl.openLink(evRow.ev.url)
    }
  }

  component FaintNote: Text {
    property var host: null
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: host && host.island ? host.island.textFamily : "sans-serif"
    font.pixelSize: host && host.island ? host.island.f(11) : 11
    color: host ? host.faint : "#888888"
  }

  // ------------------------------------------------------------ Header
  Item {
    id: topNav
    x: view.pad
    y: island ? island.s(14) : 14
    width: parent.width - view.pad - (island ? island.s(14) : 14)
    height: island ? island.s(28) : 28

    // Segmented mode track
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: tabRow.implicitWidth + (island ? island.s(4) : 4)
      height: island ? island.s(28) : 28
      radius: height / 2
      color: Util.alpha(view.fg, 0.05)

      Row {
        id: tabRow
        anchors.centerIn: parent
        spacing: island ? island.s(2) : 2

        Repeater {
          model: [
            { mode: "month", label: "Month" },
            { mode: "week", label: "Week" },
            { mode: "three-day", label: "3 Day" },
            { mode: "today", label: "Today" }
          ]

          Rectangle {
            id: tabBtn
            required property var modelData
            readonly property bool active: view.viewMode === modelData.mode && !view.adding
            width: tabText.implicitWidth + (island ? island.s(24) : 24)
            height: island ? island.s(24) : 24
            radius: height / 2
            color: active ? Util.alpha(island.accentColor, 0.16)
              : Util.alpha(view.fg, tabMouse.containsMouse ? 0.06 : 0)
            Behavior on color { ColorAnimation { duration: 140 } }

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
    }

    // Context: month + chevrons, a date range, or nothing; then add
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        visible: !view.adding && (view.viewMode === "month" || view.contextLabel !== "")
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: island ? island.s(4) : 4
        text: view.viewMode === "month"
          ? Qt.locale().standaloneMonthName(view.monthIndex) + " " + view.year
          : view.contextLabel
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island ? island.textFamily : "sans-serif"
        font.pixelSize: island ? island.f(12) : 12
        font.weight: view.viewMode === "month" ? Font.DemiBold : Font.Medium
        font.features: { "tnum": 1 }
        color: view.viewMode === "month" ? view.fg : island.fgDim
      }

      IconButton {
        visible: view.viewMode === "month" && !view.adding
        anchors.verticalCenter: parent.verticalCenter
        glyph: "󰅁"
        glyphSize: island ? island.f(13) : 13
        color: island.fgDim
        fontFamily: island ? island.fontFamily : "sans-serif"
        onClicked: view.shiftMonth(-1)
      }

      IconButton {
        visible: view.viewMode === "month" && !view.adding
        anchors.verticalCenter: parent.verticalCenter
        glyph: "󰅂"
        glyphSize: island ? island.f(13) : 13
        color: island.fgDim
        fontFamily: island ? island.fontFamily : "sans-serif"
        onClicked: view.shiftMonth(1)
      }

      Rectangle {
        visible: !view.adding && (view.viewMode === "month" || view.contextLabel !== "")
        anchors.verticalCenter: parent.verticalCenter
        width: 1 + (island ? island.s(12) : 12)
        height: island ? island.s(14) : 14
        color: "transparent"

        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: parent.height
          color: view.hairline
        }
      }

      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: view.adding ? "󰅖" : "󰐕"
        glyphSize: island ? island.f(14) : 14
        color: view.adding ? view.fg : island.fgDim
        fontFamily: island ? island.fontFamily : "sans-serif"
        onClicked: if (island) island.calendarAdding = !island.calendarAdding
      }
    }
  }

  // ------------------------------------------------------------ Content
  Item {
    id: contentArea
    x: view.pad
    y: topNav.y + topNav.height + (island ? island.s(12) : 12)
    width: parent.width - view.pad * 2
    height: parent.height - y - (island ? island.s(18) : 18)

    // ============================================================ MONTH
    Item {
      id: monthContainer
      visible: view.viewMode === "month" && !view.adding
      anchors.fill: parent

      Item {
        id: monthPane
        width: island ? island.s(7 * 32) : 224
        height: parent.height

        Row {
          id: weekdaysRow

          Repeater {
            model: 7
            Text {
              required property int index
              width: island ? island.s(32) : 32
              height: island ? island.s(18) : 18
              horizontalAlignment: Text.AlignHCenter
              text: Qt.locale().dayName((view.firstWeekday + index) % 7, Locale.NarrowFormat)
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.textFamily : "sans-serif"
              font.pixelSize: island ? island.f(10) : 10
              color: view.faint
            }
          }
        }

        Grid {
          y: weekdaysRow.height
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
              height: island ? island.s(32) : 32

              Rectangle {
                anchors.centerIn: parent
                width: island ? island.s(24) : 24
                height: width
                radius: width / 2
                color: cell.isToday ? island.accentColor
                  : Util.alpha(view.fg, dayMouse.containsMouse ? 0.08 : 0)
                border.width: cell.isSelected && !cell.isToday ? Math.max(1, island ? island.s(1.5) : 1.5) : 0
                border.color: island.accentColor
              }

              Text {
                anchors.centerIn: parent
                text: cell.cellDate.getDate()
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(11.5) : 11.5
                font.weight: cell.isToday ? Font.Bold : (cell.isSelected ? Font.DemiBold : Font.Normal)
                font.features: { "tnum": 1 }
                color: cell.isToday ? island.surfaceBottom
                  : (cell.inMonth ? view.fg : Util.alpha(view.fg, 0.22))
              }

              Rectangle {
                visible: cell.busy
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: island ? island.s(1) : 1
                width: island ? island.s(3) : 3
                height: width
                radius: width / 2
                color: island.orangeColor
                opacity: cell.inMonth ? 1 : 0.35
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

      Rectangle {
        x: monthPane.width + (island ? island.s(19) : 19)
        y: island ? island.s(4) : 4
        width: 1
        height: parent.height - y * 2
        color: view.hairline
      }

      // Selected day
      Item {
        anchors.left: monthPane.right
        anchors.leftMargin: island ? island.s(32) : 32
        anchors.right: parent.right
        height: parent.height

        Text {
          id: selectedDayLabel
          x: island ? island.s(8) : 8
          height: island ? island.s(18) : 18
          verticalAlignment: Text.AlignVCenter
          text: Qt.formatDateTime(new Date(view.selected), "ddd, MMM d")
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island ? island.textFamily : "sans-serif"
          font.pixelSize: island ? island.f(12) : 12
          font.weight: Font.DemiBold
          color: view.fg
        }

        ListView {
          anchors.top: selectedDayLabel.bottom
          anchors.topMargin: island ? island.s(6) : 6
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: view.dayEvents

          delegate: EventRow {
            required property var modelData
            width: ListView.view.width
            host: view
            ev: modelData
          }
        }

        FaintNote {
          visible: view.dayEvents.length === 0
          anchors.centerIn: parent
          host: view
          text: "Free"
        }
      }
    }

    // ============================================================ WEEK
    Item {
      id: weekContainer
      visible: view.viewMode === "week" && !view.adding
      anchors.fill: parent

      Row {
        anchors.fill: parent

        Repeater {
          model: 7

          Item {
            id: weekCol
            required property int index
            readonly property date colDate: new Date(view.weekStart.getFullYear(), view.weekStart.getMonth(), view.weekStart.getDate() + index)
            readonly property bool isToday: Model.dayKey(colDate.getTime()) === Model.dayKey(view.currentDate.getTime())
            readonly property var colEvents: view.eventsForDate(colDate)

            width: weekContainer.width / 7
            height: parent.height

            Rectangle {
              visible: weekCol.index > 0
              width: 1
              height: parent.height
              color: view.hairline
            }

            Column {
              id: colHead
              width: parent.width
              topPadding: island ? island.s(2) : 2
              spacing: island ? island.s(3) : 3

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(weekCol.colDate, "ddd").toUpperCase()
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island ? island.textFamily : "sans-serif"
                font.pixelSize: island ? island.f(9) : 9
                font.letterSpacing: 0.7
                color: weekCol.isToday ? island.accentColor : view.faint
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: island ? island.s(24) : 24
                height: width
                radius: width / 2
                color: weekCol.isToday ? island.accentColor : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: weekCol.colDate.getDate()
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island ? island.textFamily : "sans-serif"
                  font.pixelSize: island ? island.f(13) : 13
                  font.weight: Font.DemiBold
                  font.features: { "tnum": 1 }
                  color: weekCol.isToday ? island.surfaceBottom : view.fg
                }
              }
            }

            ListView {
              anchors.top: colHead.bottom
              anchors.topMargin: island ? island.s(8) : 8
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.leftMargin: island ? island.s(4) : 4
              anchors.right: parent.right
              anchors.rightMargin: island ? island.s(4) : 4
              clip: true
              spacing: island ? island.s(4) : 4
              boundsBehavior: Flickable.StopAtBounds
              model: weekCol.colEvents

              delegate: Rectangle {
                id: weekEv
                required property var modelData
                readonly property bool linked: !!modelData.url
                width: ListView.view.width
                height: island ? island.s(34) : 34
                radius: island ? island.s(7) : 7
                opacity: view.isPast(modelData) ? 0.4 : 1
                color: weekCol.isToday
                  ? Util.alpha(island.accentColor, wMouse.containsMouse ? 0.12 : 0.07)
                  : Util.alpha(view.fg, wMouse.containsMouse ? 0.08 : 0.04)
                clip: true

                Rectangle {
                  width: Math.max(2, island ? island.s(2) : 2)
                  height: parent.height
                  color: weekEv.modelData.allDay ? island.orangeColor : island.accentColor
                }

                Column {
                  x: island ? island.s(8) : 8
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - x - (island ? island.s(4) : 4)
                  spacing: island ? island.s(1) : 1

                  Text {
                    width: parent.width
                    text: weekEv.modelData.title || "Busy"
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(10) : 10
                    font.weight: Font.Medium
                    color: view.fg
                  }

                  Text {
                    text: weekEv.modelData.allDay ? "All day" : view.timeText(weekEv.modelData.start)
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: island ? island.textFamily : "sans-serif"
                    font.pixelSize: island ? island.f(9) : 9
                    font.features: { "tnum": 1 }
                    color: island.fgDim
                  }
                }

                MouseArea {
                  id: wMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: weekEv.linked ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: if (weekEv.linked && island) island.openLink(weekEv.modelData.url)
                }
              }
            }
          }
        }
      }
    }

    // ============================================================ 3-DAY
    Item {
      id: threeDayContainer
      visible: view.viewMode === "three-day" && !view.adding
      anchors.fill: parent

      Row {
        anchors.fill: parent
        spacing: island ? island.s(14) : 14

        Repeater {
          model: 3

          Item {
            id: threeDayCol
            required property int index
            readonly property date colDate: {
              var c = view.currentDate
              return new Date(c.getFullYear(), c.getMonth(), c.getDate() - 1 + index)
            }
            readonly property bool isToday: index === 1
            readonly property var colEvents: view.eventsForDate(colDate)

            width: (threeDayContainer.width - 2 * (island ? island.s(14) : 14)) / 3
            height: parent.height

            Item {
              id: tHeader
              width: parent.width
              height: island ? island.s(30) : 30

              Row {
                x: island ? island.s(6) : 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: island ? island.s(6) : 6

                Text {
                  id: dayNum
                  text: threeDayCol.colDate.getDate()
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island ? island.textFamily : "sans-serif"
                  font.pixelSize: island ? island.f(16) : 16
                  font.weight: Font.DemiBold
                  font.features: { "tnum": 1 }
                  color: threeDayCol.isToday ? island.accentColor : view.fg
                }

                Text {
                  anchors.baseline: dayNum.baseline
                  text: threeDayCol.isToday ? "Today" : Qt.formatDateTime(threeDayCol.colDate, "ddd")
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island ? island.textFamily : "sans-serif"
                  font.pixelSize: island ? island.f(11) : 11
                  color: threeDayCol.isToday ? island.accentColor : island.fgDim
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: threeDayCol.isToday ? Util.alpha(island.accentColor, 0.45) : view.hairline
              }
            }

            ListView {
              anchors.top: tHeader.bottom
              anchors.topMargin: island ? island.s(6) : 6
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              model: threeDayCol.colEvents

              delegate: EventRow {
                required property var modelData
                width: ListView.view.width
                host: view
                ev: modelData
                compact: true
              }
            }
          }
        }
      }
    }

    // ============================================================ TODAY
    Item {
      id: todayContainer
      visible: view.viewMode === "today" && !view.adding
      anchors.fill: parent

      // Only show the hero if the next event is actually today
      readonly property var heroEvent: {
        if (!cal || !cal.next) return null
        return Model.dayKey(view.currentDate.getTime()) === Model.dayKey(cal.next.start) ? cal.next : null
      }

      readonly property var agenda: {
        var h = heroEvent
        if (!h) return view.todayEvents
        return view.todayEvents.filter(function(e) { return !(e.start === h.start && e.title === h.title) })
      }

      Rectangle {
        id: heroCard
        visible: !!todayContainer.heroEvent
        width: parent.width
        height: visible ? (island ? island.s(76) : 76) : 0
        radius: island ? island.s(16) : 16
        color: Util.alpha(island.accentColor, 0.07)

        Column {
          x: island ? island.s(16) : 16
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - (joinPill.visible ? joinPill.width + (island ? island.s(28) : 28) : (island ? island.s(16) : 16))
          spacing: island ? island.s(2) : 2

          Text {
            text: todayContainer.heroEvent ? Model.untilText(todayContainer.heroEvent.start, view.currentDate.getTime()) : ""
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(10.5) : 10.5
            font.weight: Font.DemiBold
            color: island.accentColor
          }

          Text {
            width: parent.width
            text: todayContainer.heroEvent ? (todayContainer.heroEvent.title || "Busy") : ""
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(15) : 15
            font.weight: Font.DemiBold
            color: view.fg
          }

          Text {
            text: todayContainer.heroEvent ? view.timeText(todayContainer.heroEvent.start) + " – " + view.timeText(todayContainer.heroEvent.end) : ""
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.features: { "tnum": 1 }
            color: island.fgDim
          }
        }

        Rectangle {
          id: joinPill
          visible: !!(todayContainer.heroEvent && todayContainer.heroEvent.url)
          anchors.right: parent.right
          anchors.rightMargin: island ? island.s(14) : 14
          anchors.verticalCenter: parent.verticalCenter
          width: joinText.implicitWidth + (island ? island.s(30) : 30)
          height: island ? island.s(32) : 32
          radius: height / 2
          color: island.accentColor
          scale: joinMouse.pressed ? 0.95 : (joinMouse.containsMouse ? 1.03 : 1)
          Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

          Text {
            id: joinText
            anchors.centerIn: parent
            text: "Join"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(12) : 12
            font.weight: Font.DemiBold
            color: island.surfaceBottom
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

      ListView {
        anchors.top: heroCard.visible ? heroCard.bottom : parent.top
        anchors.topMargin: heroCard.visible ? (island ? island.s(8) : 8) : 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: todayContainer.agenda

        delegate: EventRow {
          required property var modelData
          width: ListView.view.width
          host: view
          ev: modelData
        }
      }

      FaintNote {
        visible: view.todayEvents.length === 0
        anchors.centerIn: parent
        host: view
        text: "Free today"
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
        model: [{ code: "off", name: "None" }].concat(Model.holidayCalendars)

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
            text: country.modelData.name + (country.modelData.code === view.cal.detectedCountry ? "  ·  local" : "")
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
            text: "󰃭  Holidays  ·  " + (view.cal && view.cal.holidayName ? view.cal.holidayName : "None")
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
