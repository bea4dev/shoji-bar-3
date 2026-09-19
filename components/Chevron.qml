import QtQuick
import QtQuick.Shapes
import "../theme.js" as Theme

// A two-segment stroke pointing down: the peek state's affordance, one per
// column, sitting exactly where that column's tile will appear.
//
// `progress` truncates the polyline geometrically instead of dashing it, which
// leaves the curve renderer free to antialias analytically. It is a plain
// input, not an animation this component starts, so reversing it mid-draw is
// only a smaller number.
Shape {
    id: chevron

    property real span: 11
    property real drop: 4.5
    property color ink: Theme.lineStrong
    property real weight: 1.3
    property real progress: 1

    readonly property real legLength: Math.sqrt(span * span / 4 + drop * drop)
    readonly property real travelled: Theme.clamp01(progress) * legLength * 2
    readonly property bool pastApex: travelled > legLength
    readonly property real firstLeg: Theme.clamp01(travelled / legLength)
    readonly property real secondLeg: Theme.clamp01((travelled - legLength) / legLength)

    // While the first leg is still being drawn the head sits on it, so the
    // second segment collapses to zero length instead of leaping to the apex.
    readonly property real headX: pastApex
        ? span / 2 * (1 + secondLeg) : span / 2 * firstLeg
    readonly property real headY: pastApex
        ? drop * (1 - secondLeg) : drop * firstLeg

    implicitWidth: span
    implicitHeight: drop
    // Per-pixel analytic coverage, no multisampling needed from the window.
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: chevron.ink
        strokeWidth: chevron.weight
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: 0
        startY: 0
        PathLine {
            x: chevron.span / 2 * chevron.firstLeg
            y: chevron.drop * chevron.firstLeg
        }
        PathLine {
            x: chevron.headX
            y: chevron.headY
        }
    }
}
