import QtQuick
import "../theme.js" as Theme

// The menu's spine: a plotted axis. Minor ticks divide the span into twelve,
// every third one reads as a major division, and a brighter segment sweeps the
// axis once per minute, so the ornament is actually the clock's second hand.
//
// `draw` is the pen: the rule extends from its left end and each tick resolves
// as the pen passes it. Straight runs grow by width rather than by dash, which
// is both cheaper and exactly the same gesture, and their weight and cross-axis
// position snap to whole device pixels so every hairline is the same hairline.
Item {
    id: axis

    // 0..1 length of the rule that has been drawn.
    property real draw: 1
    // 0..1 fade of the live sweep, which is a value and should not be "drawn".
    property real reveal: 1
    // 0..1 position of the sweep along the axis.
    property real progress: 0

    property int divisions: 12
    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)

    implicitHeight: 14

    // Base rule.
    Rectangle {
        width: axis.width * Theme.clamp01(axis.draw)
        height: axis.hairline
        color: Theme.lineFaint
        opacity: Theme.opGrid + 0.1
    }

    Repeater {
        model: axis.divisions + 1
        delegate: Rectangle {
            required property int index
            readonly property bool major: index % 3 === 0
            readonly property real reached:
                Theme.tickReached(axis.draw, index / axis.divisions)

            x: Theme.snap(axis.width * index / axis.divisions - axis.hairline / 2,
                          Screen.devicePixelRatio)
            y: 0
            width: axis.hairline
            // Ticks grow downward out of the rule as it passes, so the rule
            // always reads as the thing doing the drawing.
            height: (major ? 5 : 3) * reached
            color: Theme.lineFaint
            opacity: (major ? Theme.opFaint : Theme.opGrid) * reached
            visible: reached > 0.001
        }
    }

    // Swept segment, at the same weight as the rule: only its value reads.
    // It is drawn out to the current value rather than faded in, so the marker
    // travels to its reading the same way the rule travelled to its end.
    Item {
        id: sweep
        readonly property real head:
            axis.width * Theme.clamp01(axis.progress) * Theme.pen(axis.reveal)

        width: axis.width
        visible: axis.reveal > 0.001

        Rectangle {
            width: sweep.head
            height: axis.hairline
            color: Theme.lineStrong
            opacity: Theme.opNormal
        }

        // A single travelling marker at the head of the sweep.
        Rectangle {
            x: sweep.head - axis.hairline / 2
            y: -3
            width: axis.hairline
            height: 7
            color: Theme.lineStrong
            opacity: Theme.opStrong
        }
    }
}
