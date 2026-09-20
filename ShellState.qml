pragma Singleton

import Quickshell

// State the shell owns rather than reads from a service, kept in one place so
// every screen's bar agrees about it. The bar is built per screen through
// Variants, and a flag stored in one of those would be a different flag on
// each monitor.
Singleton {
    // Do not disturb. Nothing in shoji-bar-3 displays notifications yet -- the
    // session's notification daemon is still shoji-bar-2 -- so for now this is
    // the shell's own intent, which the settings panel shows and which the
    // notification surface will read once it lands here.
    property bool doNotDisturb: false
}
