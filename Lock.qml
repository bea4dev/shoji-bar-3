pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "components"
import "theme.js" as Theme

// The session lock.
//
// Its own surface, its own keyboard, and its own clock: while it is up the
// compositor hands it everything and the bar is not on screen at all. That is
// the protocol's whole point, and it is why none of this goes through the
// bar's machinery.
//
// The secret never leaves this object. The surfaces are given how much has
// been typed, never what: a lock screen that hands its own password around to
// per-screen delegates has no business being one.
Singleton {
    id: root

    // Owned here rather than read back from the lock surface. Reading it back
    // does not report the change: a timer bound to it never started during
    // testing, and the state the face and the release depend on cannot be one
    // that might be stale.
    property bool locked: false
    readonly property bool checking: pam.active
    readonly property int typed: secret.length

    property string status: ""
    property bool failed: false
    // 0..1 pen driver for the face, as every other surface here has.
    property real draw: 0
    // 0..1 the cover itself: the dimming over the wallpaper and the island's
    // own ground. Separate from the pen, because on the way out the strokes
    // and the cover leave at different rates -- the lines retract, then the
    // desktop comes back through.
    property real veil: 0

    readonly property string user: Quickshell.env("USER") || ""
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(clock.date, "yyyy.MM.dd")
        + "  " + ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][clock.date.getDay()]
    readonly property real minuteProgress: clock.date.getSeconds() / 60
    readonly property string seconds: ":" + Qt.formatDateTime(clock.date, "ss")

    property string secret: ""

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        // The owned flag, not the surface's: reading the surface's back does
        // not report the change, so this clock was never started and the
        // second hand sat where it was built.
        enabled: root.locked
    }

    ParallelAnimation {
        id: cover
        NumberAnimation {
            target: root; property: "veil"; to: 1
            duration: Theme.lockCoverMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
        NumberAnimation {
            target: root; property: "draw"; to: 1
            duration: Theme.durLockDraw
            easing.type: Easing.Linear
        }
    }

    // Letting go. The pen retracts first and the cover follows it off, so the
    // desktop is uncovered rather than switched back to. The surface is only
    // given up once there is nothing left to see, which is what makes this an
    // animation rather than a flicker.
    SequentialAnimation {
        id: release

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "draw"; to: 0
                duration: Theme.lockReleaseMs
                easing.type: Easing.Linear
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.lockReleaseHoldMs }
                NumberAnimation {
                    target: root; property: "veil"; to: 0
                    duration: Theme.lockReleaseMs
                    // Sustained rather than front-loaded: `easeOut` had the
                    // desktop back at a quarter of the way through, before
                    // the strokes had finished retracting, which reads as the
                    // cover being yanked rather than drawn away.
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeSustained
                }
            }
        }

        ScriptAction {
            script: {
                session.locked = false;
                root.locked = false;
            }
        }
    }

    function engage() {
        if (locked)
            return;
        release.stop();
        secret = "";
        status = "";
        failed = false;
        draw = 0;
        veil = 0;
        locked = true;
        session.locked = true;
        cover.restart();
    }

    function type(text) {
        if (pam.active)
            return;
        failed = false;
        status = "";
        secret += text;
    }

    function erase() {
        if (!pam.active)
            secret = secret.substring(0, secret.length - 1);
    }

    function clear() {
        if (!pam.active)
            secret = "";
    }

    function submit() {
        if (pam.active || secret === "")
            return;
        failed = false;
        status = "CHECKING";
        pam.start();
    }

    WlSessionLock {
        id: session

        surface: WlSessionLockSurface {
            color: "transparent"

            LockFace {
                anchors.fill: parent
            }
        }
    }

    PamContext {
        id: pam

        // /etc/pam.d/login, which is what every lock on this machine ends up
        // including anyway -- hyprlock's config and astal-auth's are both one
        // line of `auth include login`. Using it directly means the lock does
        // not depend on another package's file being installed.
        config: "login"
        user: root.user

        onPamMessage: {
            if (responseRequired)
                respond(root.secret);
            else if (message !== "")
                root.status = message.toUpperCase();
        }

        onCompleted: (result) => {
            // Whatever happened, the secret is done with.
            root.secret = "";
            if (result === PamResult.Success) {
                root.status = "";
                cover.stop();
                release.restart();
                return;
            }
            root.failed = true;
            root.status = result === PamResult.MaxTries ? "TOO MANY ATTEMPTS"
                : result === PamResult.Error ? "AUTHENTICATION ERROR"
                : "WRONG PASSWORD";
        }

        onError: (code) => {
            root.secret = "";
            root.failed = true;
            root.status = "PAM ERROR";
        }
    }

    // Locking is offered; unlocking is not. A shell that could be told to
    // unlock over a socket would be a lock in name only.
    IpcHandler {
        target: "session"

        function lock(): void { root.engage(); }
    }
}
