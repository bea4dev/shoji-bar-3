import QtQuick
import Quickshell.Io
import ".."
import "../theme.js" as Theme

// The fourth section: three ways to end the session.
//
// The menu's own tiles at a larger size, hanging from a rule by the same drop
// lines. An icon on its own would arrive and sit there; a frame that is drawn
// around it gives the panel the same pen work everything else here has.
//
// A press arms a tile and the next one carries it out. Powering a machine off
// is not something to do on a slipped click, and the caption is where it says
// so -- no extra dialog, no second surface.
Item {
    id: power

    // 0..1 pen driver for this panel.
    property real draw: 1
    // Tile under the pointer, hit-tested by the bar's single MouseArea.
    property int hovered: -1
    // Tile waiting for its second press, or -1.
    property int armed: -1

    readonly property var actions: Theme.powerActions

    // Moving off an armed tile disarms it: the arming belongs to the gesture,
    // not to the panel.
    onHoveredChanged: {
        if (armed >= 0 && hovered !== armed)
            armed = -1;
    }

    function reset() {
        armed = -1;
    }

    function tileAt(lx, ly) {
        if (ly < Theme.powerTileY - 8
            || ly > Theme.powerLabelY + 12)
            return -1;
        for (var i = 0; i < actions.length; i++) {
            if (Math.abs(lx - Theme.powerTileX(i)) <= Theme.powerTileSize / 2 + 8)
                return i;
        }
        return -1;
    }

    function activate(index) {
        if (index < 0 || index >= actions.length)
            return;
        var chosen = actions[index];
        // Only what cannot be undone asks twice.
        if (chosen.confirm && armed !== index) {
            armed = index;
            return;
        }
        armed = -1;
        if (chosen.session === "lock") {
            Lock.engage();
            return;
        }
        runner.running = false;
        runner.command = chosen.command;
        runner.running = true;
    }

    Process { id: runner }

    clip: true

    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.powerWidth - Theme.powerPadX * 2

        x: (power.width - Theme.powerWidth) / 2
        y: (power.height - Theme.powerHeight) / 2
        width: Theme.powerWidth
        height: Theme.powerHeight

        AxisRule {
            x: Theme.powerPadX
            y: Theme.powerAxisY
            width: body.inner
            divisions: 10
            draw: Theme.pen(Theme.powerPhase(power.draw, Theme.drawPowerAxis))
            // Nothing here is a reading, so the rule carries no sweep.
            reveal: 0
        }

        // Each tile is tied to its division on the rule, which is what makes
        // the row read as plotted rather than merely arranged.
        Repeater {
            model: power.actions.length
            delegate: Rectangle {
                required property int index
                readonly property real drawn: Theme.pen(
                    Theme.powerPhase(power.draw, Theme.drawPowerDrop, index))

                x: Theme.snap(Theme.powerTileX(index) - body.hairline / 2,
                              Screen.devicePixelRatio)
                y: Theme.powerAxisY + 7
                width: body.hairline
                height: (Theme.powerTileY - Theme.powerAxisY - 7) * drawn
                color: Theme.lineFaint
                opacity: power.hovered === index ? Theme.opNormal : Theme.opGrid
                visible: drawn > 0.001

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }

        Repeater {
            model: power.actions
            delegate: IconTile {
                required property int index
                required property var modelData
                readonly property bool isArmed: power.armed === index

                source: Qt.resolvedUrl("../assets/icons/" + modelData.icon + ".svg")
                // An armed tile says what the next press does, in the place
                // its name was.
                label: isArmed ? Theme.powerArmedLabel : modelData.label
                hovered: power.hovered === index || isArmed

                size: Theme.powerTileSize
                radius: Theme.powerTileRadius
                glyphSize: Theme.powerIconSize
                labelOffset: Theme.powerLabelY - Theme.powerTileY
                labelCapacity: Theme.powerLabelChars

                x: Theme.powerTileX(index) - width / 2
                y: Theme.powerTileY

                draw: Theme.pen(Theme.powerPhase(
                    power.draw, Theme.drawPowerFrame, index))
                glyphReveal: Theme.pen(Theme.powerPhase(
                    power.draw, Theme.drawPowerGlyph, index))
                labelReveal: Theme.powerPhase(
                    power.draw, Theme.drawPowerLabel, index)
            }
        }
    }
}
