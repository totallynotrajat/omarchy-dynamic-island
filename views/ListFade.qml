import QtQuick

// A short fade at the bottom of a clipped list while rows sit below the
// fold, so a cut-off row reads as "scroll for more" instead of a glitch.
// Place it as a sibling of the list (same parent) and pass the list as `flick`.
EdgeFade {
  property Flickable flick: null
  // Kept for older callers; the fade masks the list itself now.
  property color tone: "black"

  target: flick
  horizontal: false
  start: false
  end: flick !== null && flick.visible && flick.contentHeight > flick.height + 1 && !flick.atYEnd
  size: 18
}
