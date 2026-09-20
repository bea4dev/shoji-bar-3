pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "theme.js" as Theme

// The session's notification daemon, and the one notification currently being
// shown.
//
// A singleton, because the bar is built per screen through Variants and there
// can only be one owner of org.freedesktop.Notifications -- one server here
// and every screen showing the same arrival.
//
// Nothing here runs a clock. The toast's life is animated by the bar, which
// owns every animation in the shell, and the end of that animation is what
// takes the toast away; that way hovering can pause it without two timers
// having to agree about how much time is left.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications
        ? server.trackedNotifications.values : []
    readonly property int count: list.length

    // The arrival currently on screen, or null.
    property var toast: null

    // How long this toast should be held, in milliseconds. Zero means it stays
    // until it is answered: a sender that marks something critical is saying
    // the reader must see it, and a timer would disagree.
    readonly property int toastMs: {
        if (!toast)
            return 0;
        if (toast.urgency === NotificationUrgency.Critical)
            return 0;
        if (toast.expireTimeout > 0)
            return toast.expireTimeout;
        return Theme.toastHoldMs;
    }

    NotificationServer {
        id: server

        // A config reload must not drop what is on the wire.
        keepOnReload: true
        // Only claims we can actually honour. Saying otherwise makes senders
        // build a notification the shell then silently throws half of away.
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: true

        onNotification: (notification) => {
            // Untracked notifications are destroyed the moment this returns.
            notification.tracked = true;

            // Do not disturb holds the toast, not the notification: it is
            // still received, still kept, and still in the list the settings
            // panel shows. The switch is about interruption, not about losing
            // what arrived while it was on.
            if (ShellState.doNotDisturb)
                return;

            root.toast = notification;
        }
    }

    // The sender can withdraw a notification while it is on screen, and the
    // object goes with it.
    Connections {
        target: root.toast
        ignoreUnknownSignals: true

        function onClosed(reason: int): void {
            root.toast = null;
        }
    }

    function dismissToast() {
        toast = null;
    }

    // Takes the notification away for good, rather than just off the screen.
    function dismissCurrent() {
        var current = toast;
        toast = null;
        if (current)
            current.dismiss();
    }

    // The action a sender means by "the notification itself was clicked".
    function invokeDefault() {
        var current = toast;
        if (!current) {
            return false;
        }
        var actions = current.actions || [];
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
                toast = null;
                actions[i].invoke();
                return true;
            }
        }
        return false;
    }

    function clearAll() {
        toast = null;
        var current = list.slice();
        for (var i = 0; i < current.length; i++)
            current[i].dismiss();
    }
}
