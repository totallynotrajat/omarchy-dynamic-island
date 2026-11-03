import QtQuick
import QtQuick.Controls
import qs.Commons
import "../IslandModel.js" as Model

// Dynamic Island Calendar View with Google Calendar Sync & Multi-View Support.
// Integrates Month view and Agenda view with 1-click meeting join and
// Raycast Glass aesthetics.
Item {
  id: view

  property var island: null
  readonly property var cal: island.calendar
  readonly property int pad: island.s(16)

  readonly property date today: new Date()
  property int year: today.getFullYear()
  property int monthIndex: today.getMonth()
  property double selected: new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime()
  readonly property bool adding: island.calendarAdding

  // View mode: "month" or "agenda"
  property string currentMode: "month"

  readonly property var days: cal.month(year, monthIndex)
  readonly property var dayEvents: days[Model.dayKey(selected)] || []
  readonly property bool hasCalendars: cal.sources.length > 0 || cal.googleEvents.length > 0
  property bool pickingHolidays: false

  // Weekday layout
  readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
  readonly property int leadingBlanks: (new Date(year, monthIndex, 1).getDay() - firstWeekday + 7) % 7

  onVisibleChanged: {
    if (!visible) return
    var t = new Date()
    year = t.getFullYear()
    monthIndex = t.getMonth()
    selected = new Date(t.getFullYear(), t.getMonth(), t.getDate()).getTime()
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
    return Qt.formatDateTime(new Date(t), island.clockFormat.indexOf("AP") !== -1 ? "h:mm AP" : "HH:mm")
  }

  // --------------------------------------------------------------------------
  // TOP BAR: Navigation, View Tabs, Sync Status, Add Button
  // --------------------------------------------------------------------------
  Item {
    id: topNav
    x: view.pad
    y: island.s(10)
    width: parent.width - view.pad * 2
    height: island.s(28)

    // Month & Year title with chevrons
    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(new Date(view.year, view.monthIndex, 1), "MMMM yyyy")
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(14)
        font.weight: Font.DemiBold
        color: island.fg
      }

      IconButton {
        glyph: "󰅁"
        glyphSize: island.f(13)
        color: island.fgDim
        fontFamily: island.fontFamily
        onClicked: view.shiftMonth(-1)
      }

      IconButton {
        glyph: "󰅂"
        glyphSize: island.f(13)
        color: island.fgDim
        fontFamily: island.fontFamily
        onClicked: view.shiftMonth(1)
      }
    }

    // Right Controls: Mode Switcher & Sync / Add
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(8)

      // Google sync chip
      Rectangle {
        height: island.s(22)
        width: syncRow.implicitWidth + island.s(14)
        radius: height / 2
        color: Util.alpha(island.fg, 0.08)

        Row {
          id: syncRow
          anchors.centerIn: parent
          spacing: island.s(5)

          Rectangle {
            width: island.s(6)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: cal.googleConnected ? island.greenColor : island.fgDim
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: cal.googleSyncing ? "Syncing…" : "Google"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.textFamily
            font.pixelSize: island.f(10)
            color: island.fgDim
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.resyncGoogle()
        }
      }

      // Mode Switcher: [ Month | Agenda ]
      Rectangle {
        height: island.s(24)
        width: island.s(128)
        radius: height / 2
        color: Util.alpha(island.fg, 0.1)

        Row {
          anchors.fill: parent

          // Month Tab
          Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: height / 2
            color: view.currentMode === "month" ? island.accentColor : "transparent"

            Text {
              anchors.centerIn: parent
              text: "Month"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(11)
              font.weight: view.currentMode === "month" ? Font.DemiBold : Font.Normal
              color: view.currentMode === "month" ? "#ffffff" : island.fgDim
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: view.currentMode = "month"
            }
          }

          // Agenda Tab
          Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: height / 2
            color: view.currentMode === "agenda" ? island.accentColor : "transparent"

            Text {
              anchors.centerIn: parent
              text: "Agenda"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(11)
              font.weight: view.currentMode === "agenda" ? Font.DemiBold : Font.Normal
              color: view.currentMode === "agenda" ? "#ffffff" : island.fgDim
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: view.currentMode = "agenda"
            }
          }
        }
      }

      // Focus Pomodoro shortcut
      IconButton {
        glyph: ""
        glyphSize: island.f(14)
        color: island.orangeColor
        fontFamily: island.fontFamily
        onClicked: island.openFocusd()
      }

      // Add Calendar Link
      IconButton {
        glyph: "󰐕"
        glyphSize: island.f(14)
        color: island.fg
        fontFamily: island.fontFamily
        onClicked: island.calendarAdding = !island.calendarAdding
      }
    }
  }

  // --------------------------------------------------------------------------
  // MONTH VIEW CONTAINER
  // --------------------------------------------------------------------------
  Item {
    id: monthContainer
    visible: view.currentMode === "month" && !view.adding && !view.pickingHolidays
    anchors.top: topNav.bottom
    anchors.topMargin: island.s(6)
    anchors.left: parent.left
    anchors.leftMargin: view.pad
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.pad

    // Left: Month Grid
    Item {
      id: monthGridPane
      anchors.left: parent.left
      anchors.top: parent.top
      width: island.s(7 * 32)
      height: parent.height

      // Weekday letters
      Row {
        id: weekdayRow
        anchors.top: parent.top
        width: parent.width
        Repeater {
          model: 7
          Item {
            width: island.s(32)
            height: island.s(18)
            Text {
              anchors.centerIn: parent
              text: ["M","T","W","T","F","S","S"][(index + view.firstWeekday + 6) % 7]
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(10)
              font.weight: Font.DemiBold
              color: island.fgDim
            }
          }
        }
      }

      // Days Grid
      Grid {
        anchors.top: weekdayRow.bottom
        anchors.topMargin: island.s(2)
        columns: 7
        rowSpacing: island.s(2)
        columnSpacing: 0

        Repeater {
          model: view.leadingBlanks + new Date(view.year, view.monthIndex + 1, 0).getDate()

          Item {
            id: cell
            readonly property int dayNumber: index - view.leadingBlanks + 1
            readonly property bool blank: index < view.leadingBlanks
            readonly property double time: blank ? 0 : new Date(view.year, view.monthIndex, dayNumber).getTime()
            readonly property bool isToday: !blank && view.year === view.today.getFullYear()
              && view.monthIndex === view.today.getMonth() && dayNumber === view.today.getDate()
            readonly property bool isSelected: !blank && time === view.selected
            readonly property var dayEventList: blank ? [] : (view.days[Model.dayKey(time)] || [])
            readonly property bool hasEvents: dayEventList.length > 0 || (cal.datesWithEvents && cal.datesWithEvents.indexOf(Model.dayKey(time)) !== -1)

            width: island.s(32)
            height: island.s(28)

            Rectangle {
              anchors.centerIn: parent
              width: island.s(26)
              height: width
              radius: width / 2
              color: cell.isSelected ? island.accentColor
                : (cell.isToday ? Util.alpha(island.accentColor, 0.25)
                  : (cellMouse.containsMouse ? Util.alpha(island.fg, 0.08) : "transparent"))

              Text {
                anchors.centerIn: parent
                visible: !cell.blank
                text: String(cell.dayNumber)
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island.fontFamily
                font.pixelSize: island.f(11)
                font.weight: (cell.isToday || cell.isSelected) ? Font.DemiBold : Font.Normal
                color: cell.isSelected ? "#ffffff" : (cell.isToday ? island.accentColor : island.fg)
              }

              // Event indicator dot
              Rectangle {
                visible: cell.hasEvents && !cell.isSelected
                anchors.bottom: parent.bottom
                anchors.bottomMargin: island.s(2)
                anchors.horizontalCenter: parent.horizontalCenter
                width: island.s(3)
                height: width
                radius: width / 2
                color: cell.isToday ? island.accentColor : island.fgDim
              }
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              enabled: !cell.blank
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.selected = cell.time
            }
          }
        }
      }
    }

    // Divider
    Rectangle {
      anchors.left: monthGridPane.right
      anchors.leftMargin: island.s(10)
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 1
      color: Util.alpha(island.fg, 0.08)
    }

    // Right: Day Schedule / Event Card
    Item {
      anchors.left: monthGridPane.right
      anchors.leftMargin: island.s(18)
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom

      // Selected Day Header
      Text {
        id: selectedDayLabel
        anchors.top: parent.top
        text: Qt.formatDateTime(new Date(view.selected), "dddd, MMMM d")
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(12)
        font.weight: Font.DemiBold
        color: island.accentColor
      }

      // Empty State
      Text {
        visible: view.dayEvents.length === 0
        anchors.centerIn: parent
        text: "No events scheduled"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(11)
        color: island.fgDim
      }

      // Day Events ScrollView
      ScrollView {
        visible: view.dayEvents.length > 0
        anchors.top: selectedDayLabel.bottom
        anchors.topMargin: island.s(6)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        Column {
          width: parent.width
          spacing: island.s(6)

          Repeater {
            model: view.dayEvents

            Rectangle {
              id: evCard
              required property var modelData
              width: parent.width
              height: island.s(48)
              radius: island.s(8)
              color: Util.alpha(island.fg, 0.05)

              Column {
                anchors.left: parent.left
                anchors.leftMargin: island.s(10)
                anchors.right: joinBtn.visible ? joinBtn.left : parent.right
                anchors.rightMargin: island.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.s(2)

                Text {
                  width: parent.width
                  text: evCard.modelData.title || "Meeting"
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(11)
                  font.weight: Font.DemiBold
                  color: island.fg
                }

                Text {
                  width: parent.width
                  text: evCard.modelData.allDay ? "All Day" : (evCard.modelData.timeString || (view.timeText(evCard.modelData.start) + " - " + view.timeText(evCard.modelData.end)))
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(10)
                  color: island.fgDim
                }
              }

              // Join meeting button
              Rectangle {
                id: joinBtn
                visible: !!evCard.modelData.url
                anchors.right: parent.right
                anchors.rightMargin: island.s(8)
                anchors.verticalCenter: parent.verticalCenter
                height: island.s(24)
                width: island.s(58)
                radius: height / 2
                color: Util.alpha(island.greenColor, joinMouse.pressed ? 0.35 : 0.2)

                Text {
                  anchors.centerIn: parent
                  text: "󰍫 Join"
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(10)
                  font.weight: Font.DemiBold
                  color: island.greenColor
                }

                MouseArea {
                  id: joinMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: island.openLink(evCard.modelData.url)
                }
              }

              MouseArea {
                anchors.fill: parent
                enabled: !joinBtn.visible && !!evCard.modelData.url
                cursorShape: Qt.PointingHandCursor
                onClicked: if (evCard.modelData.url) island.openLink(evCard.modelData.url)
              }
            }
          }
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // AGENDA VIEW CONTAINER
  // --------------------------------------------------------------------------
  Item {
    id: agendaContainer
    visible: view.currentMode === "agenda" && !view.adding && !view.pickingHolidays
    anchors.top: topNav.bottom
    anchors.topMargin: island.s(6)
    anchors.left: parent.left
    anchors.leftMargin: view.pad
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.pad

    ScrollView {
      anchors.fill: parent
      clip: true

      Column {
        width: parent.width
        spacing: island.s(8)

        Repeater {
          model: cal.googleEvents.length > 0 ? cal.googleEvents.slice(0, 15) : (cal.events || []).slice(0, 10)

          Rectangle {
            id: agendaCard
            required property var modelData
            width: parent.width
            height: island.s(44)
            radius: island.s(8)
            color: Util.alpha(island.fg, 0.05)

            Row {
              anchors.fill: parent
              anchors.leftMargin: island.s(10)
              anchors.rightMargin: island.s(10)
              spacing: island.s(10)

              // Date badge
              Column {
                width: island.s(68)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  text: Qt.formatDateTime(new Date(agendaCard.modelData.start), "ddd, MMM d")
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(10)
                  font.weight: Font.DemiBold
                  color: island.accentColor
                }

                Text {
                  text: agendaCard.modelData.allDay ? "All Day" : view.timeText(agendaCard.modelData.start)
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(9)
                  color: island.fgDim
                }
              }

              // Event details
              Column {
                width: parent.width - island.s(80) - (agendaJoinBtn.visible ? island.s(66) : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  width: parent.width
                  text: agendaCard.modelData.title || "Meeting"
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(11)
                  font.weight: Font.DemiBold
                  color: island.fg
                }

                Text {
                  width: parent.width
                  text: agendaCard.modelData.location || "Google Calendar"
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(9)
                  color: island.fgDim
                }
              }

              // Join button
              Rectangle {
                id: agendaJoinBtn
                visible: !!agendaCard.modelData.url
                anchors.verticalCenter: parent.verticalCenter
                height: island.s(24)
                width: island.s(58)
                radius: height / 2
                color: Util.alpha(island.greenColor, 0.2)

                Text {
                  anchors.centerIn: parent
                  text: "󰍫 Join"
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: island.textFamily
                  font.pixelSize: island.f(10)
                  font.weight: Font.DemiBold
                  color: island.greenColor
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: island.openLink(agendaCard.modelData.url)
                }
              }
            }
          }
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // ADD CALENDAR & HOLIDAYS OVERLAY
  // --------------------------------------------------------------------------
  Item {
    visible: view.adding || view.pickingHolidays
    anchors.top: topNav.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: view.pad

    // Holiday Country Picker
    ListView {
      visible: view.pickingHolidays
      anchors.fill: parent
      clip: true
      spacing: island.s(4)
      model: [{ code: "off", name: "No holidays" }, { code: "auto", name: "Automatic" }].concat(Model.holidayCalendars)

      delegate: Rectangle {
        required property var modelData
        width: ListView.view.width
        height: island.s(26)
        radius: height / 2
        color: Util.alpha(island.fg, 0.05)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: island.s(12)
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(11)
          color: island.fg
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            view.cal.setHolidays(modelData.code)
            view.pickingHolidays = false
          }
        }
      }
    }

    // Add / Paste Calendar
    Column {
      visible: view.adding && !view.pickingHolidays
      anchors.fill: parent
      spacing: island.s(10)

      Row {
        width: parent.width
        height: island.s(32)
        spacing: island.s(8)

        Rectangle {
          width: parent.width - pasteBtn.width - island.s(8)
          height: parent.height
          radius: height / 2
          color: Util.alpha(island.fg, 0.08)

          TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: island.s(12)
            anchors.right: parent.right
            anchors.rightMargin: island.s(12)
            anchors.verticalCenter: parent.verticalCenter
            font.family: island.fontFamily
            font.pixelSize: island.f(11)
            color: island.fg
            clip: true

            Keys.onReturnPressed: {
              if (text.trim()) {
                island.addCalendar(text.trim())
                text = ""
                island.calendarAdding = false
              }
            }
          }
        }

        Rectangle {
          id: pasteBtn
          width: island.s(80)
          height: parent.height
          radius: height / 2
          color: Util.alpha(island.accentColor, 0.25)

          Text {
            anchors.centerIn: parent
            text: "󰆒 Paste"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.textFamily
            font.pixelSize: island.f(11)
            color: island.accentColor
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: island.addCalendarFromClipboard()
          }
        }
      }

      Text {
        text: "Google Calendar: Settings › your calendar › Secret address in iCal format."
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(10)
        color: island.fgDim
      }
    }
  }
}
