import QtQuick
import QtQuick.Shapes
import "../theme.js" as Theme

// A switch in the bar's vocabulary: a drawn stadium with a plotted point
// inside it. On is the point filled at the far end, off is a hollow point at
// the near end -- the same "standing on the origin or away from it" reading
// the clock panel's month control uses.
//
// `draw` truncates the outline geometrically, so the switch is drawn on rather
// than faded in, and the point travels rather than being redrawn.
Item {
    id: sw

    property bool on: false
    property bool hovered: false
    property real draw: 1

    implicitWidth: Theme.switchWidth
    implicitHeight: Theme.switchHeight
    width: implicitWidth
    height: implicitHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: sw.hovered ? Theme.opStrong : Theme.opNormal
        visible: sw.draw > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeColor: sw.hovered ? Theme.lineStrong : Theme.lineNormal
            strokeWidth: Theme.strokeWeight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: Theme.roundedRectPath(sw.width, sw.height,
                                            sw.height / 2, sw.draw)
            }
        }
    }

    Rectangle {
        readonly property real travel: sw.width - Theme.switchInset * 2

        x: Theme.switchInset + (sw.on ? travel : 0) - width / 2
        y: (sw.height - height) / 2
        width: Theme.switchKnob * 2
        height: width
        radius: width / 2
        color: sw.on ? Theme.lineStrong : "transparent"
        antialiasing: true
        border.width: Theme.strokeWeight
        border.color: sw.hovered ? Theme.lineStrong : Theme.lineNormal
        opacity: Theme.clamp01(sw.draw)
            * (sw.on ? Theme.opStrong : Theme.opNormal)
        visible: opacity > 0.001

        // The point travels to its reading the same way the axis marker does.
        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }
    }
}
