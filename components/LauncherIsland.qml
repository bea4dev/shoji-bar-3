import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../theme.js" as Theme

// The launcher: the first section panel, extruded out of the menu in the
// dock's place.
//
// It is a plot, not a list. A rail runs down the left of the results and every
// row is a tick branching out of it; the rule under the query reads how much of
// the corpus survived the filter, on the same instrument the menu uses for
// seconds and the dock uses for charge.
//
// Unlike DockIsland this takes the pen driver itself rather than one reveal per
// element: its stages repeat per row, and handing down seven rows' worth of
// windows would put the schedule in the caller instead of next to the strokes
// it times. It still starts no animation of its own -- every reveal here is a
// pure function of `draw` -- so toggling faster than the panel can finish only
// feeds those functions a different number.
Item {
    id: launcher

    // 0..1 pen driver for this panel.
    property real draw: 1
    // Row slot under the pointer, hit-tested by the bar's single MouseArea.
    property int hovered: -1
    // Whether the panel should be holding the keyboard.
    property bool active: false

    signal launched
    signal dismissed

    readonly property var apps: DesktopEntries.applications.values

    property string query: ""
    // Index into `results`, which may be scrolled out of the visible window.
    property int selected: 0
    // First visible result: the window slides to keep `selected` inside it.
    property int first: 0

    readonly property int total: apps.length

    // Ranked rather than merely filtered: a prefix of the name is what the
    // query usually means, a word inside it is the next best thing, and the
    // metadata fields are a fallback that should never outrank either.
    readonly property var results: {
        var q = query.trim().toLowerCase();
        var scored = [];
        for (var i = 0; i < apps.length; i++) {
            var entry = apps[i];
            if (entry.noDisplay)
                continue;
            var name = (entry.name || "").toLowerCase();
            var rank = 0;
            if (q.length > 0) {
                var at = name.indexOf(q);
                if (at === 0)
                    rank = 1;
                else if (at > 0)
                    rank = name.charAt(at - 1) === " " ? 2 : 3;
                else {
                    var other = [entry.genericName || "", entry.comment || "",
                                 (entry.keywords || []).join(" "),
                                 entry.execString || ""].join(" ").toLowerCase();
                    if (other.indexOf(q) < 0)
                        continue;
                    rank = 4;
                }
            }
            scored.push({ entry: entry, rank: rank, name: name });
        }
        scored.sort(function (a, b) {
            return a.rank - b.rank || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
        });
        var out = [];
        for (var j = 0; j < scored.length; j++)
            out.push(scored[j].entry);
        return out;
    }

    // Window bounds, clamped here rather than at every call site.
    readonly property int lastFirst:
        Math.max(0, results.length - Theme.launcherRows)

    function reset() {
        input.text = "";
        selected = 0;
        first = 0;
    }

    // Keeps the visible window around the selection, moving by the least it can.
    function follow() {
        var target = Math.max(0, Math.min(selected, results.length - 1));
        if (target < first)
            first = target;
        else if (target >= first + Theme.launcherRows)
            first = target - Theme.launcherRows + 1;
        first = Math.max(0, Math.min(first, lastFirst));
    }

    function step(delta) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
        follow();
    }

    // The window moves and the selection comes with it, so what Enter would
    // launch is always something the eye can see.
    function scrollBy(delta) {
        var moved = Math.max(0, Math.min(lastFirst, first + delta));
        if (moved === first)
            return;
        first = moved;
        selected = Math.max(first,
            Math.min(first + Theme.launcherRows - 1, selected));
    }

    // Launcher-local hit test, in the contents' own coordinates. Returns the
    // slot, not the result index, so the caller never has to know about the
    // scroll offset.
    function rowAt(lx, ly) {
        if (lx < 0 || lx > Theme.launcherWidth)
            return -1;
        var slot = Math.floor((ly - Theme.launcherRowsY) / Theme.launcherRowHeight);
        if (slot < 0 || slot >= Theme.launcherRows)
            return -1;
        return first + slot < results.length ? slot : -1;
    }

    // The first category that says something about the application rather than
    // about whoever packaged it.
    function kindOf(entry) {
        var categories = entry.categories || [];
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].indexOf("X-") !== 0)
                return categories[i];
        }
        return "";
    }

    function activate(slot) {
        var entry = results[first + slot];
        if (!entry)
            return;
        entry.execute();
        launched();
    }

    function activateSelected() {
        var entry = results[selected];
        if (!entry)
            return;
        entry.execute();
        launched();
    }

    // An item that is not visible cannot hold active focus, so the grab has to
    // wait for the panel to exist rather than happen when it is requested.
    function syncFocus() {
        if (active && visible)
            input.forceActiveFocus();
        else if (!active)
            input.focus = false;
    }

    onActiveChanged: syncFocus()
    onVisibleChanged: syncFocus()
    // A shrinking result set can leave the selection past the end of it.
    onResultsChanged: {
        if (selected > results.length - 1)
            selected = Math.max(0, results.length - 1);
        follow();
    }

    clip: true

    // Scrolling arrives through `scrollBy`, called by the bar's single
    // MouseArea. A WheelHandler of this panel's own never saw the events: the
    // bar owns every pointer event the surface receives, and that is also what
    // keeps hover from being stolen from it.

    // Contents at the island's full size, centred in its animated box, so
    // nothing shifts as the panel necks out and settles.
    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.launcherWidth - Theme.launcherPadX * 2

        x: (launcher.width - Theme.launcherWidth) / 2
        y: (launcher.height - Theme.launcherHeight) / 2
        width: Theme.launcherWidth
        height: Theme.launcherHeight

        // ----- query row ----------------------------------------------------

        // The prompt is the peek chevron turned to point at the field, so the
        // bar says "here" with one stroke in both places.
        Chevron {
            span: 9
            drop: 4
            rotation: -90
            transformOrigin: Item.Center
            x: Theme.launcherPromptX - width / 2
            y: Theme.launcherQueryY - height / 2
            ink: Theme.lineStrong
            opacity: Theme.opNormal
            progress: Theme.pen(Theme.launcherPhase(
                launcher.draw, Theme.drawLauncherPrompt))
            visible: progress > 0.001
        }

        Item {
            id: field

            readonly property real reveal:
                Theme.launcherPhase(launcher.draw, Theme.drawLauncherQuery)

            x: Theme.launcherQueryX
            y: Theme.launcherQueryY - height / 2
            width: body.inner + Theme.launcherPadX - Theme.launcherQueryX
                - Theme.launcherNoteWidth
            height: input.implicitHeight
            opacity: Theme.clamp01(reveal)
            visible: opacity > 0.001

            TextInput {
                id: input

                anchors.fill: parent
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: Theme.launcherQuerySize
                font.letterSpacing: 1.5
                selectionColor: Theme.lineNormal
                selectedTextColor: Theme.textPrimary
                selectByMouse: true
                clip: true

                onTextChanged: {
                    launcher.query = text;
                    launcher.selected = 0;
                    launcher.first = 0;
                }

                // The caret is a hairline, like everything else that marks a
                // position here; the blink is the one animation in this file,
                // and it carries no state anything else depends on.
                cursorDelegate: Rectangle {
                    width: body.hairline
                    color: Theme.lineStrong

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: input.activeFocus
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 520 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 420 }
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        launcher.dismissed();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        launcher.step(1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        launcher.step(-1);
                    } else if (event.key === Qt.Key_PageDown) {
                        launcher.step(Theme.launcherRows);
                    } else if (event.key === Qt.Key_PageUp) {
                        launcher.step(-Theme.launcherRows);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        launcher.activateSelected();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "SEARCH"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 10
                font.letterSpacing: 3
                opacity: Theme.opGrid
                visible: input.text.length === 0
            }
        }

        // How much of the corpus the query kept, written as a figure and
        // plotted on the rule below it.
        TypedText {
            x: body.width - Theme.launcherPadX - width
            y: Theme.launcherQueryY - height / 2
            content: launcher.results.length + " / " + launcher.total
            capacity: Theme.launcherCountChars
            reveal: Theme.launcherPhase(launcher.draw, Theme.drawLauncherCount)
            ink: Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
            visible: reveal > 0.001
        }

        AxisRule {
            x: Theme.launcherPadX
            y: Theme.launcherAxisY
            width: body.inner
            draw: Theme.pen(Theme.launcherPhase(launcher.draw, Theme.drawLauncherAxis))
            reveal: Theme.remap(
                Theme.launcherPhase(launcher.draw, Theme.drawLauncherAxis), 0.45, 1)
            progress: launcher.total > 0
                ? launcher.results.length / launcher.total : 0
        }

        // ----- results ------------------------------------------------------

        // The rail the rows branch off. Drawn downward, so it reads as the
        // thing that put the rows there.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.launcherPhase(launcher.draw, Theme.drawLauncherRail))

            x: Theme.snap(Theme.launcherRailX - body.hairline / 2,
                          Screen.devicePixelRatio)
            y: Theme.launcherRowsY
            width: body.hairline
            height: Theme.launcherRowsHeight * drawn
            color: Theme.lineFaint
            opacity: Theme.opGrid
            visible: drawn > 0.001
        }

        Repeater {
            model: Theme.launcherRows
            delegate: Item {
                id: row

                required property int index
                readonly property var entry: launcher.results[launcher.first + index] || null
                readonly property real branch: Theme.pen(
                    Theme.launcherPhase(launcher.draw, Theme.drawLauncherRow, index))
                readonly property real nameReveal:
                    Theme.launcherPhase(launcher.draw, Theme.drawLauncherName, index)
                readonly property real iconReveal: Theme.pen(
                    Theme.launcherPhase(launcher.draw, Theme.drawLauncherIcon, index))
                readonly property bool current: launcher.first + index === launcher.selected
                readonly property bool hovered: launcher.hovered === index
                readonly property bool lit: current || hovered

                x: 0
                y: Theme.launcherRowsY + index * Theme.launcherRowHeight
                width: body.width
                height: Theme.launcherRowHeight
                visible: entry !== null && branch > 0.001

                // The row's own stroke: a tick out of the rail towards its
                // contents, in the menu's drop-line vocabulary.
                Rectangle {
                    x: Theme.launcherRailX
                    y: Theme.snap((row.height - body.hairline) / 2,
                                  Screen.devicePixelRatio)
                    width: Theme.launcherBranch * row.branch
                    height: body.hairline
                    color: row.lit ? Theme.lineStrong : Theme.lineFaint
                    opacity: row.lit ? Theme.opNormal : Theme.opGrid

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                // Selection is a marker on the rail, the same mark the axis
                // puts at the head of its sweep -- not a filled row.
                Rectangle {
                    x: Theme.snap(Theme.launcherRailX - body.hairline / 2,
                                  Screen.devicePixelRatio)
                    y: (row.height - 14) / 2
                    width: body.hairline
                    height: 14
                    color: Theme.lineStrong
                    opacity: row.current ? Theme.opStrong
                        : row.hovered ? Theme.opFaint : 0
                    visible: opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                TypedText {
                    x: Theme.launcherPadX
                    y: (row.height - height) / 2
                    content: {
                        var n = launcher.first + row.index + 1;
                        return (n < 10 ? "0" : "") + n;
                    }
                    capacity: Theme.launcherIndexChars
                    reveal: Theme.launcherPhase(
                        launcher.draw, Theme.drawLauncherRow, row.index)
                    ink: Theme.textMuted
                    pixelSize: 9
                    letterSpacing: 2
                    opacity: row.lit ? Theme.opNormal : Theme.opGrid

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                IconImage {
                    id: appIcon
                    x: Theme.launcherIconX
                    y: (row.height - Theme.launcherIconSize) / 2
                    width: Theme.launcherIconSize
                    height: Theme.launcherIconSize
                    source: row.entry && row.entry.icon
                        ? Quickshell.iconPath(row.entry.icon, "application-x-executable")
                        : Quickshell.iconPath("application-x-executable", true)
                    visible: Theme.launcherDesaturate <= 0.001
                    opacity: row.iconReveal * (row.lit ? 1 : 0.82)
                }

                Desaturate {
                    anchors.fill: appIcon
                    source: appIcon
                    desaturation: Theme.launcherDesaturate
                    visible: Theme.launcherDesaturate > 0.001
                    opacity: row.iconReveal * (row.lit ? 1 : 0.82)
                }

                // Clipped rather than elided: the name is written a character
                // at a time, and an elide would rewrite its tail every frame.
                Item {
                    x: Theme.launcherNameX
                    y: 0
                    width: body.width - Theme.launcherPadX - Theme.launcherNoteWidth
                        - Theme.launcherNameX
                    height: row.height
                    clip: true

                    TypedText {
                        y: (row.height - height) / 2
                        content: row.entry ? row.entry.name || "" : ""
                        capacity: Theme.launcherNameChars
                        reveal: row.nameReveal
                        ink: row.lit ? Theme.textPrimary : Theme.textMuted
                        pixelSize: 12
                        letterSpacing: 1
                        weight: Font.Light
                        opacity: row.lit ? 1 : Theme.opStrong
                        visible: reveal > 0.001
                    }
                }

                // The annotation is a caption, not pen work: it fades with the
                // row rather than being written after it.
                Text {
                    x: body.width - Theme.launcherPadX - width
                    y: (row.height - height) / 2
                    width: Theme.launcherNoteWidth - 10
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    // What kind of thing this is, not what it is called
                    // twice: the desktop id would only repeat the name in
                    // uppercase with a vendor prefix stuck to it. Vendor
                    // categories are skipped for the same reason -- X-XFCE
                    // says who shipped the file, not what it launches.
                    text: row.entry
                        ? (row.entry.genericName
                           || launcher.kindOf(row.entry) || "").toUpperCase()
                        : ""
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.weight: Font.Light
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                    opacity: Theme.clamp01(row.nameReveal)
                        * (row.lit ? Theme.opNormal : Theme.opGrid)
                    visible: opacity > 0.001
                }
            }
        }

        // Same note the tray uses when it has nothing to show.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.launcherRowsY + Theme.launcherRowHeight
            text: "NO MATCH"
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 9
            font.letterSpacing: 2
            opacity: Theme.opGrid * Theme.clamp01(
                Theme.launcherPhase(launcher.draw, Theme.drawLauncherRow, 0))
            visible: launcher.results.length === 0 && opacity > 0.001
        }
    }
}
