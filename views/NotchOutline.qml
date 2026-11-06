import QtQuick
import QtQuick.Shapes

// Boring Notch's NotchShape as one path: quadratic "ears" turn out into the
// screen edge at the top, quadratic corners round the bottom. `l` and `r`
// are the outer ends of the ears, `t` the ear size, `b` the bottom corner
// radius and `hh` the height.
//
// Closed, it is the body to fill. Open (`closed: false`) it stops where it
// meets the screen edge again, so a stroke along it rims the sides and the
// bottom but never the top edge.
ShapePath {
  id: outline

  property real l: 0
  property real r: 0
  property real t: 0
  property real b: 0
  property real hh: 0
  property bool closed: true

  startX: l; startY: 0
  PathQuad { x: outline.l + outline.t; y: outline.t; controlX: outline.l + outline.t; controlY: 0 }
  PathLine { x: outline.l + outline.t; y: outline.hh - outline.b }
  PathQuad { x: outline.l + outline.t + outline.b; y: outline.hh; controlX: outline.l + outline.t; controlY: outline.hh }
  PathLine { x: outline.r - outline.t - outline.b; y: outline.hh }
  PathQuad { x: outline.r - outline.t; y: outline.hh - outline.b; controlX: outline.r - outline.t; controlY: outline.hh }
  PathLine { x: outline.r - outline.t; y: outline.t }
  PathQuad { x: outline.r; y: 0; controlX: outline.r - outline.t; controlY: 0 }
  PathLine { x: outline.closed ? outline.l : outline.r; y: 0 }
}
