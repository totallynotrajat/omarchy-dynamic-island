import QtQuick
import Qt5Compat.GraphicalEffects

// Fades `target`'s ends out to nothing, so clipped content (a scrolling
// title, a strip of days, a list with more below) melts away instead of
// being cut. It masks the target's own pixels, so it works on the see-through
// glass, where painting the notch's color over the edges would show as a box.
//
// Place it as a sibling of the target (same parent). It takes the target's
// geometry; `start`/`end` pick which ends fade, along x or (with
// `horizontal: false`) y.
Item {
  id: fade

  property Item target: null
  property bool horizontal: true
  property real size: 12
  property bool start: true
  property bool end: true
  readonly property bool needed: target !== null && size > 0 && (start || end)

  x: target ? target.x : 0
  y: target ? target.y : 0
  width: target ? target.width : 0
  height: target ? target.height : 0
  visible: false
  layer.enabled: needed

  readonly property real length: horizontal ? width : height
  readonly property real edge: length > 0 ? Math.min(0.5, size / length) : 0

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: fade.horizontal ? Gradient.Horizontal : Gradient.Vertical
      GradientStop { position: 0; color: fade.start ? "transparent" : "white" }
      GradientStop { position: fade.edge; color: "white" }
      GradientStop { position: 1 - fade.edge; color: "white" }
      GradientStop { position: 1; color: fade.end ? "transparent" : "white" }
    }
  }

  Component {
    id: maskEffect
    OpacityMask { maskSource: fade }
  }

  function attach() {
    if (!target) return
    target.layer.effect = maskEffect
    target.layer.enabled = Qt.binding(function() { return fade.needed })
  }

  onTargetChanged: attach()
  Component.onCompleted: attach()
}
