import QtQuick
import qs.Commons

// Holds one part of the open notch. It is built only while shown (so a tab
// starts fresh each time the notch opens, and nothing polls behind a closed
// notch) and comes in the way Boring Notch's content does: fading in while
// it grows from 80% at the top edge, and fading out quickly on the way out.
Item {
  id: slot

  property bool active: false
  property Component content: null

  width: parent ? parent.width : 0
  height: parent ? parent.height : 0
  transformOrigin: Item.Top
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.8
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity { NumberAnimation { duration: Style.duration(slot.active ? 200 : 80); easing.type: Easing.OutCubic } }
  Behavior on scale { NumberAnimation { duration: Style.duration(slot.active ? 260 : 80); easing.type: Easing.OutCubic } }

  Loader {
    anchors.fill: parent
    active: slot.active || slot.visible
    sourceComponent: slot.content
  }
}
