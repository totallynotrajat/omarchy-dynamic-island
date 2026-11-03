import QtQuick

// Holds one island view at its own target size, centered horizontally and anchored to the top bar.
// Because the view never resizes with the spring, the morphing shape reveals
// it instead of squashing it; the view itself smoothly fades and settles in.
Item {
  id: slot
  default property alias data: slot.children
  property bool active: false

  // Centered on device pixels so text and edges stay crisp
  readonly property real dpr: parent && parent.dpr > 0 ? parent.dpr : 1
  x: parent ? Math.round((parent.width - width) / 2 * dpr) / dpr : 0
  // When expanding downwards from the top bar, anchor expanded views (height > 40) at y: 0
  // so the view reveals smoothly downward without jumping.
  y: parent ? (height > 40 ? 0 : Math.round((parent.height - height) / 2 * dpr) / dpr) : 0
  transformOrigin: Item.Top
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.95
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity { NumberAnimation { duration: slot.active ? 140 : 80 } }
  Behavior on scale {
    NumberAnimation {
      duration: slot.active ? 170 : 80
      easing.type: slot.active ? Easing.OutBack : Easing.InCubic
      easing.overshoot: 1.05
    }
  }
}
