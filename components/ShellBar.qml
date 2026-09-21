import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import ".."
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
        { icon: Qt.resolvedUrl("../assets/icons/setting.svg"), label: "SETTINGS" },
        { icon: Qt.resolvedUrl("../assets/icons/power.svg"), label: "POWER" }
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
    // The launcher's list has a driver of its own, because it is redrawn when
    // the corpus under it changes and the frame around it is not.
    property real launcherList: 0
    property real clock: 0
    property real clockDraw: 0
    property real settings: 0
    property real settingsDraw: 0
    // The dock is a pair: itself and the media island under it. They arrive
    // and leave as one thing, a beat apart.
    property real dockDraw: 0
    property real power: 0
    property real powerDraw: 0
    property real media: 0
    property real mediaDraw: 0
    property real toast: 0
    property real toastDraw: 0
    // 1..0 over the toast's hold. The animation is the clock: when it finishes
    // the toast is taken away, so pausing it on hover is all "hold while the
    // pointer is here" has to mean.
    property real toastLife: 1
    // The settings panel's pane is drawn again every time another section of
    // it is chosen, so it needs a driver the tabs do not share.
    property real settingsPane: 0

    readonly property bool engaged: mode >= 1
    readonly property bool opened: mode >= 2
    readonly property bool launcherOpen: section === 0
    readonly property bool clockOpen: section === 1
    readonly property bool settingsOpen: section === 2
    readonly property bool powerOpen: section === 3

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

    // The menu and the socket beneath it are animated separately, not as one
    // sequence per direction. They have to be startable and stoppable on their
    // own: swapping panels while the menu is still expanding must replace what
    // is in the socket without freezing the menu halfway. The timings are
    // unchanged by the split -- each socket animation still carries the delay
    // that makes it serial with the menu.
    //
    // Every delay is a plain constant from theme.js, never `mode >= n ? a : b`:
    // a Behavior would read such a binding one transition late, and that is
    // what once made the island leave with the menu when opening from hover.

    NumberAnimation {
        id: menuIn
        target: bar; property: "open"; to: 1
        duration: Theme.durMenu
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }

    SequentialAnimation {
        id: menuOut
        // The socket empties first; the menu only starts to collapse once the
        // island is most of the way home.
        PauseAnimation { duration: Theme.menuCloseStartMs }
        NumberAnimation {
            target: bar; property: "open"; to: 0
            duration: Theme.durMenu
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }

    // ----- the socket -------------------------------------------------------
    //
    // One pair of animations per island that can occupy the socket, and no
    // animation that knows about more than one of them. A swap is then just
    // "the one leaving runs its Out, the one arriving runs its In", which is
    // the same code whichever two islands are involved and stays the same code
    // when a third is added.
    //
    // Each In carries its own pause, whose duration is WRITTEN rather than
    // bound: `dockStartMs` when the menu is opening, `socketAdmitMs` when one
    // island is replacing another. A binding here would be read one transition
    // late -- the same trap that once made the island leave with the menu.

    SequentialAnimation {
        id: dockIn
        PauseAnimation { id: dockInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "dock"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            // The dock's contents start with the dock, on the dock's own
            // driver -- not on the menu's, which is already finished whenever
            // the dock is swapped back in.
            NumberAnimation {
                target: bar; property: "dockDraw"; to: 1
                duration: Theme.durDockDraw
                easing.type: Easing.Linear
            }
            // The second box of the same thing: extruded out of the first one
            // rather than announced separately.
            SequentialAnimation {
                PauseAnimation { duration: Theme.mediaTrailMs }
                ParallelAnimation {
                    NumberAnimation {
                        target: bar; property: "media"; to: 1
                        duration: Theme.socketEmergeMs
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.dockCurve
                    }
                    NumberAnimation {
                        target: bar; property: "mediaDraw"; to: 1
                        duration: Theme.durMediaDraw
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // Leaving together, with no trail: the pair is absorbed, not unstacked.
    ParallelAnimation {
        id: dockOut
        NumberAnimation {
            target: bar; property: "dock"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "dockDraw"; to: 0
            duration: Theme.durDockUndraw
            easing.type: Easing.Linear
        }
        NumberAnimation {
            target: bar; property: "media"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "mediaDraw"; to: 0
            duration: Theme.durMediaUndraw
            easing.type: Easing.Linear
        }
    }

    // A panel's contents start with the panel, as the dock's do.
    SequentialAnimation {
        id: launcherIn
        PauseAnimation { id: launcherInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "launcher"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            NumberAnimation {
                target: bar; property: "launcherDraw"; to: 1
                duration: Theme.durLauncherDraw
                easing.type: Easing.Linear
            }
        }
    }

    ParallelAnimation {
        id: launcherOut
        NumberAnimation {
            target: bar; property: "launcher"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "launcherDraw"; to: 0
            duration: Theme.durLauncherUndraw
            easing.type: Easing.Linear
        }
        NumberAnimation {
            target: bar; property: "launcherList"; to: 0
            duration: Theme.durLauncherListUndraw
            easing.type: Easing.Linear
        }
    }

    // Redrawn on its own: once when the panel arrives, and again whenever the
    // field is pointed at a different corpus. Its delay is written rather than
    // bound, for the reason given above.
    SequentialAnimation {
        id: launcherListIn
        PauseAnimation { id: launcherListDelay }
        NumberAnimation {
            target: bar; property: "launcherList"; to: 1
            duration: Theme.durLauncherListDraw
            easing.type: Easing.Linear
        }
    }

    function drawLauncherList(delayMs) {
        launcherListIn.stop();
        launcherList = 0;
        launcherListDelay.duration = delayMs;
        launcherListIn.restart();
    }

    SequentialAnimation {
        id: clockIn
        PauseAnimation { id: clockInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "clock"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            NumberAnimation {
                target: bar; property: "clockDraw"; to: 1
                duration: Theme.durClockDraw
                easing.type: Easing.Linear
            }
        }
    }

    ParallelAnimation {
        id: clockOut
        NumberAnimation {
            target: bar; property: "clock"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "clockDraw"; to: 0
            duration: Theme.durClockUndraw
            easing.type: Easing.Linear
        }
    }

    SequentialAnimation {
        id: settingsIn
        PauseAnimation { id: settingsInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "settings"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            NumberAnimation {
                target: bar; property: "settingsDraw"; to: 1
                duration: Theme.durSettingsDraw
                easing.type: Easing.Linear
            }
        }
    }

    ParallelAnimation {
        id: settingsOut
        NumberAnimation {
            target: bar; property: "settings"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "settingsDraw"; to: 0
            duration: Theme.durSettingsUndraw
            easing.type: Easing.Linear
        }
        NumberAnimation {
            target: bar; property: "settingsPane"; to: 0
            duration: Theme.durSettingsPaneUndraw
            easing.type: Easing.Linear
        }
    }

    // The pane, redrawn on its own: once when the panel arrives, and again
    // whenever a different section of it is chosen. Its delay is written
    // rather than bound, for the reason given above.
    SequentialAnimation {
        id: settingsPaneIn
        PauseAnimation { id: settingsPaneDelay }
        NumberAnimation {
            target: bar; property: "settingsPane"; to: 1
            duration: Theme.durSettingsPaneDraw
            easing.type: Easing.Linear
        }
    }

    function drawSettingsPane(delayMs) {
        settingsPaneIn.stop();
        settingsPane = 0;
        settingsPaneDelay.duration = delayMs;
        settingsPaneIn.restart();
    }

    SequentialAnimation {
        id: toastIn
        PauseAnimation { id: toastInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "toast"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            NumberAnimation {
                target: bar; property: "toastDraw"; to: 1
                duration: Theme.durToastDraw
                easing.type: Easing.Linear
            }
        }
    }

    ParallelAnimation {
        id: toastOut
        NumberAnimation {
            target: bar; property: "toast"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "toastDraw"; to: 0
            duration: Theme.durToastUndraw
            easing.type: Easing.Linear
        }
    }

    NumberAnimation {
        id: toastLifeOut
        target: bar; property: "toastLife"; to: 0
        easing.type: Easing.Linear
        // Reaching the end is what dismisses; being stopped is not, or
        // retracting the toast by hand would dismiss it twice.
        onFinished: Notifications.dismissToast()
    }

    SequentialAnimation {
        id: powerIn
        PauseAnimation { id: powerInDelay }
        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "power"; to: 1
                duration: Theme.socketEmergeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.dockCurve
            }
            NumberAnimation {
                target: bar; property: "powerDraw"; to: 1
                duration: Theme.durPowerDraw
                easing.type: Easing.Linear
            }
        }
    }

    ParallelAnimation {
        id: powerOut
        NumberAnimation {
            target: bar; property: "power"; to: 0
            duration: Theme.socketRetractMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.dockCurve
        }
        NumberAnimation {
            target: bar; property: "powerDraw"; to: 0
            duration: Theme.durPowerUndraw
            easing.type: Easing.Linear
        }
    }

    // The socket, addressed by section index: -1 is the dock, 0 and up are the
    // menu's tiles in order. An arrival is not one of them -- it appears below
    // whatever is in the socket rather than instead of it, so it has its own
    // pair of animations and never takes the socket's place.
    readonly property int socketNone: -2

    // What is in the socket right now, so a swap knows what has to leave.
    property int occupant: socketNone
    function islandIn(which) {
        return which === 0 ? launcherIn : which === 1 ? clockIn
            : which === 2 ? settingsIn : which === 3 ? powerIn : dockIn;
    }

    function islandInDelay(which) {
        return which === 0 ? launcherInDelay : which === 1 ? clockInDelay
            : which === 2 ? settingsInDelay
            : which === 3 ? powerInDelay : dockInDelay;
    }

    function islandOut(which) {
        return which === 0 ? launcherOut : which === 1 ? clockOut
            : which === 2 ? settingsOut : which === 3 ? powerOut : dockOut;
    }

    function stopSocket() {
        dockIn.stop(); dockOut.stop();
        launcherIn.stop(); launcherOut.stop(); launcherListIn.stop();
        clockIn.stop(); clockOut.stop();
        settingsIn.stop(); settingsOut.stop(); settingsPaneIn.stop();
        powerIn.stop(); powerOut.stop();
    }

    // Whatever is in the socket leaves and the next thing arrives. The same
    // two calls whichever two islands are involved.
    function swapSocket(next, delayMs) {
        stopSocket();
        if (occupant !== socketNone)
            islandOut(occupant).restart();
        occupant = next;
        if (next !== socketNone)
            fillSocket(next, delayMs);
    }

    // Written, not bound, and written before the animation is started.
    function fillSocket(which, delayMs) {
        islandInDelay(which).duration = delayMs;
        islandIn(which).restart();
        // A list trails the rule it hangs from, measured from the same
        // instant the island starts moving.
        if (which === 0)
            drawLauncherList(delayMs + Theme.launcherListLeadMs);
        else if (which === 2)
            drawSettingsPane(delayMs + Theme.settingsPaneLeadMs);
    }

    // Only one island is ever non-zero, so all of them are simply sent home
    // and whichever was showing is the one that reads as leaving.
    function emptySocket() {
        occupant = socketNone;
        dockOut.restart();
        launcherOut.restart();
        clockOut.restart();
        settingsOut.restart();
        powerOut.restart();
    }

    // ----- arrivals ---------------------------------------------------------
    //
    // An arrival is always shown, and always at the bottom: it appears under
    // the resting pill when nothing else is open and under whatever panel the
    // socket is holding when something is. It never replaces a panel, because
    // it is not something the reader asked for and taking their place away to
    // show it would be the wrong trade.

    readonly property var toastItem: Notifications.toast

    onToastItemChanged: {
        toastIn.stop(); toastOut.stop();
        startToastLife();
        if (toastItem) {
            // A second arrival redraws the same island rather than retracting
            // it and pushing it out again.
            toastDraw = 0;
            toastInDelay.duration = 0;
            toastIn.restart();
        } else {
            toastOut.restart();
        }
    }

    function startToastLife() {
        toastLifeOut.stop();
        toastLife = 1;
        var ms = Notifications.toastMs;
        if (ms <= 0)
            return;
        // Written, not bound: a duration read one transition late would hold
        // the next toast for as long as the last one asked for.
        toastLifeOut.duration = ms;
        toastLifeOut.restart();
    }

    // Hovering holds the arrival: the pointer is on its way to answering it.
    function holdToast(hold) {
        if (hold)
            toastLifeOut.pause();
        else if (toastLifeOut.paused)
            toastLifeOut.resume();
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
            menuOut.stop(); menuDrawOut.stop();
            menuIn.restart(); menuDrawIn.restart();
            // Which island the menu opens with. Everything but a keybinding
            // opens with the dock, because closing always resets the section.
            swapSocket(section, Theme.dockStartMs);
        } else {
            menuIn.stop(); menuDrawIn.stop(); stopSocket();
            // The next opening starts from the state it always starts from.
            section = -1;
            menuOut.restart(); menuDrawOut.restart(); emptySocket();
        }
    }

    // A tile either owns a panel here or is still only a signal to the shell.
    function chooseSection(index) {
        if (index > 3) {
            sectionRequested(index);
            return;
        }
        setSection(section === index ? -1 : index);
    }

    // A panel is shown as it was designed to be shown, not as the last reader
    // left it: a query still in the field, a calendar still on another month,
    // a tile still armed. Every way in goes through here, so a panel opened by
    // a keybinding starts from the same place as one opened by its tile.
    function prepareSection(which) {
        if (which === 0)
            launcherIsland.reset();
        else if (which === 1)
            clockIsland.reset();
        else if (which === 2)
            settingsIsland.reset();
        else if (which === 3)
            powerIsland.reset();
    }

    function setSection(next) {
        if (section === next)
            return;
        hit.wheelCarry = 0;
        section = next;
        prepareSection(next);
        swapSocket(next, Theme.socketAdmitMs);
    }

    // ----- external control -------------------------------------------------
    //
    // The launcher is the one thing here a keybinding is expected to reach, so
    // it has an entry point that does not go through the pointer. Opening from
    // collapsed puts the panel in the socket *before* the menu commits, so the
    // dock is never extruded only to be swallowed again a frame later.

    function openLauncher() {
        if (opened) {
            setSection(0);
            return;
        }
        section = 0;
        prepareSection(0);
        mode = 2;
    }

    function closeLauncher() {
        if (launcherOpen)
            mode = 0;
    }

    function toggleLauncher() {
        if (launcherOpen)
            mode = 0;
        else
            openLauncher();
    }

    // The same panel with its field pointed at the clipboard. Opening it this
    // way is one gesture, so it does not go through the applications list on
    // the way.
    function toggleClipboard() {
        if (launcherOpen && launcherIsland.clipping) {
            mode = 0;
            return;
        }
        openLauncher();
        launcherIsland.mode = Theme.launcherClipMode;
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

    // ----- the clock island -------------------------------------------------
    //
    // Same socket, same terms. Only the height differs, and the surface was
    // sized for the tallest of them.

    readonly property real clockW: Theme.clockWidth * clock
    readonly property real clockH: Theme.clockHeight * clock
    readonly property real clockR: Theme.cornerRadius(Theme.clockRadius, clockW, clockH)
    readonly property real clockX: blobX + (shapeW - clockW) / 2
    readonly property real clockCenterY: Theme.mix(
        blobY + shapeH - Theme.dockEmergeDepth,
        blobY + shapeH + Theme.dockGap + Theme.clockHeight / 2,
        clock)
    readonly property real clockY: clockCenterY - clockH / 2
    readonly property bool clockVisible: clock > 0.001

    readonly property real clockContentX: clockX + (clockW - Theme.clockWidth) / 2
    readonly property real clockContentY: clockY + (clockH - Theme.clockHeight) / 2

    // ----- the settings island ----------------------------------------------

    readonly property real settingsW: Theme.settingsWidth * settings
    readonly property real settingsH: Theme.settingsHeight * settings
    readonly property real settingsR: Theme.cornerRadius(
        Theme.settingsRadius, settingsW, settingsH)
    readonly property real settingsX: blobX + (shapeW - settingsW) / 2
    readonly property real settingsCenterY: Theme.mix(
        blobY + shapeH - Theme.dockEmergeDepth,
        blobY + shapeH + Theme.dockGap + Theme.settingsHeight / 2,
        settings)
    readonly property real settingsY: settingsCenterY - settingsH / 2
    readonly property bool settingsVisible: settings > 0.001

    readonly property real settingsContentX:
        settingsX + (settingsW - Theme.settingsWidth) / 2
    readonly property real settingsContentY:
        settingsY + (settingsH - Theme.settingsHeight) / 2

    // ----- the power island -------------------------------------------------

    readonly property real powerW: Theme.powerWidth * power
    readonly property real powerH: Theme.powerHeight * power
    readonly property real powerR: Theme.cornerRadius(
        Theme.powerRadius, powerW, powerH)
    readonly property real powerX: blobX + (shapeW - powerW) / 2
    readonly property real powerCenterY: Theme.mix(
        blobY + shapeH - Theme.dockEmergeDepth,
        blobY + shapeH + Theme.dockGap + Theme.powerHeight / 2,
        power)
    readonly property real powerY: powerCenterY - powerH / 2
    readonly property bool powerVisible: power > 0.001

    readonly property real powerContentX: powerX + (powerW - Theme.powerWidth) / 2
    readonly property real powerContentY: powerY + (powerH - Theme.powerHeight) / 2

    // ----- the toast island -------------------------------------------------
    //
    // Narrower than the panels, because it comes out of the shape above it
    // rather than out of the menu, and always the last thing on the surface.

    // The lowest edge the socket currently reaches, which is what an arrival
    // is extruded from: the pill when the socket is empty, the panel when it
    // is not. It moves while a panel grows, and the toast moves with it.
    readonly property real socketBottom: Math.max(
        blobY + shapeH,
        dockVisible ? dockY + dockH : 0,
        mediaVisible ? mediaY + mediaH : 0,
        launcherVisible ? launcherY + launcherH : 0,
        clockVisible ? clockY + clockH : 0,
        settingsVisible ? settingsY + settingsH : 0,
        powerVisible ? powerY + powerH : 0)

    readonly property real toastW: Theme.toastWidth * toast
    readonly property real toastH: Theme.toastHeight * toast
    readonly property real toastR: Theme.cornerRadius(Theme.toastRadius, toastW, toastH)
    readonly property real toastX: blobX + (shapeW - toastW) / 2
    readonly property real toastCenterY: Theme.mix(
        socketBottom - Theme.dockEmergeDepth,
        socketBottom + Theme.dockGap + Theme.toastHeight / 2,
        toast)
    readonly property real toastY: toastCenterY - toastH / 2
    readonly property bool toastVisible: toast > 0.001

    readonly property real toastContentX: toastX + (toastW - Theme.toastWidth) / 2
    readonly property real toastContentY: toastY + (toastH - Theme.toastHeight) / 2

    // The lowest point anything currently reaches, which is what the pointer
    // has to be able to travel over.
    readonly property real lowerBottom: Math.max(
        socketBottom, toastVisible ? toastY + toastH : 0)

    // ----- the media island -------------------------------------------------
    //
    // Born out of the dock's lower edge on the same terms the dock is born out
    // of the menu's, and it follows the dock while the dock is still growing.

    readonly property real dockBottom: dockY + dockH
    readonly property real mediaW: Theme.mediaWidth * media
    readonly property real mediaH: Theme.mediaHeight * media
    readonly property real mediaR: Theme.cornerRadius(
        Theme.mediaRadius, mediaW, mediaH)
    readonly property real mediaX: blobX + (shapeW - mediaW) / 2
    readonly property real mediaCenterY: Theme.mix(
        dockBottom - Theme.dockEmergeDepth,
        dockBottom + Theme.dockGap + Theme.mediaHeight / 2,
        media)
    readonly property real mediaY: mediaCenterY - mediaH / 2
    readonly property bool mediaVisible: media > 0.001

    readonly property real mediaContentX: mediaX + (mediaW - Theme.mediaWidth) / 2
    readonly property real mediaContentY: mediaY + (mediaH - Theme.mediaHeight) / 2

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
        Theme.dockPhase(dockDraw, Theme.drawTrayIcons) > 0.5
    readonly property bool launcherInteractive: launcherVisible
        && Theme.launcherPhase(launcherDraw, Theme.drawLauncherRow, 0) > 0.5
    readonly property bool clockInteractive: clockVisible
        && Theme.clockPhase(clockDraw, Theme.drawClockMonth) > 0.5
    readonly property bool settingsInteractive: settingsVisible
        && Theme.settingsPhase(settingsDraw, Theme.drawSettingsLabel, 0) > 0.5
    readonly property bool settingsPaneInteractive: settingsInteractive
        && Theme.panePhase(settingsPane, Theme.drawPaneControl) > 0.5
    readonly property bool settingsListInteractive: settingsInteractive
        && Theme.panePhase(settingsPane, Theme.drawPaneRow, 0) > 0.5

    // The passphrase prompt is the only thing outside the launcher that reads
    // typing, so it is the other reason the layer asks for the keyboard.
    readonly property bool wantsKeyboard:
        launcherOpen || (settingsOpen && settingsIsland.prompting)

    // The headline readout's centre line. Named for the element rather than for
    // the clock, now that an island carries that name too.
    readonly property real readoutCenterY: Theme.mix(
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

    // The month controls, hit-tested in the same coordinates as everything
    // else the bar owns.
    function clockControlAt(px, py) {
        if (!clockInteractive)
            return -1;
        return clockIsland.controlAt(px - (clockContentX - blobX),
                                     py - (clockContentY - blobY));
    }

    // The settings tabs and whatever control the chosen section puts in its
    // pane, hit-tested in the same coordinates as everything else.
    function settingsTabAt(px, py) {
        if (!settingsInteractive)
            return -1;
        return settingsIsland.tabAt(px - (settingsContentX - blobX),
                                    py - (settingsContentY - blobY));
    }

    function settingsControlAt(px, py) {
        if (!settingsPaneInteractive)
            return -1;
        return settingsIsland.controlAt(px - (settingsContentX - blobX),
                                        py - (settingsContentY - blobY));
    }

    function settingsRowAt(px, py) {
        if (!settingsListInteractive)
            return -1;
        return settingsIsland.rowAt(px - (settingsContentX - blobX),
                                    py - (settingsContentY - blobY));
    }

    // The dismiss mark sits inside a row, so it has to be asked about first.
    function settingsCloseAt(px, py) {
        if (!settingsListInteractive)
            return -1;
        return settingsIsland.closeAt(px - (settingsContentX - blobX),
                                      py - (settingsContentY - blobY));
    }

    function settingsScrollAt(px, py) {
        if (!settingsListInteractive)
            return -1;
        return settingsIsland.scrollAt(px - (settingsContentX - blobX),
                                       py - (settingsContentY - blobY));
    }

    // The panel takes the wheel over its list, the way the launcher does.
    function overSettings(px, py) {
        if (!settingsVisible)
            return false;
        var lx = px - (settingsContentX - blobX);
        var ly = py - (settingsContentY - blobY);
        return lx >= 0 && lx <= Theme.settingsWidth
            && ly >= Theme.settingsListY && ly <= Theme.settingsHeight;
    }

    readonly property bool powerInteractive: powerVisible
        && Theme.powerPhase(powerDraw, Theme.drawPowerFrame, 0) > 0.5

    function powerTileAt(px, py) {
        if (!powerInteractive)
            return -1;
        return powerIsland.tileAt(px - (powerContentX - blobX),
                                  py - (powerContentY - blobY));
    }

    // ----- the media island's controls --------------------------------------

    readonly property bool mediaInteractive: mediaVisible
        && Theme.mediaPhase(mediaDraw, Theme.drawMediaRow, 0) > 0.5

    function mediaLocalX(px) { return px - (mediaContentX - blobX); }
    function mediaLocalY(py) { return py - (mediaContentY - blobY); }

    function mediaIconAt(px, py) {
        return mediaInteractive
            ? mediaIsland.iconAt(mediaLocalX(px), mediaLocalY(py)) : -1;
    }

    function mediaDeviceAt(px, py) {
        return mediaInteractive
            ? mediaIsland.deviceAt(mediaLocalX(px), mediaLocalY(py)) : -1;
    }

    function mediaSliderAt(px, py) {
        return mediaInteractive
            ? mediaIsland.sliderAt(mediaLocalX(px), mediaLocalY(py)) : -1;
    }

    function mediaControlAt(px, py) {
        return mediaInteractive
            ? mediaIsland.controlAt(mediaLocalX(px), mediaLocalY(py)) : -1;
    }

    function mediaSeekAt(px, py) {
        return mediaInteractive
            && mediaIsland.seekAt(mediaLocalX(px), mediaLocalY(py));
    }

    // An arriving notification is one target, not several: the whole island
    // answers it.
    function overToast(px, py) {
        if (!toastVisible)
            return false;
        var lx = px - (toastContentX - blobX);
        var ly = py - (toastContentY - blobY);
        return lx >= 0 && lx <= Theme.toastWidth
            && ly >= 0 && ly <= Theme.toastHeight;
    }

    // The clock panel takes the wheel too, to page the month.
    function overClock(px, py) {
        if (!clockVisible)
            return false;
        var lx = px - (clockContentX - blobX);
        var ly = py - (clockContentY - blobY);
        return lx >= 0 && lx <= Theme.clockWidth
            && ly >= 0 && ly <= Theme.clockHeight;
    }

    // Result rows, hit-tested from the same MouseArea in the same coordinates.
    // The chip that says which corpus the field is searching.
    function launcherModeAt(px, py) {
        if (!launcherVisible
            || Theme.launcherPhase(launcherDraw, Theme.drawLauncherMode) <= 0.5)
            return -1;
        return launcherIsland.modeAt(px - (launcherContentX - blobX),
                                     py - (launcherContentY - blobY));
    }

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
        readonly property bool hoverLauncherMode: containsMouse
            && bar.launcherModeAt(mouseX, mouseY) >= 0
        readonly property int hoverControl: containsMouse ? bar.clockControlAt(mouseX, mouseY) : -1
        readonly property int hoverTab: containsMouse ? bar.settingsTabAt(mouseX, mouseY) : -1
        readonly property int hoverSetting: containsMouse ? bar.settingsControlAt(mouseX, mouseY) : -1
        readonly property int hoverSettingRow: containsMouse ? bar.settingsRowAt(mouseX, mouseY) : -1
        readonly property int hoverSettingClose: containsMouse ? bar.settingsCloseAt(mouseX, mouseY) : -1
        readonly property int hoverSettingScroll: containsMouse ? bar.settingsScrollAt(mouseX, mouseY) : -1
        readonly property bool hoverToast: containsMouse && bar.overToast(mouseX, mouseY)
        readonly property int hoverMediaIcon: containsMouse ? bar.mediaIconAt(mouseX, mouseY) : -1
        readonly property int hoverMediaDevice: containsMouse ? bar.mediaDeviceAt(mouseX, mouseY) : -1
        readonly property int hoverMediaControl: containsMouse ? bar.mediaControlAt(mouseX, mouseY) : -1
        readonly property bool hoverMediaSeek: containsMouse && bar.mediaSeekAt(mouseX, mouseY)
        readonly property int hoverMediaSlider: containsMouse ? bar.mediaSliderAt(mouseX, mouseY) : -1
        readonly property int hoverPowerTile: containsMouse ? bar.powerTileAt(mouseX, mouseY) : -1

        // A slider is dragged, not only clicked, so the press is what starts
        // it and the release is what ends it. The click that follows has
        // already been answered by then.
        property int dragRow: -1
        property bool dragSeek: false
        property bool pressConsumed: false

        onHoverToastChanged: bar.holdToast(hoverToast)

        // The cursor says which parts of the silhouette are actually pressable,
        // now that the rest of it swallows clicks.
        cursorShape: hoverColumn >= 0 || hoverTray >= 0 || hoverRow >= 0
            || hoverControl >= 0 || hoverTab >= 0 || hoverSetting >= 0
            || hoverLauncherMode
            || hoverSettingRow >= 0 || hoverSettingScroll >= 0
            || hoverMediaIcon >= 0 || hoverMediaDevice >= 0
            || hoverMediaControl >= 0 || hoverMediaSlider >= 0 || hoverMediaSeek
            || hoverPowerTile >= 0
            || hoverToast || bar.onHandle(mouseX, mouseY)
            ? Qt.PointingHandCursor : Qt.ArrowCursor

        // Hovering the bar itself is what opens the peek. The area also spans
        // whatever island is below, and reaching for a toast should not make
        // the pill widen under the pointer on the way.
        onEntered: {
            closeTimer.stop();
            if (bar.mode === 0 && mouseY <= bar.shapeH)
                bar.mode = 1;
        }

        onPositionChanged: (event) => {
            if (bar.mode === 0 && event.y <= bar.shapeH)
                bar.mode = 1;
            if (pressed && dragRow >= 0)
                mediaIsland.setRow(dragRow,
                    mediaIsland.fractionAt(bar.mediaLocalX(event.x)));
        }

        onPressed: (event) => {
            dragRow = -1;
            dragSeek = false;
            if (event.button !== Qt.LeftButton)
                return;
            var slider = bar.mediaSliderAt(event.x, event.y);
            if (slider >= 0) {
                dragRow = slider;
                mediaIsland.setRow(slider,
                    mediaIsland.fractionAt(bar.mediaLocalX(event.x)));
            } else if (bar.mediaSeekAt(event.x, event.y)) {
                // Seeking lands once, on release: a player asked to seek every
                // frame of a drag spends the drag buffering.
                dragSeek = true;
            }
            pressConsumed = dragRow >= 0 || dragSeek;
        }

        onReleased: (event) => {
            if (dragSeek)
                Media.seekFraction(
                    mediaIsland.seekFractionAt(bar.mediaLocalX(event.x)));
            dragRow = -1;
            dragSeek = false;
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
            var onLauncher = bar.overLauncher(event.x, event.y);
            var onSettings = !onLauncher && bar.overSettings(event.x, event.y);
            if (!onLauncher && !onSettings && !bar.overClock(event.x, event.y)) {
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
            if (onLauncher)
                launcherIsland.scrollBy(-steps);
            else if (onSettings)
                settingsIsland.scrollBy(-steps);
            else
                clockIsland.page(-steps);
        }

        onClicked: (event) => {
            // A drag already answered this press.
            if (pressConsumed) {
                pressConsumed = false;
                return;
            }
            var mediaIcon = bar.mediaIconAt(event.x, event.y);
            if (mediaIcon >= 0) {
                mediaIsland.activateIcon(mediaIcon);
                return;
            }
            var mediaDevice = bar.mediaDeviceAt(event.x, event.y);
            if (mediaDevice >= 0) {
                mediaIsland.activateDevice(mediaDevice);
                return;
            }
            var transport = bar.mediaControlAt(event.x, event.y);
            if (transport >= 0) {
                mediaIsland.activateControl(transport);
                return;
            }
            var powerTile = bar.powerTileAt(event.x, event.y);
            if (powerTile >= 0) {
                powerIsland.activate(powerTile);
                return;
            }
            // The arrival answers first: it is the thing that just interrupted.
            if (bar.overToast(event.x, event.y)) {
                if (event.button === Qt.RightButton)
                    Notifications.dismissCurrent();
                else if (!Notifications.invokeDefault())
                    Notifications.dismissToast();
                return;
            }
            var tray = bar.trayAt(event.x, event.y);
            if (tray >= 0) {
                bar.activateTray(tray, event.button);
                return;
            }
            // The paging marks and the dismiss mark sit over the list, so
            // they are asked about before the row underneath them.
            var scrollMark = bar.settingsScrollAt(event.x, event.y);
            if (scrollMark >= 0) {
                settingsIsland.scrollBy(scrollMark === 0 ? -1 : 1);
                return;
            }
            var closeMark = bar.settingsCloseAt(event.x, event.y);
            if (closeMark >= 0) {
                settingsIsland.dismissRow(closeMark);
                return;
            }
            // Rows in the settings panel take both buttons: one acts, the
            // other forgets what it is looking at.
            var settingRow = bar.settingsRowAt(event.x, event.y);
            if (settingRow >= 0) {
                settingsIsland.activateRow(settingRow,
                                           event.button === Qt.RightButton);
                return;
            }
            if (event.button !== Qt.LeftButton)
                return;
            bar.closeTrayMenu();
            if (bar.launcherModeAt(event.x, event.y) >= 0) {
                launcherIsland.toggleMode();
                return;
            }
            var row = bar.launcherRowAt(event.x, event.y);
            if (row >= 0) {
                launcherIsland.activate(row, event.button === Qt.RightButton);
                return;
            }
            var control = bar.clockControlAt(event.x, event.y);
            if (control >= 0) {
                clockIsland.control(control);
                return;
            }
            var tab = bar.settingsTabAt(event.x, event.y);
            if (tab >= 0) {
                settingsIsland.page = tab;
                return;
            }
            var setting = bar.settingsControlAt(event.x, event.y);
            if (setting >= 0) {
                settingsIsland.activate(setting);
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
        interval: bar.launcherOpen || bar.wantsKeyboard
            ? Theme.launcherGraceMs : Theme.closeGraceMs
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
            },
            LiquidShape {
                x: bar.clockX
                y: bar.clockY
                width: bar.clockW
                height: bar.clockH
                radius: bar.clockR
            },
            LiquidShape {
                x: bar.settingsX
                y: bar.settingsY
                width: bar.settingsW
                height: bar.settingsH
                radius: bar.settingsR
            },
            LiquidShape {
                x: bar.powerX
                y: bar.powerY
                width: bar.powerW
                height: bar.powerH
                radius: bar.powerR
            },
            LiquidShape {
                x: bar.mediaX
                y: bar.mediaY
                width: bar.mediaW
                height: bar.mediaH
                radius: bar.mediaR
            },
            LiquidShape {
                x: bar.toastX
                y: bar.toastY
                width: bar.toastW
                height: bar.toastH
                radius: bar.toastR
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
            y: bar.readoutCenterY - height / 2
        }

        // Resting indicator: minutes elapsed in the hour, plotted. Updates once
        // a minute, which is the entire repaint budget of the collapsed pill.
        Item {
            id: minuteTrack
            readonly property real span: 56
            width: span
            x: (content.width - width) / 2
            y: bar.readoutCenterY + 11
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

        batteryIconReveal: Theme.pen(Theme.dockPhase(bar.dockDraw, Theme.drawBatteryIcon))
        batteryValueReveal: Theme.dockPhase(bar.dockDraw, Theme.drawBatteryValue)
        batteryStatusReveal: Theme.dockPhase(bar.dockDraw, Theme.drawBatteryStatus)
        batteryGaugeDraw: Theme.pen(Theme.dockPhase(bar.dockDraw, Theme.drawBatteryGauge))
        trayFrameDraw: Theme.pen(Theme.dockPhase(bar.dockDraw, Theme.drawTrayFrame))
        trayIconsReveal: Theme.pen(Theme.dockPhase(bar.dockDraw, Theme.drawTrayIcons))
    }

    LauncherIsland {
        id: launcherIsland
        x: bar.launcherX
        y: bar.launcherY
        width: bar.launcherW
        height: bar.launcherH
        // Visible from the moment the panel is asked for, not from the moment
        // its box starts growing. An item that is not visible cannot hold
        // active focus, and the box does not start growing until the menu is
        // most of the way open -- 186ms measured -- so a keybinding that opens
        // the launcher and a reader who starts typing immediately were racing,
        // and the first character went to whatever had the keyboard before.
        // It is still 0x0 and clipped until then, so nothing is drawn early.
        visible: bar.launcherVisible || bar.launcherOpen

        draw: bar.launcherDraw
        listDraw: bar.launcherList
        hovered: hit.hoverRow
        hoveredMode: hit.hoverLauncherMode

        // Pointing the field at another corpus redraws the list and nothing
        // else. No delay: the rail it hangs from is already there.
        onModeChanged: bar.drawLauncherList(0)
        // Holding the keyboard is a state of the panel, not of the window: the
        // layer asks for on-demand focus from the same flag.
        active: bar.launcherOpen

        onLaunched: bar.mode = 0
        // Escape gives the socket back to the dock while the pointer is on the
        // bar -- there is something to go back to. Opened from a keybinding the
        // pointer is elsewhere, nothing would ever dismiss the menu, so Escape
        // closes the bar outright.
        onDismissed: {
            if (hit.containsMouse)
                bar.setSection(-1);
            else
                bar.mode = 0;
        }
    }

    ClockIsland {
        id: clockIsland
        x: bar.clockX
        y: bar.clockY
        width: bar.clockW
        height: bar.clockH
        visible: bar.clockVisible

        draw: bar.clockDraw
        hoveredControl: hit.hoverControl
        // Minutes drive the calendar, seconds drive the readout. The second
        // clock only runs while the menu is open, so a panel that is not on
        // screen costs nothing.
        day: minuteClock.date
        live: secondClock.date
    }

    SettingsIsland {
        id: settingsIsland
        x: bar.settingsX
        y: bar.settingsY
        width: bar.settingsW
        height: bar.settingsH
        visible: bar.settingsVisible

        draw: bar.settingsDraw
        paneDraw: bar.settingsPane
        hoveredTab: hit.hoverTab
        hoveredControl: hit.hoverSetting
        hoveredRow: hit.hoverSettingRow
        hoveredClose: hit.hoverSettingClose
        hoveredScroll: hit.hoverSettingScroll
        active: bar.settingsOpen

        // Choosing a section redraws the pane and nothing else. No delay: the
        // rule it hangs from is already there.
        onPageChanged: bar.drawSettingsPane(0)
    }

    ToastIsland {
        id: toastIsland
        x: bar.toastX
        y: bar.toastY
        width: bar.toastW
        height: bar.toastH
        visible: bar.toastVisible

        draw: bar.toastDraw
        life: bar.toastLife
        hovered: hit.hoverToast
        notification: bar.toastItem
    }

    MediaIsland {
        id: mediaIsland
        x: bar.mediaX
        y: bar.mediaY
        width: bar.mediaW
        height: bar.mediaH
        visible: bar.mediaVisible

        draw: bar.mediaDraw
        hoveredIcon: hit.hoverMediaIcon
        hoveredDevice: hit.hoverMediaDevice
        hoveredControl: hit.hoverMediaControl
        hoveredSeek: hit.hoverMediaSeek
    }

    PowerIsland {
        id: powerIsland
        x: bar.powerX
        y: bar.powerY
        width: bar.powerW
        height: bar.powerH
        visible: bar.powerVisible

        draw: bar.powerDraw
        hovered: hit.hoverPowerTile
    }
}
