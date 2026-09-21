import QtQuick
import "../theme.js" as Theme

// Which workspace you are on, as marks on a rule.
//
// Discrete things, so points rather than a swept axis: one mark each, filled
// at the one you are on, hollow at the rest. The rule runs between the first
// and the last of them, which is what makes a row of dots read as a set
// rather than as decoration.
//
// `draw` is the pen. It starts no animation of its own.
Item {
    id: strip

    property var workspaces: []
    property real draw: 1

    readonly property int count: workspaces.length
    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
    readonly property real span: Math.max(0, (count - 1) * Theme.workspaceGap)

    // Centre of one mark, in the strip's own coordinates.
    function markX(index) {
        return (width - span) / 2 + index * Theme.workspaceGap;
    }

    implicitHeight: Theme.workspaceMark + 4

    Rectangle {
        readonly property real drawn: Theme.pen(strip.draw)

        x: strip.markX(0) - Theme.workspaceRulePad
            + (strip.span + Theme.workspaceRulePad * 2) * (1 - drawn) / 2
        y: Theme.snap((strip.height - strip.hairline) / 2, Screen.devicePixelRatio)
        width: (strip.span + Theme.workspaceRulePad * 2) * drawn
        height: strip.hairline
        color: Theme.lineFaint
        opacity: Theme.opGrid
        // One workspace is not a set, and a rule through a single point says
        // nothing the point does not.
        visible: strip.count > 1 && drawn > 0.001
    }

    Repeater {
        model: strip.count
        delegate: Rectangle {
            required property int index
            readonly property var workspace: strip.workspaces[index]
            readonly property bool here: workspace && workspace.active
            readonly property bool urgent: workspace && workspace.urgent
            // Each mark resolves as the rule reaches it, left to right.
            readonly property real reached: strip.count > 1
                ? Theme.tickReached(Theme.pen(strip.draw), index / (strip.count - 1))
                : Theme.pen(strip.draw)

            x: strip.markX(index) - width / 2
            y: (strip.height - height) / 2
            width: Theme.workspaceMark
            height: Theme.workspaceMark
            radius: Theme.workspaceMark / 2
            color: here || urgent ? Theme.lineStrong : "transparent"
            antialiasing: true
            border.width: Theme.strokeWeight
            border.color: here || urgent ? Theme.lineStrong : Theme.lineNormal
            opacity: reached * (here ? Theme.opStrong
                : urgent ? Theme.opNormal : Theme.opGrid + 0.12)
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }
}
