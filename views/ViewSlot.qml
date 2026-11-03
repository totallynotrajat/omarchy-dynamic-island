import QtQuick

// Holds one island view at its own target size, centered in the island.
// Because the view never resizes with the spring, the morphing shape reveals
// it instead of squashing it; the view itself smoothly fades and settles in.
Item {
  id: slot

  property bool active: false

  // Centered on device pixels so text and edges stay crisp
  readonly property real dpr: parent && parent.dpr > 0 ? parent.dpr : 1
  x: parent ? Math.round((parent.width - width) / 2 * dpr) / dpr : 0
  y: parent ? Math.round((parent.height - height) / 2 * dpr) / dpr : 0
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.92
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity {
    NumberAnimation { duration: slot.active ? 200 : 100; easing.type: Easing.OutCubic }
  }

  Behavior on scale {
    NumberAnimation {
      duration: slot.active ? 240 : 110
      easing.type: slot.active ? Easing.OutBack : Easing.InCubic
      easing.overshoot: 1.08
    }
  }
}
