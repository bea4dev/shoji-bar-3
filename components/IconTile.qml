import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../theme.js" as Theme

// A section entry: a hairline rounded square holding a stroked glyph, with a
// sparse caption beneath it. Nothing is filled; hover is expressed by weight.
//
// Hover is supplied by the owner, which hit-tests all columns from the single
// MouseArea covering the silhouette, so no child steals the bar's hover state.
// The three reveal inputs are likewise plain values owned by the caller: this
// component starts no animation of its own and therefore has no state to get
// out of sync when the menu is opened and closed faster than it can finish.
Item {
    id: tile

    required property url source
    required property string label
    property bool hovered: false

    // 0..1 length of the frame that has been drawn, from the top-left corner.
    property real draw: 1
    property real glyphReveal: 1
    property real labelReveal: 1

    readonly property real weight: hovered ? Theme.strokeWeightHover : Theme.strokeWeight
    // Axis-aligned hairlines snap to whole device pixels; the frame's curves do
    // not, because the curve renderer resolves their coverage analytically.
    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)

    implicitWidth: Theme.tileSize
    implicitHeight: Theme.labelY - Theme.tileY + 12
    width: implicitWidth
    height: implicitHeight

    Shape {
        id: frame
        width: Theme.tileSize
        height: Theme.tileSize
        // Per-pixel analytic coverage. The geometry renderer would be the only
        // one honouring a dash pattern, but it has no antialiasing at all, so
        // the outline is truncated geometrically instead and this renderer is
        // free to resolve the corners properly.
        preferredRendererType: Shape.CurveRenderer
        opacity: tile.hovered ? Theme.opStrong : Theme.opNormal
        visible: tile.draw > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeColor: tile.hovered ? Theme.lineStrong : Theme.lineNormal
            strokeWidth: tile.weight
            fillColor: "transparent"
            // A real pen tip at the growing end of the stroke.
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: Theme.roundedRectPath(Theme.tileSize, Theme.tileSize,
                                            Theme.tileRadius, tile.draw)
            }

            Behavior on strokeWidth {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    // Corner ticks: a measurement mark that only resolves on hover, keeping the
    // resting state to a single outline.
    Repeater {
        model: 4
        delegate: Item {
            id: corner
            required property int index
            readonly property int sx: (index === 0 || index === 3) ? 1 : -1
            readonly property int sy: index < 2 ? 1 : -1

            x: sx > 0 ? frame.x - 5 : frame.x + frame.width + 5
            y: sy > 0 ? frame.y - 5 : frame.y + frame.height + 5
            opacity: tile.hovered ? Theme.opFaint : 0
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Rectangle {
                x: corner.sx > 0 ? 0 : -6
                y: -tile.hairline / 2
                width: 6
                height: tile.hairline
                color: Theme.lineStrong
            }
            Rectangle {
                x: -tile.hairline / 2
                y: corner.sy > 0 ? 0 : -6
                width: tile.hairline
                height: 6
                color: Theme.lineStrong
            }
        }
    }

    Image {
        id: glyph
        anchors.centerIn: frame
        width: Theme.iconSize
        height: Theme.iconSize
        source: tile.source
        // Rasterize the SVG well above its drawn size; these are 1.5px strokes.
        sourceSize.width: Theme.iconSize * 4
        sourceSize.height: Theme.iconSize * 4
        smooth: true
        visible: false
    }

    // The assets are authored with a black stroke; recolor at draw time so the
    // palette stays in theme.js and the files stay swappable. A raster glyph
    // cannot be drawn stroke by stroke, so it only fades — and its window is
    // anchored to the end of the frame's, so it lands as the frame closes
    // rather than pretending to be pen work of its own.
    ColorOverlay {
        anchors.fill: glyph
        source: glyph
        color: tile.hovered ? Theme.lineStrong : Theme.lineNormal
        opacity: Theme.clamp01(tile.glyphReveal) * (tile.hovered ? 1 : 0.78)
        visible: opacity > 0.001

        Behavior on opacity {
            enabled: tile.glyphReveal >= 0.999
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    TypedText {
        anchors.horizontalCenter: frame.horizontalCenter
        y: Theme.labelY - Theme.tileY
        content: tile.label
        capacity: Theme.labelChars
        reveal: tile.labelReveal
        ink: Theme.textMuted
        pixelSize: 9
        letterSpacing: 2
        opacity: tile.hovered ? Theme.opNormal + 0.25 : Theme.opFaint
        visible: tile.labelReveal > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }
}
