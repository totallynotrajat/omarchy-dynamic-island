import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The open notch's tab switcher, on the left of the header: one glyph per
// tab, the current one in a pill that slides between them.
Item {
  id: tabs

  property var island: null
  readonly property var list: Model.visibleTabs({ inbox: !!island && island.tabIds.indexOf("inbox") !== -1 })
  readonly property real cell: island ? island.s(28) : 28

  implicitWidth: row.implicitWidth
  implicitHeight: cell

  Rectangle {
    id: pill
    readonly property int index: {
      for (var i = 0; i < tabs.list.length; i++) if (tabs.list[i].id === island.tab) return i
      return 0
    }
    x: index * tabs.cell
    anchors.verticalCenter: parent.verticalCenter
    width: tabs.cell
    height: tabs.cell
    radius: height / 2
    color: Util.alpha(island ? island.fg : "white", 0.14)
    Behavior on x { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
      model: tabs.list

      Item {
        id: cellItem
        required property var modelData
        readonly property bool current: island && island.tab === modelData.id
        width: tabs.cell
        height: tabs.cell

        Text {
          anchors.centerIn: parent
          text: cellItem.modelData.glyph
          renderType: Text.NativeRendering
          font.family: island ? island.fontFamily : Style.font.family
          font.pixelSize: island ? island.f(14) : 14
          color: cellItem.current ? (island ? island.fg : "white") : (island ? island.fgDim : "gray")
          Behavior on color { ColorAnimation { duration: Style.duration(160) } }
        }

        // Unread count on the inbox tab.
        Rectangle {
          visible: cellItem.modelData.id === "inbox"
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: island ? island.s(3) : 3
          width: island ? island.s(6) : 6
          height: width
          radius: width / 2
          color: island ? island.accentColor : "white"
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: island.selectTab(cellItem.modelData.id)
        }
      }
    }
  }
}
