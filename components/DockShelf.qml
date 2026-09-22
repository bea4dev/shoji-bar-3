import QtQuick
import QtQuick.Shapes
import ".."
import "../theme.js" as Theme

// The dock: what is running, what is pinned, along the bottom edge.
//
// It is away until the pointer reaches the bottom of the screen, and the only
// part of this surface that takes input while it is away is a strip a few
// pixels tall -- everything else at the bottom edge still belongs to the
// window underneath.
//
// Read it in one line: a square per application, and under the squares a rule
// carrying one mark per open window. A pinned application with nothing open
// keeps a hollow mark, which is what "a place reserved" looks like when the
// vocabulary is marks on a rule.
//
// Like the bar, every value here is a plain property written by a named
// animation and every position is a pure function of those. Nothing starts an
// animation of its own, so waving the pointer at the edge cannot leave a
// half-finished sequence running.
Item {
    id: shelf

    // ----- the row ----------------------------------------------------------

    readonly property var items: Dock.entries
    readonly property int count: items.length
    // Where the divider goes: pinned applications are before it.
    readonly property int split: Dock.split

    // The pill's width follows the row, and follows it on a curve: an
    // application opening should widen the dock, not teleport it. The binding
    // is what it converges to, so there is no state here to get stuck.
    property real rowWidth: Theme.shelfRowWidth(count, split)

    Behavior on rowWidth {
        NumberAnimation {
            duration: Theme.shelfEmergeMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }

    // ----- drivers ----------------------------------------------------------

    property real reveal: 0
    property real draw: 0

    readonly property bool shown: reveal > 0.001

    NumberAnimation {
        id: revealIn
        target: shelf; property: "reveal"; to: 1
        duration: Theme.shelfEmergeMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    NumberAnimation {
        id: revealOut
        target: shelf; property: "reveal"; to: 0
        duration: Theme.shelfRetractMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    NumberAnimation {
        id: drawIn
        target: shelf; property: "draw"; to: 1
        duration: Theme.durShelfDraw
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: drawOut
        target: shelf; property: "draw"; to: 0
        duration: Theme.durShelfUndraw
        easing.type: Easing.Linear
    }

    function show() {
        hideTimer.stop();
        revealOut.stop(); drawOut.stop();
        revealIn.restart(); drawIn.restart();
    }

    function hide() {
        hideTimer.stop();
        closeMenu();
        revealIn.stop(); drawIn.stop();
        revealOut.restart(); drawOut.restart();
    }

    Timer {
        id: hideTimer
        interval: Theme.shelfGraceMs
        // A menu standing open, or a tile held in the middle of being moved,
        // is the pointer still being here -- it has only stepped off the
        // surface that owns the hover.
        onTriggered: {
            if (!shelf.menuOpen && !shelf.dragging)
                shelf.hide();
        }
    }

    // ----- hover ------------------------------------------------------------

    // A binding on the one MouseArea rather than a value written from its
    // handlers: hover is a fact about where the pointer is, and a fact does
    // not need to be kept in sync. A tile being carried is the exception --
    // then the answer is the tile in hand, wherever the pointer has got to.
    readonly property int hovered: dragging ? dragIndex
        : (hit.containsMouse ? tileAt(hit.mouseX, hit.mouseY) : -1)

    // ----- the menu ---------------------------------------------------------
    //
    // An xdg-popup, the way the tray's menu is, rather than another box in
    // this surface. A menu is as tall as its contents decide, and reserving
    // room for the tallest one inside the layer would make the compositor run
    // the glass pipeline over that rectangle for the whole session.
    //
    // Held by key rather than by object: the row is rebuilt whenever a window
    // opens or closes, and a menu holding a stale entry would act on something
    // that is no longer in the dock.

    property string menuKey: ""

    readonly property int menuColumn: {
        for (var i = 0; i < items.length; i++) {
            if (items[i].key === menuKey)
                return i;
        }
        return -1;
    }
    readonly property var menuItem: menuColumn >= 0 ? items[menuColumn] : null
    readonly property bool menuOpen: menuItem !== null

    // Where the popup is anchored: the whole column, so the menu stands on the
    // pill rather than over the caption.
    readonly property rect menuRect: Qt.rect(
        pillX + Theme.shelfTileX(Math.max(0, menuColumn), count, split),
        pillY, Theme.shelfTile, pillH)

    function openMenu(index) {
        if (index < 0 || index >= items.length)
            return;
        var key = items[index].key;
        menuKey = menuKey === key ? "" : key;
    }

    function closeMenu() {
        menuKey = "";
    }

    // ----- reordering -------------------------------------------------------
    //
    // A pinned tile is dragged to where it should be. Only pinned ones move:
    // an application that merely happens to be running has no stored position
    // for a drag to change, and making one up would pin it by accident.
    //
    // The row itself is not rebuilt while the drag is in progress. `slotOf`
    // answers where each tile is standing right now, which is the order the
    // drag would commit, so what is on screen during the drag is already the
    // result of letting go.

    property int dragIndex: -1
    property real dragX: 0
    // Where inside the tile it was picked up, so it does not jump to centre
    // itself on the pointer.
    property real dragGrab: 0
    property int dragSlot: 0

    readonly property bool dragging: dragIndex >= 0

    function slotOf(index) {
        if (dragIndex < 0)
            return index;
        if (index === dragIndex)
            return dragSlot;
        if (dragIndex < dragSlot)
            return (index > dragIndex && index <= dragSlot) ? index - 1 : index;
        if (dragIndex > dragSlot)
            return (index >= dragSlot && index < dragIndex) ? index + 1 : index;
        return index;
    }

    // Which pinned slot the carried tile's centre is nearest. The pitch is
    // uniform across the pinned run -- the divider is past its last slot -- so
    // this is one division rather than a search.
    function slotAt(px) {
        var centre = px - pillX - dragGrab + Theme.shelfTile / 2;
        var pitch = Theme.shelfTile + Theme.shelfGap;
        var slot = Math.round(
            (centre - Theme.shelfPadX - Theme.shelfTile / 2) / pitch);
        return Math.max(0, Math.min(split - 1, slot));
    }

    function beginDrag(index, px) {
        closeMenu();
        dragIndex = index;
        dragGrab = px - pillX - Theme.shelfTileX(index, count, split);
        dragX = px;
        dragSlot = index;
    }

    function commitDrag() {
        if (dragIndex < 0)
            return;
        var key = items[dragIndex].key;
        var slot = dragSlot;
        dragIndex = -1;
        Dock.reorder(key, slot);
    }

    function cancelDrag() {
        dragIndex = -1;
    }

    // ----- geometry ---------------------------------------------------------

    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)

    readonly property real pillW: rowWidth
    readonly property real pillH: Theme.shelfHeight
    readonly property real pillX: (width - pillW) / 2
    // Away means below the surface's own bottom edge, which is the screen's:
    // the dock is not shrunk out of existence, it is off the screen.
    readonly property real pillY: Theme.mix(
        height + Theme.shelfLift,
        height - Theme.shelfLift - pillH,
        reveal)
    readonly property real pillR: Theme.cornerRadius(Theme.shelfRadius, pillW, pillH)

    // The strip that reveals it, and -- once it is out -- the gap between the
    // pill and the screen edge. A hole there would read to the client as the
    // pointer having left the dock, and the dock would retract under the
    // cursor that is holding it open.
    readonly property real hotW: Math.min(width, pillW + Theme.shelfHotPad * 2)
    readonly property real hotX: (width - hotW) / 2
    readonly property real hotH: Theme.shelfHotHeight + Theme.shelfLift * reveal
    readonly property real hotY: height - hotH

    // ----- hit-testing ------------------------------------------------------
    //
    // One MouseArea over the whole surface, hit-testing these positions from
    // the same functions the contents are drawn from. Nothing below accepts
    // input, so nothing below can steal the hover that holds the dock open.

    function tileAt(px, py) {
        if (!shown || count === 0)
            return -1;
        var ly = py - pillY;
        if (ly < 0 || ly > pillH)
            return -1;
        var lx = px - pillX;
        for (var i = 0; i < count; i++) {
            var x = Theme.shelfTileX(slotOf(i), count, split);
            // Generous by half a gap on each side: a dock is aimed at, not
            // read, and the space between two squares belongs to one of them.
            if (lx >= x - Theme.shelfGap / 2
                && lx <= x + Theme.shelfTile + Theme.shelfGap / 2)
                return i;
        }
        return -1;
    }

    // What the press landed on, so the release can tell a click from a drag
    // that happened to start on the same tile.
    property int pressIndex: -1
    property real pressX: 0
    property int pressButton: Qt.NoButton

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onContainsMouseChanged: {
            if (containsMouse)
                shelf.show();
            else
                hideTimer.restart();
        }

        // The menu opens on the press, the way a context menu does. Everything
        // else waits for the release, because until the button comes up it
        // might still turn out to be a drag.
        onPressed: (event) => {
            var index = shelf.tileAt(event.x, event.y);
            shelf.pressIndex = index;
            shelf.pressX = event.x;
            shelf.pressButton = event.button;

            if (index < 0) {
                shelf.closeMenu();
                return;
            }
            if (event.button === Qt.RightButton)
                shelf.openMenu(index);
        }

        onPositionChanged: (event) => {
            if (shelf.dragging) {
                shelf.dragX = event.x;
                shelf.dragSlot = shelf.slotAt(event.x);
                return;
            }
            if (!pressed || shelf.pressButton !== Qt.LeftButton)
                return;
            // Only pinned tiles have a position to change.
            if (shelf.pressIndex < 0 || shelf.pressIndex >= shelf.split)
                return;
            if (Math.abs(event.x - shelf.pressX) < Theme.shelfDragThreshold)
                return;
            shelf.beginDrag(shelf.pressIndex, event.x);
        }

        onReleased: (event) => {
            if (shelf.dragging) {
                shelf.commitDrag();
                shelf.pressIndex = -1;
                return;
            }

            var index = shelf.pressIndex;
            shelf.pressIndex = -1;
            // The release has to land on the tile the press did.
            if (index < 0 || index !== shelf.tileAt(event.x, event.y))
                return;
            if (event.button === Qt.RightButton)
                return;

            shelf.closeMenu();
            if (event.button === Qt.MiddleButton)
                Dock.launch(shelf.items[index]);
            else
                Dock.activate(shelf.items[index]);
        }

        // The grab can be taken away mid-drag; the row then simply stays as it
        // was rather than committing an order nobody let go of.
        onCanceled: {
            shelf.cancelDrag();
            shelf.pressIndex = -1;
        }
    }

    // ----- silhouette -------------------------------------------------------

    LiquidGroup {
        anchors.fill: parent
        blendRadius: Theme.blendRadius
        tint: Theme.tint
        shapes: [
            LiquidShape {
                x: shelf.pillX
                y: shelf.pillY
                width: shelf.pillW
                height: shelf.pillH
                radius: shelf.pillR
            }
        ]
    }

    // ----- the row's contents -----------------------------------------------

    Item {
        id: content
        x: shelf.pillX
        y: shelf.pillY
        width: shelf.pillW
        height: shelf.pillH
        // A tile admitted at the end of a row that is still widening must not
        // be drawn outside the pill it is joining.
        clip: true

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.shelfTileY + (Theme.shelfTile - height) / 2
            text: "NO WINDOWS"
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 9
            font.letterSpacing: 2
            opacity: Theme.opGrid * Theme.clamp01(shelf.draw)
            visible: shelf.count === 0 && opacity > 0.001
        }

        // The baseline. It is drawn first and the marks resolve as it passes
        // them, so the rule always reads as the thing doing the drawing.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.shelfPhase(shelf.draw, Theme.drawShelfRule, 0, shelf.count))

            x: Theme.shelfPadX - Theme.shelfRulePad
            y: Theme.snap(Theme.shelfMarkY + (Theme.shelfMark - shelf.hairline) / 2,
                          Screen.devicePixelRatio)
            width: (content.width - Theme.shelfPadX * 2
                    + Theme.shelfRulePad * 2) * drawn
            height: shelf.hairline
            color: Theme.lineFaint
            opacity: Theme.opGrid
            visible: shelf.count > 0 && width > 0.5
        }

        // Pinned on one side, merely running on the other.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.shelfPhase(shelf.draw, Theme.drawShelfDivider, 0, shelf.count))

            x: Theme.snap(Theme.shelfDividerX(shelf.count, shelf.split)
                          - shelf.hairline / 2, Screen.devicePixelRatio)
            y: Theme.shelfTileY + (Theme.shelfTile - Theme.shelfDividerHeight * drawn) / 2
            width: shelf.hairline
            height: Theme.shelfDividerHeight * drawn
            color: Theme.lineFaint
            opacity: Theme.opGrid
            visible: shelf.split > 0 && shelf.split < shelf.count && drawn > 0.001
        }

        // Where a carried tile would land, drawn as an empty frame: the row
        // says what letting go would do before it does it.
        Shape {
            x: Theme.shelfTileX(shelf.dragSlot, shelf.count, shelf.split)
            y: Theme.shelfTileY
            width: Theme.shelfTile
            height: Theme.shelfTile
            preferredRendererType: Shape.CurveRenderer
            opacity: Theme.opGrid
            visible: shelf.dragging

            ShapePath {
                strokeColor: Theme.lineFaint
                strokeWidth: Theme.strokeWeight
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: Theme.roundedRectPath(Theme.shelfTile, Theme.shelfTile,
                                                Theme.shelfTileRadius, 1)
                }
            }
        }

        Repeater {
            model: shelf.items

            delegate: Item {
                id: tile

                required property int index
                required property var modelData

                readonly property bool carried: shelf.dragIndex === index
                readonly property bool hovered: shelf.hovered === index
                readonly property bool open: modelData.windows.length > 0
                readonly property real frameDraw: Theme.shelfPhase(
                    shelf.draw, Theme.drawShelfFrame, index, shelf.count)
                readonly property real iconReveal: Theme.shelfPhase(
                    shelf.draw, Theme.drawShelfIcon, index, shelf.count)
                readonly property real markReveal: Theme.shelfPhase(
                    shelf.draw, Theme.drawShelfMark, index, shelf.count)
                readonly property real weight:
                    hovered ? Theme.strokeWeightHover : Theme.strokeWeight

                // The tile in hand follows the pointer, held inside the run it
                // belongs to. The ones it displaces slide out of its way.
                x: carried
                    ? Math.max(Theme.shelfTileX(0, shelf.count, shelf.split),
                        Math.min(Theme.shelfTileX(Math.max(0, shelf.split - 1),
                                                  shelf.count, shelf.split),
                                 shelf.dragX - shelf.pillX - shelf.dragGrab))
                    : Theme.shelfTileX(shelf.slotOf(index), shelf.count, shelf.split)
                y: 0
                z: carried ? 1 : 0
                width: Theme.shelfTile
                height: content.height

                Behavior on x {
                    enabled: !tile.carried
                    NumberAnimation {
                        duration: Theme.shelfSlideMs
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                // The square. Nothing is filled: an application that is open
                // says so on the rule below, not by being highlighted.
                Shape {
                    y: Theme.shelfTileY
                    width: Theme.shelfTile
                    height: Theme.shelfTile
                    preferredRendererType: Shape.CurveRenderer
                    opacity: tile.hovered ? Theme.opStrong
                        : tile.open ? Theme.opNormal : Theme.opFaint
                    visible: tile.frameDraw > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    ShapePath {
                        strokeColor: tile.hovered ? Theme.lineStrong : Theme.lineNormal
                        strokeWidth: tile.weight
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: Theme.roundedRectPath(
                                Theme.shelfTile, Theme.shelfTile,
                                Theme.shelfTileRadius, tile.frameDraw)
                        }

                        Behavior on strokeWidth {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // The application's own icon, at its own colours: this is the
                // one place in the shell where the picture is not ours to
                // draw, and recolouring somebody's logo would make the row
                // unreadable at a glance.
                Image {
                    x: (Theme.shelfTile - width) / 2
                    y: Theme.shelfTileY + (Theme.shelfTile - height) / 2
                    width: Theme.shelfIcon
                    height: Theme.shelfIcon
                    source: tile.modelData.icon
                    sourceSize.width: Theme.shelfIcon * 3
                    sourceSize.height: Theme.shelfIcon * 3
                    smooth: true
                    asynchronous: true
                    opacity: Theme.clamp01(tile.iconReveal)
                        * (tile.hovered ? 1 : 0.86)
                    visible: opacity > 0.001

                    Behavior on opacity {
                        enabled: tile.iconReveal >= 0.999
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }

                // One mark per window, on the rule. A pinned application with
                // nothing open keeps a single hollow one. A tile in hand has
                // left the rule, so it takes no marks with it.
                Repeater {
                    model: Math.max(1, Math.min(tile.modelData.windows.length,
                                                Theme.shelfMarksMax))

                    delegate: Rectangle {
                        required property int index

                        readonly property int marks: Math.max(
                            1, Math.min(tile.modelData.windows.length,
                                        Theme.shelfMarksMax))
                        readonly property var handle:
                            tile.modelData.windows[index] || null
                        readonly property bool here:
                            handle && handle === Dock.activeWindow
                        readonly property bool away: handle && handle.minimized
                        readonly property bool filled: handle && !away

                        x: (Theme.shelfTile - (marks - 1) * Theme.shelfMarkGap) / 2
                           + index * Theme.shelfMarkGap - width / 2
                        y: Theme.shelfMarkY
                        width: Theme.shelfMark
                        height: Theme.shelfMark
                        radius: Theme.shelfMark / 2
                        color: filled ? (here ? Theme.lineStrong : Theme.lineNormal)
                            : "transparent"
                        antialiasing: true
                        border.width: Theme.strokeWeight
                        border.color: here ? Theme.lineStrong : Theme.lineNormal
                        opacity: tile.carried ? 0 : Theme.clamp01(tile.markReveal)
                            * (here ? Theme.opStrong
                                : filled ? Theme.opNormal : Theme.opGrid + 0.1)
                        visible: opacity > 0.001

                        Behavior on opacity {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
