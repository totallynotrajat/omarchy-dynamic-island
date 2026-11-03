import QtQuick

// A short fade over the bottom of a clipped list while rows sit below the
// fold, so a cut-off row reads as "scroll for more" instead of a glitch.
// Place it as a sibling of the list (same parent) and pass the list as `flick`.
Rectangle {
  id: fade
  property Flickable flick: null
  property color tone: "black"
  property real size: 18

  x: flick ? flick.x : 0
  y: flick ? flick.y + flick.height - height : 0
  width: flick ? flick.width : 0
  height: size
  visible: flick !== null && flick.visible && flick.contentHeight > flick.height + 1 && !flick.atYEnd
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.rgba(fade.tone.r, fade.tone.g, fade.tone.b, 0) }
    GradientStop { position: 1; color: fade.tone }
  }
}
