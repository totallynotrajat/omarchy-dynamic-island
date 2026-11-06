import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import qs.Commons

// Rounded cover art with a tinted glyph standing in until (or unless) the
// player provides an image.
//
// The tile is always square and always full: the image is scaled to cover
// it keeping its aspect ratio and centred, so a 16:9 video thumbnail loses
// a little off its left and right edges, never its middle.
//
// Qt's Image does the centred crop (PreserveAspectCrop), and a rounded mask
// cuts the corners. The layer is rendered at the screen's own pixel density
// so it stays sharp at fractional scaling. (Filling a Shape straight from
// the decoded texture ignored the crop and showed a corner of wide
// thumbnails.)
Item {
  id: art

  property string source: ""
  property color tint: Color.accent
  property string fontFamily: Style.font.family
  property real radius: Math.round(width * 0.24)
  property string placeholder: "󰝚"

  // App icons from the icon theme have their own shape (and transparency),
  // so they are drawn as-is instead of cropped into a rounded tile.
  readonly property bool themeIcon: source.indexOf("image://icon/") === 0

  // Decode at twice the on-screen size so 1.25x/1.5x/2x screens all get
  // real pixels; the scene graph filters it down smoothly.
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property int textureW: Math.max(1, Math.ceil(width * dpr))
  readonly property int textureH: Math.max(1, Math.ceil(height * dpr))

  Image {
    id: image
    width: art.width
    height: art.height
    visible: status === Image.Ready
    source: art.source
    // A cover fills the square, centred, its overhang cut off; a theme icon
    // fits inside it.
    fillMode: art.themeIcon ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    clip: true
    layer.enabled: !art.themeIcon
    layer.smooth: true
    layer.textureSize: Qt.size(art.textureW, art.textureH)
    layer.effect: OpacityMask { maskSource: roundMask }
    sourceSize.width: art.decodeSize
    sourceSize.height: art.decodeSize
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    // The tinted tile only stands in while there is no image.
    visible: image.status !== Image.Ready

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: Util.alpha(art.tint, 0.22)
      PathRectangle { x: 0; y: 0; width: art.width; height: art.height; radius: art.radius }
    }
  }

  // The tile's rounded shape, used as the cover's mask.
  Rectangle {
    id: roundMask
    width: art.width
    height: art.height
    radius: art.radius
    antialiasing: true
    visible: false
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(art.textureW, art.textureH)
  }

  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready
    text: art.placeholder
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: art.fontFamily
    font.pixelSize: Math.round(art.height * 0.5)
    color: art.tint
  }
}
