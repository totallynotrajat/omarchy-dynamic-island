import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Boring Notch Segmented Tab Bar for Omarchy Dynamic Island.
// Provides fluid 1-click switching between Calendar, Focus (Focusd Pomodoro),
// Music Player, Notifications Inbox, and System Overview.
Item {
  id: nav

  property var island: null
  readonly property string currentTab: island ? island.currentFeature : "calendar"

  height: island ? island.s(28) : 28
  width: tabRow.width + (island ? island.s(8) : 8)

  // Sleek frosted glass capsule container
  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.45)
    border.color: island ? Util.alpha(island.fg, 0.14) : Qt.rgba(1, 1, 1, 0.14)
    border.width: 1
  }

  // Active pill highlight indicator
  Rectangle {
    id: activeIndicator
    x: nav.activeX
    y: island ? island.s(2) : 2
    width: Math.max(10, nav.activeW)
    height: parent.height - (island ? island.s(4) : 4)
    radius: height / 2
    color: island ? Util.alpha(island.accentColor, 0.32) : Qt.rgba(1, 1, 1, 0.25)
    border.color: island ? Util.alpha(island.accentColor, 0.55) : Qt.rgba(1, 1, 1, 0.4)
    border.width: 1

    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  property real activeX: 0
  property real activeW: 0

  readonly property var tabs: [
    {
      id: "calendar",
      glyph: "󰃭",
      label: "Calendar",
      badge: ""
    },
    {
      id: "focus",
      glyph: island && island.clocks && island.clocks.isFocusd ? (island.clocks.focusSession.indexOf("break") !== -1 ? "" : "") : "",
      label: island && island.clocks && island.clocks.isFocusd ? island.clocks.focusRemainingText : "Focus",
      badge: island && island.clocks && island.clocks.timerActive ? "active" : ""
    },
    {
      id: "media",
      glyph: "󰎆",
      label: "Player",
      badge: island && island.mediaPlaying ? "playing" : ""
    },
    {
      id: "inbox",
      glyph: "󰂚",
      label: "Inbox",
      badge: island && island.inbox && island.inbox.length > 0 ? String(island.inbox.length) : ""
    },
    {
      id: "overview",
      glyph: "󰔚",
      label: "Overview",
      badge: ""
    }
  ]

  Row {
    id: tabRow
    anchors.centerIn: parent
    spacing: island ? island.s(2) : 2

    Repeater {
      id: tabRepeater
      model: nav.tabs

      delegate: Item {
        id: tabItem
        required property var modelData
        required property int index

        readonly property bool isCurrent: nav.currentTab === modelData.id
        readonly property bool isHovered: tabMouse.containsMouse

        height: nav.height - (island ? island.s(4) : 4)
        width: itemRow.implicitWidth + (island ? island.s(16) : 16)

        onIsCurrentChanged: if (isCurrent) Qt.callLater(updatePosition)
        onWidthChanged: if (isCurrent) Qt.callLater(updatePosition)
        Component.onCompleted: if (isCurrent) Qt.callLater(updatePosition)

        function updatePosition() {
          var mapped = tabItem.mapToItem(nav, 0, 0)
          nav.activeX = mapped.x
          nav.activeW = tabItem.width
        }

        Connections {
          target: nav
          function onCurrentTabChanged() {
            if (tabItem.isCurrent) tabItem.updatePosition()
          }
        }

        // Hover effect for inactive tabs
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: island ? Util.alpha(island.fg, 0.08) : Qt.rgba(1, 1, 1, 0.08)
          visible: tabItem.isHovered && !tabItem.isCurrent
        }

        Row {
          id: itemRow
          anchors.centerIn: parent
          spacing: island ? island.s(5) : 5

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tabItem.modelData.glyph
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.fontFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            color: tabItem.isCurrent
              ? (island ? island.accentColor : "#ffffff")
              : (tabItem.modelData.badge === "active" ? (island ? island.orangeColor : "#ffaa00")
                : (tabItem.modelData.badge === "playing" ? (island ? island.greenColor : "#00ff88")
                  : (island ? island.fgDim : "#aaaaaa")))
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tabItem.modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(11) : 11
            font.weight: tabItem.isCurrent ? Font.DemiBold : Font.Normal
            color: tabItem.isCurrent ? (island ? island.fg : "#ffffff") : (island ? island.fgDim : "#aaaaaa")
          }

          // Live status dot / unread badge
          Rectangle {
            visible: tabItem.modelData.badge !== ""
            anchors.verticalCenter: parent.verticalCenter
            height: island ? island.s(14) : 14
            width: tabItem.modelData.badge === "active" || tabItem.modelData.badge === "playing"
              ? height
              : Math.max(height, badgeText.implicitWidth + (island ? island.s(6) : 6))
            radius: height / 2
            color: tabItem.modelData.badge === "active" ? (island ? island.orangeColor : "#ffaa00")
              : (tabItem.modelData.badge === "playing" ? (island ? island.greenColor : "#00ff88")
                : (island ? island.accentColor : "#3388ff"))

            Text {
              id: badgeText
              visible: tabItem.modelData.badge !== "active" && tabItem.modelData.badge !== "playing"
              anchors.centerIn: parent
              text: tabItem.modelData.badge
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island ? island.fontFamily : "sans-serif"
              font.pixelSize: island ? island.f(9) : 9
              font.weight: Font.Bold
              color: "#ffffff"
            }
          }
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (island) island.showFeature(tabItem.modelData.id)
          }
        }
      }
    }
  }
}
