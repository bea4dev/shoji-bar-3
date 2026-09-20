import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme.js" as Theme

// The whole shell lives in one layer surface and one silhouette.
//
// Three resting states drive everything:
//   0 collapsed - the clock pill, the only thing that reserves screen space
//   1 peek      - hovered: the pill widens and admits it has somewhere to go
//   2 open      - clicked: the main menu, overlapping windows
//
// There are five animated values and nothing else holds state. `peek`, `open`
// and `dock` carry the silhouettes on an eased curve; `peekDraw` and `menuDraw`
// run the linework on linear time, because under that curve the shape is 96%
// resolved at 12% of its duration and a schedule keyed to it would fire every
// stage within a few frames. `dock` is the one driven by an explicit animation
// rather than a Behavior, for the reason given where it is declared.
//
// Every geometry, reveal and stroke length is a pure function of those five.
// No element starts an animation of its own, so toggling faster than a
// transition can finish only feeds the same functions a different number:
// there is no half-finished sequence left running and nothing to reset.
Item {
    id: bar

    property int mode: 0







    signal sectionRequested(int index)

    readonly property var sections: [
        { icon: Qt.resolvedUrl("../assets/icons/terminal.svg"), label: "LAUNCHER" },
        { icon: Qt.resolvedUrl("../assets/icons/clock.svg"), label: "CLOCK" },
        { icon: Qt.resolvedUrl("../assets/icons/setting.svg"), label: "SETTINGS" }
    ]

    // ----- animators --------------------------------------------------------
    //
    // Every value here is a plain property written by a named animation, not a
    // binding with a Behavior on it. A Behavior starts before the bindings that
    // configure it have been re-evaluated, so any duration or delay written as
    // `mode >= n ? a : b` is read one transition late: the island's delay came
    // out as zero when opening from the hover state and it left with the menu,
    // while opening straight from collapsed happened to flush in the other
    // order and looked correct. Driving the transitions from one place instead
    // makes the order explicit and makes "serial" mean what it says.

    property real peek: 0
    property real open: 0
    property real dock: 0
    property real peekDraw: 0
    property real menuDraw: 0

    // Which section panel is showing under the menu. -1 is the dock, the state
    // the menu always opens in: a panel takes the dock's place rather than
    // joining it, so there is never more than one island in that socket.
    property int section: -1
    property real launcher: 0
    property real launcherDraw: 0

    readonly property bool engaged: mode >= 1
    readonly property bool opened: mode >= 2
    readonly property bool launcherOpen: section === 0

    // ----- hover ------------------------------------------------------------

    NumberAnimation {
        id: peekIn
        target: bar; property: "peek"; to: 1
        duration: Theme.durPeek
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    NumberAnimation {
        id: peekOut
        target: bar; property: "peek"; to: 0
        duration: Theme.durPeek
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    NumberAnimation {
        id: peekDrawIn
        target: bar; property: "peekDraw"; to: 1
        duration: Theme.durPeekDraw
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: peekDrawOut
        target: bar; property: "peekDraw"; to: 0
        duration: Theme.durPeekUndraw
        easing.type: Easing.Linear
    }

    onEngagedChanged: {
        if (engaged) {
            peekOut.stop(); peekDrawOut.stop();
            peekIn.restart(); peekDrawIn.restart();
        } else {
            peekIn.stop(); peekDrawIn.stop();
            peekOut.restart(); peekDrawOut.restart();
        }
    }

    // ----- opening and closing ----------------------------------------------
    //
    // One sequence per direction, and the order is the order they are written
    // in: the menu arrives before the island is extruded out of it, and the
    // island is absorbed before the menu collapses. The pen runs alongside,
    // because the linework belongs to both islands at once.

    // Parallel with a delayed branch rather than two phases in a row, so the
    // second animation can be pulled back into the first by `dockOverlapMs`.
    // The delay is a plain constant from theme.js, not `mode >= n ? a : b`:
    // a Behavior would read such a binding one transition late, and that is
    // what made the island leave with the menu when opening from hover.
    ParallelAnimation {
        id: openSequence
        NumberAnimation {
            target: bar; property: "open"; to: 1
            duration: Theme.durMenu
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.dockStartMs }
            NumberAnimation {
                target: bar; property: "dock"; to: 1
                duration: Theme.dockEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
        }
    }

    ParallelAnimation {
        id: closeSequence
        NumberAnimation {
            target: bar; property: "dock"; to: 0
            duration: Theme.dockRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        // Whichever island is in the socket is the one that has to leave, and
        // only one of the two is ever non-zero, so both are simply sent home.
        NumberAnimation {
            target: bar; property: "launcher"; to: 0
            duration: Theme.launcherRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
        NumberAnimation {
            target: bar; property: "launcherDraw"; to: 0
            duration: Theme.durLauncherUndraw
            easing.type: Easing.Linear
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.menuCloseStartMs }
            NumberAnimation {
                target: bar; property: "open"; to: 0
                duration: Theme.durMenu
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    NumberAnimation {
        id: menuDrawIn
        target: bar; property: "menuDraw"; to: 1
        duration: Theme.durMenuDraw
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: menuDrawOut
        target: bar; property: "menuDraw"; to: 0
        duration: Theme.durMenuUndraw
        easing.type: Easing.Linear
    }

    onOpenedChanged: {
        // The tray menu belongs to the open state; losing it takes the popup.
        if (!opened)
            closeTrayMenu();

        if (opened) {
            closeSequence.stop(); menuDrawOut.stop();
            openSequence.restart(); menuDrawIn.restart();
        } else {
            openSequence.stop(); menuDrawIn.stop();
            // Cancel any swap in flight and give the socket back to the dock,
            // so the next opening starts from the state it always starts from.
            // `closeSequence` empties the socket either way.
            toLauncher.stop(); toDock.stop();
            section = -1;
            closeSequence.restart(); menuDrawOut.restart();
        }
    }

    // ----- swapping the lower island ----------------------------------------
    //
    // The same shape as the entrance, one socket lower: one curve, then the
    // next, pulled together by `sectionSwapOverlapMs`. The outgoing island is
    // absorbed into the menu and the incoming one is extruded out of the same
    // edge, so the exchange reads as one drawer replacing another.

    ParallelAnimation {
        id: toLauncher
        NumberAnimation {
            target: bar; property: "dock"; to: 0
            duration: Theme.dockRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launcherStartMs }
            ParallelAnimation {
                NumberAnimation {
                    target: bar; property: "launcher"; to: 1
                    duration: Theme.launcherEmergeMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
                // The panel's contents start with the panel, as the dock's do.
                NumberAnimation {
                    target: bar; property: "launcherDraw"; to: 1
                    duration: Theme.durLauncherDraw
                    easing.type: Easing.Linear
                }
            }
        }
    }

    ParallelAnimation {
        id: toDock
        NumberAnimation {
            target: bar; property: "launcher"; to: 0
            duration: Theme.launcherRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
        NumberAnimation {
            target: bar; property: "launcherDraw"; to: 0
            duration: Theme.durLauncherUndraw
            easing.type: Easing.Linear
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.dockReturnStartMs }
            NumberAnimation {
                target: bar; property: "dock"; to: 1
                duration: Theme.dockEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
        }
    }

    // A tile either owns a panel here or is still only a signal to the shell.
    function chooseSection(index) {
        if (index !== 0) {
            sectionRequested(index);
            return;
        }
        setSection(section === 0 ? -1 : 0);
    }

    function setSection(next) {
        if (section === next)
            return;
        toLauncher.stop(); toDock.stop();
        hit.wheelCarry = 0;
        section = next;
        if (next === 0) {
            launcherIsland.reset();
            toLauncher.restart();
        } else {
            toDock.restart();
        }
    }

    // ----- derived silhouette ----------------------------------------------

    readonly property real shapeW: Theme.mix(Theme.mix(Theme.barWidth, Theme.peekWidth, peek), Theme.menuWidth, open)
    readonly property real shapeH: Theme.mix(Theme.mix(Theme.barHeight, Theme.peekHeight, peek), Theme.menuHeight, open)
    // Clamped rather than interpolated blindly: a radius is only ever as large
    // as the box can hold, and holding the maximum is what keeps a shrinking
    // shape from reading as square.
    readonly property real shapeR: Theme.cornerRadius(
        Theme.mix(Theme.mix(Theme.barRadius, Theme.peekRadius, peek), Theme.menuRadius, open),
        shapeW, shapeH)

    // Centred in the surface, which the compositor centres on the output, so
    // the silhouette does not move when the surface itself is resized.
    readonly property real blobX: (width - shapeW) / 2
    readonly property real blobY: Theme.screenPad

    // Axis-aligned strokes snap to whole device pixels so nominally identical
    // hairlines do not come out at different weights depending on where they
    // land. Curves are left fractional for the curve renderer to resolve.
    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)

    // ----- the lower island -------------------------------------------------

    readonly property real dockW: Theme.dockWidth * dock
    readonly property real dockH: Theme.dockHeight * dock
    // Never scaled with the box: kept at the designed radius while it fits, and
    // at a stadium once it does not.
    readonly property real dockR: Theme.cornerRadius(Theme.dockRadius, dockW, dockH)
    readonly property real dockX: blobX + (shapeW - dockW) / 2

    // The island is born inside the menu and travels out of it. Starting at the
    // menu's edge instead leaves the two shapes merely touching, which gives
    // the smooth minimum nothing to bridge and no neck to thin and break.
    readonly property real dockCenterY: Theme.mix(
        blobY + shapeH - Theme.dockEmergeDepth,
        blobY + shapeH + Theme.dockGap + Theme.dockHeight / 2,
        dock)
    readonly property real dockY: dockCenterY - dockH / 2
    readonly property bool dockVisible: dock > 0.001

    // Contents sit at the island's full size, centred in its animated box.
    readonly property real dockContentX: dockX + (dockW - Theme.dockWidth) / 2
    readonly property real dockContentY: dockY + (dockH - Theme.dockHeight) / 2

    // ----- the launcher island ----------------------------------------------
    //
    // Born in the same place the dock is, out of the menu's lower edge, and on
    // the same terms: overlapping the menu rather than touching it, so the
    // smooth minimum has something to bridge and a neck actually forms.

    readonly property real launcherW: Theme.launcherWidth * launcher
    readonly property real launcherH: Theme.launcherHeight * launcher
    readonly property real launcherR: Theme.cornerRadius(
        Theme.launcherRadius, launcherW, launcherH)
    readonly property real launcherX: blobX + (shapeW - launcherW) / 2
    readonly property real launcherCenterY: Theme.mix(
        blobY + shapeH - Theme.dockEmergeDepth,
        blobY + shapeH + Theme.dockGap + Theme.launcherHeight / 2,
        launcher)
    readonly property real launcherY: launcherCenterY - launcherH / 2
    readonly property bool launcherVisible: launcher > 0.001

    readonly property real launcherContentX:
        launcherX + (launcherW - Theme.launcherWidth) / 2
    readonly property real launcherContentY:
        launcherY + (launcherH - Theme.launcherHeight) / 2

    // The lowest point anything currently reaches, which is what the pointer
    // has to be able to travel over.
    readonly property real lowerBottom: Math.max(
        blobY + shapeH,
        dockVisible ? dockY + dockH : 0,
        launcherVisible ? launcherY + launcherH : 0)

    readonly property var trayItems: SystemTray.items.values

    // Set while a tray item's own menu is open, which also suspends the bar's
    // leave-to-dismiss: the pointer is on the popup, not on the bar.
    property var trayMenuItem: null
    property rect trayMenuRect: Qt.rect(0, 0, 1, 1)

    // ----- content staging --------------------------------------------------

    // The chevron is erased by the menu committing, not hidden by it: the same
    // stroke that was drawn on hover retracts as the frames start. Its own
    // window on the peek driver is what the hover lead-in delays.
    readonly property real chevronDraw: Theme.clamp01(
        Theme.pen(Theme.peekPhase(peekDraw))
        - Theme.phaseMs(menuDraw, 0, Theme.drawChevronClearMs))
    // The resting indicator is the chevron's opposite, and is erased first:
    // the lead-in is the pause between the two. `peek` is set in the open state
    // too, so this needs no term for the menu.
    readonly property real minuteDraw: 1 - Theme.pen(Theme.peekErasePhase(peekDraw))

    // Tiles accept the pointer once their frames are substantially drawn,
    // rather than the instant the silhouette arrives.
    readonly property bool menuInteractive: Theme.phase(
        menuDraw, Theme.drawFrame, Theme.columns.length - 1) > 0.5
    readonly property bool dockInteractive:
        Theme.phase(menuDraw, Theme.drawTrayIcons) > 0.5
    readonly property bool launcherInteractive: launcherVisible
        && Theme.launcherPhase(launcherDraw, Theme.drawLauncherRow, 0) > 0.5

    readonly property real clockCenterY: Theme.mix(
        Theme.mix(Theme.clockCenterCollapsed, Theme.clockCenterPeek, peek),
        Theme.clockCenterMenu, open)

    // ----- clocks -----------------------------------------------------------

    SystemClock {
        id: minuteClock
        precision: SystemClock.Minutes
    }

    // Seconds only tick while the menu is on screen. Every repaint damages the
    // layer and re-runs the compositor's glass pipeline over the whole surface,
    // so the resting pill is deliberately a once-a-minute widget.
    SystemClock {
        id: secondClock
        precision: SystemClock.Seconds
        enabled: bar.open > 0.01
    }

    readonly property string timeText: Qt.formatDateTime(minuteClock.date, "HH:mm")
    readonly property string dateText: Qt.formatDateTime(minuteClock.date, "yyyy.MM.dd")
        + "  " + ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][minuteClock.date.getDay()]

    // ----- interaction ------------------------------------------------------

    // One MouseArea for the entire silhouette. Columns are hit-tested from here
    // rather than owning MouseAreas of their own: a child grabbing hover would
    // read as "pointer left the bar" and close the menu under the cursor.
    function columnAt(px, py) {
        if (!menuInteractive)
            return -1;
        if (py < Theme.tileY - 8 || py > Theme.tileY + Theme.tileSize + 8)
            return -1;
        for (var i = 0; i < Theme.columns.length; i++) {
            if (Math.abs(px - Theme.columns[i] * shapeW) <= Theme.tileSize / 2 + 8)
                return i;
        }
        return -1;
    }

    // Tray icons, hit-tested in the same coordinates from the same MouseArea.
    function trayAt(px, py) {
        if (!dockInteractive || trayItems.length === 0)
            return -1;
        var lx = px - (dockContentX - blobX);
        var ly = py - (dockContentY - blobY);
        if (ly < Theme.trayFrameY || ly > Theme.trayFrameY + Theme.trayFrameHeight)
            return -1;
        for (var i = 0; i < trayItems.length; i++) {
            var left = dockIsland.tray.iconX(i);
            if (lx >= left - Theme.trayIconGap / 2
                && lx <= left + Theme.trayIconSize + Theme.trayIconGap / 2)
                return i;
        }
        return -1;
    }

    // The clock is the bar's switch: the pill opens the menu and the headline
    // it grows into closes it again. Everything else inside the silhouette is
    // surface, not button, so a click that lands on it does nothing -- missing
    // a tile by a few pixels used to dismiss the whole menu.
    function onHandle(px, py) {
        if (!opened)
            return true;
        return py <= Theme.axisY;
    }

    // Whether a point is over the launcher panel at all, rather than over one
    // of its rows: the wheel belongs to the whole panel, the query row and the
    // empty space below the last result included.
    function overLauncher(px, py) {
        if (!launcherVisible)
            return false;
        var lx = px - (launcherContentX - blobX);
        var ly = py - (launcherContentY - blobY);
        return lx >= 0 && lx <= Theme.launcherWidth
            && ly >= 0 && ly <= Theme.launcherHeight;
    }

    // Result rows, hit-tested from the same MouseArea in the same coordinates.
    function launcherRowAt(px, py) {
        if (!launcherInteractive)
            return -1;
        return launcherIsland.rowAt(px - (launcherContentX - blobX),
                                    py - (launcherContentY - blobY));
    }

    function closeTrayMenu() {
        trayMenuItem = null;
    }

    // Status notifier convention: primary activates, secondary opens the item's
    // own menu. Items that declare themselves menu-only get the menu either way.
    function activateTray(index, button) {
        var item = trayItems[index];
        if (!item)
            return;
        if (button === Qt.RightButton || item.onlyMenu) {
            if (!item.hasMenu) {
                item.secondaryActivate();
                return;
            }
            var left = dockIsland.tray.iconX(index);
            trayMenuRect = Qt.rect(
                dockContentX + left,
                dockContentY + Theme.trayFrameY
                    + (Theme.trayFrameHeight - Theme.trayIconSize) / 2,
                Theme.trayIconSize, Theme.trayIconSize);
            trayMenuItem = item;
        } else {
            closeTrayMenu();
            item.activate();
        }
    }

    MouseArea {
        id: hit
        // Spans both islands, including the gap between them, so one handler
        // owns every hover and click the bar can receive. The layer's input
        // mask is still only the two silhouettes, so the gap itself passes
        // through to the windows below.
        x: bar.blobX
        y: bar.blobY
        width: bar.shapeW
        height: bar.lowerBottom - bar.blobY
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        readonly property int hoverColumn: containsMouse ? bar.columnAt(mouseX, mouseY) : -1
        readonly property int hoverTray: containsMouse ? bar.trayAt(mouseX, mouseY) : -1
        readonly property int hoverRow: containsMouse ? bar.launcherRowAt(mouseX, mouseY) : -1

        // The cursor says which parts of the silhouette are actually pressable,
        // now that the rest of it swallows clicks.
        cursorShape: hoverColumn >= 0 || hoverTray >= 0 || hoverRow >= 0
            || bar.onHandle(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered: {
            closeTimer.stop();
            if (bar.mode === 0)
                bar.mode = 1;
        }
        // A single layer surface cannot see clicks outside itself, so leaving
        // the silhouette is what dismisses the menu. The grace period keeps a
        // clipped corner or a fast diagonal from closing it; an open tray menu
        // suspends it entirely, since the pointer is then on the popup.
        onExited: {
            if (!bar.trayMenuItem)
                closeTimer.restart();
        }

        // Scrolling is owned here for the same reason hover is: one handler
        // for every pointer event the bar receives. A WheelHandler inside the
        // panel was never reached.
        //
        // Deltas are normalized to rows before anything moves, so a touchpad's
        // stream of small pixel deltas and a mouse's 15-degree notches scroll
        // the same list at the same rate, and the remainder is carried rather
        // than rounded away -- otherwise a slow touchpad scroll moves nothing
        // at all, every event rounding to zero on its own.
        property real wheelCarry: 0

        onWheel: (event) => {
            if (!bar.overLauncher(event.x, event.y)) {
                event.accepted = false;
                return;
            }
            wheelCarry += event.pixelDelta.y !== 0
                ? event.pixelDelta.y / Theme.launcherRowHeight
                : event.angleDelta.y / Theme.wheelNotch;
            var steps = Math.trunc(wheelCarry);
            if (steps === 0)
                return;
            wheelCarry -= steps;
            launcherIsland.scrollBy(-steps);
        }

        onClicked: (event) => {
            var tray = bar.trayAt(event.x, event.y);
            if (tray >= 0) {
                bar.activateTray(tray, event.button);
                return;
            }
            if (event.button !== Qt.LeftButton)
                return;
            bar.closeTrayMenu();
            var row = bar.launcherRowAt(event.x, event.y);
            if (row >= 0) {
                launcherIsland.activate(row);
                return;
            }
            var column = bar.columnAt(event.x, event.y);
            if (column >= 0) {
                bar.chooseSection(column);
                return;
            }
            if (bar.onHandle(event.x, event.y))
                bar.mode = bar.mode >= 2 ? 1 : 2;
        }
    }

    Timer {
        id: closeTimer
        // The launcher is the one state where the pointer is not the input, so
        // a bump of the mouse should not take a half-typed query with it.
        interval: bar.launcherOpen ? Theme.launcherGraceMs : Theme.closeGraceMs
        onTriggered: bar.mode = 0
    }

    // ----- silhouette -------------------------------------------------------

    LiquidGroup {
        anchors.fill: parent
        blendRadius: Theme.blendRadius
        tint: Theme.tint
        shapes: [
            LiquidShape {
                x: bar.blobX
                y: bar.blobY
                width: bar.shapeW
                height: bar.shapeH
                radius: bar.shapeR
            },
            LiquidShape {
                x: bar.dockX
                y: bar.dockY
                width: bar.dockW
                height: bar.dockH
                radius: bar.dockR
            },
            LiquidShape {
                x: bar.launcherX
                y: bar.launcherY
                width: bar.launcherW
                height: bar.launcherH
                radius: bar.launcherR
            }
        ]
    }

    // ----- content ----------------------------------------------------------

    Item {
        id: content
        x: bar.blobX
        y: bar.blobY
        width: bar.shapeW
        height: bar.shapeH
        // Menu content must not survive outside a silhouette that is shrinking
        // back into the pill faster than the content can fade.
        clip: true

        // The clock is never rebuilt: the same readout grows from pill label to
        // menu headline, which is what makes the two states read as one object.
        Text {
            id: readout
            text: bar.timeText
            color: Theme.textPrimary
            font.family: Theme.fontMono
            font.weight: Font.Light
            // Rounded so resting states rasterize crisply; the morph still
            // reads as continuous because position and tracking are not.
            font.pixelSize: Math.round(Theme.mix(
                Theme.mix(Theme.clockSizeCollapsed, Theme.clockSizePeek, bar.peek),
                Theme.clockSizeMenu, bar.open))
            font.letterSpacing: Theme.mix(1.5, 3, bar.open)
            // Tracking adds a trailing gap after the last glyph, so the naive
            // centre is off by half of it.
            x: (content.width - width) / 2 + font.letterSpacing / 2
            y: bar.clockCenterY - height / 2
        }

        // Resting indicator: minutes elapsed in the hour, plotted. Updates once
        // a minute, which is the entire repaint budget of the collapsed pill.
        Item {
            id: minuteTrack
            readonly property real span: 56
            width: span
            x: (content.width - width) / 2
            y: bar.clockCenterY + 11
            visible: bar.minuteDraw > 0.001

            Rectangle {
                width: minuteTrack.span * bar.minuteDraw
                height: bar.hairline
                color: Theme.lineFaint
                opacity: Theme.opGrid + 0.08
            }
            // The value is clipped by the pen rather than drawn over it, so the
            // track is never longer than the line that carries it.
            Rectangle {
                width: minuteTrack.span * Math.min(
                    minuteClock.date.getMinutes() / 60, bar.minuteDraw)
                height: bar.hairline
                color: Theme.lineStrong
                opacity: Theme.opNormal
            }
        }

        // Peek affordance: one stroke, under the clock, saying only that there
        // is somewhere to go. Three of them pre-announced a layout the hover
        // state has no other way to explain.
        Chevron {
            span: Theme.chevronSpan
            drop: Theme.chevronDrop
            x: (content.width - span) / 2
            y: Theme.mix(Theme.chevronCenterY - 5, Theme.chevronCenterY, bar.peek)
            ink: Theme.lineStrong
            opacity: Theme.opNormal
            progress: bar.chevronDraw
            visible: progress > 0.001
        }

        // ----- main menu ----------------------------------------------------

        // Nothing here carries a group opacity: each element owns its own
        // window on `menuDraw`, so the menu resolves stroke by stroke instead
        // of fading in as one sheet.
        Item {
            id: menu
            width: content.width
            height: content.height
            visible: bar.menuDraw > 0.001

            // Written a character at a time. Its box is measured from the whole
            // string, so the readout fills in place instead of sliding.
            TypedText {
                content: bar.dateText
                capacity: Theme.dateChars
                // Linear, not `pen`: typeCharMs is meant to be the rate itself.
                reveal: Theme.phase(bar.menuDraw, Theme.drawDate)
                ink: Theme.textMuted
                pixelSize: 10
                letterSpacing: 4
                x: (menu.width - width) / 2
                y: Theme.dateY
                opacity: Theme.opNormal
                visible: reveal > 0.001
            }

            AxisRule {
                x: Theme.axisInset
                y: Theme.axisY
                width: menu.width - Theme.axisInset * 2
                draw: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawAxis))
                reveal: Theme.phase(bar.menuDraw, Theme.drawSweep)
                // The axis is the second hand: one full sweep per minute.
                progress: (secondClock.seconds + 1) / 60
            }

            // Drop lines tie each tile to its division on the axis, which is
            // what makes the row read as plotted rather than merely arranged.
            // They grow down out of the rule, in column order.
            Repeater {
                model: Theme.columns.length
                delegate: Rectangle {
                    required property int index
                    readonly property real full: Theme.tileY - Theme.axisY - 7
                    readonly property real draw: Theme.pen(
                        Theme.phase(bar.menuDraw, Theme.drawDrop, index))

                    x: Theme.snap(Theme.columns[index] * menu.width
                                  - bar.hairline / 2, Screen.devicePixelRatio)
                    y: Theme.axisY + 7
                    width: bar.hairline
                    height: full * draw
                    color: Theme.lineFaint
                    opacity: hit.hoverColumn === index ? Theme.opNormal : Theme.opGrid
                    visible: draw > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }

            Repeater {
                model: bar.sections
                delegate: IconTile {
                    required property int index
                    required property var modelData

                    source: modelData.icon
                    label: modelData.label
                    hovered: hit.hoverColumn === index
                    x: Theme.columns[index] * menu.width - width / 2
                    y: Theme.tileY

                    draw: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawFrame, index))
                    glyphReveal: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawGlyph, index))
                    labelReveal: Theme.phase(bar.menuDraw, Theme.drawLabel, index)
                }
            }
        }
    }

    // ----- the lower island -------------------------------------------------

    DockIsland {
        id: dockIsland
        x: bar.dockX
        y: bar.dockY
        width: bar.dockW
        height: bar.dockH
        visible: bar.dockVisible

        trayItems: bar.trayItems
        trayHovered: hit.hoverTray

        batteryIconReveal: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawBatteryIcon))
        batteryValueReveal: Theme.phase(bar.menuDraw, Theme.drawBatteryValue)
        batteryStatusReveal: Theme.phase(bar.menuDraw, Theme.drawBatteryStatus)
        batteryGaugeDraw: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawBatteryGauge))
        trayFrameDraw: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawTrayFrame))
        trayIconsReveal: Theme.pen(Theme.phase(bar.menuDraw, Theme.drawTrayIcons))
    }

    LauncherIsland {
        id: launcherIsland
        x: bar.launcherX
        y: bar.launcherY
        width: bar.launcherW
        height: bar.launcherH
        visible: bar.launcherVisible

        draw: bar.launcherDraw
        hovered: hit.hoverRow
        // Holding the keyboard is a state of the panel, not of the window: the
        // layer asks for on-demand focus from the same flag.
        active: bar.launcherOpen

        onLaunched: bar.mode = 0
        onDismissed: bar.setSection(-1)
    }
}
