pragma Singleton

import Quickshell
import Quickshell.Io

// The bar's control surface for anything outside it: a compositor keybinding,
// a script, a hotkey daemon.
//
//   quickshell -p ~/.config/shoji-bar-3 ipc call launcher toggle
//   quickshell -p ~/.config/shoji-bar-3 ipc call launcher toggleOn eDP-1
//   quickshell -p ~/.config/shoji-bar-3 ipc call launcher clipboardOn eDP-1
//
// `quickshell -p ~/.config/shoji-bar-3 ipc show` lists these.
//
// A singleton rather than a handler inside the window: the bar is built per
// screen through Variants, and one IpcHandler per screen would be several
// handlers fighting over the same target name. This one exists once and hands
// the request on as a signal, which every bar hears and only the addressed one
// answers.
Singleton {
    id: root

    // `screen` is a connector name as the compositor spells it (eDP-1,
    // DP-3...). Empty means every screen, which is also what the no-suffix
    // functions send.
    signal requested(string action, string screen)

    IpcHandler {
        target: "launcher"

        function open(): void { root.requested("open", ""); }
        function close(): void { root.requested("close", ""); }
        function toggle(): void { root.requested("toggle", ""); }

        // The same panel with its field pointed at the clipboard's history
        // rather than at the applications.
        function clipboard(): void { root.requested("clipboard", ""); }

        // The screen-addressed forms. A keybinding should use these with the
        // monitor under the pointer, so the panel opens where the eye is.
        function openOn(screen: string): void { root.requested("open", screen); }
        function closeOn(screen: string): void { root.requested("close", screen); }
        function toggleOn(screen: string): void { root.requested("toggle", screen); }
        function clipboardOn(screen: string): void { root.requested("clipboard", screen); }
    }
}
