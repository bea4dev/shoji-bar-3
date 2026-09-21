pragma Singleton

import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

// The backlight, read from sysfs and written through brightnessctl.
//
// Quickshell has no backlight service, and the sysfs files are root-owned, so
// the value is watched directly and the write goes through the tool that
// already knows how to ask logind for permission.
//
// A machine can have more than one panel -- this one has an integrated and a
// discrete GPU's -- so the row picks a device the same way the volume row
// picks a node.
Singleton {
    id: root

    property int index: 0
    property var devices: []

    readonly property string device:
        index >= 0 && index < devices.length ? devices[index] : ""
    readonly property string label: device === "" ? "NO BACKLIGHT"
        : device.toUpperCase()
    readonly property bool usable: device !== ""

    readonly property int maximum: parseInt(maxView.text()) || 0
    readonly property int raw: parseInt(rawView.text()) || 0

    // What the slider was dragged to, until the file catches up. Without it
    // the handle springs back to the last read value between writes.
    property real pending: -1
    readonly property real level: pending >= 0 ? pending
        : maximum > 0 ? Math.max(0, Math.min(1, raw / maximum)) : 0

    FolderListModel {
        id: dir

        folder: "file:///sys/class/backlight"
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name

        onCountChanged: root.rescan()
        onStatusChanged: root.rescan()
    }

    function rescan() {
        var out = [];
        for (var i = 0; i < dir.count; i++)
            out.push(String(dir.get(i, "fileName")));
        devices = out;
    }

    FileView {
        id: rawView
        path: root.device === "" ? ""
            : "/sys/class/backlight/" + root.device + "/brightness"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    FileView {
        id: maxView
        path: root.device === "" ? ""
            : "/sys/class/backlight/" + root.device + "/max_brightness"
        printErrors: false
    }

    Process { id: setter }

    // Dragging a slider would otherwise spawn a process per frame.
    Timer {
        id: flush
        interval: 60
        onTriggered: root.apply()
    }

    // Long enough for the write to land and the watch to report it.
    Timer {
        id: settle
        interval: 350
        onTriggered: root.pending = -1
    }

    function setLevel(value) {
        pending = Math.max(0, Math.min(1, value));
        flush.restart();
    }

    function apply() {
        if (device === "" || pending < 0)
            return;
        setter.running = false;
        // Never all the way off: a panel at zero looks like a broken shell.
        setter.command = ["brightnessctl", "-q", "-d", device, "set",
                          Math.max(1, Math.round(pending * 100)) + "%"];
        setter.running = true;
        settle.restart();
    }

    function cycle() {
        if (devices.length === 0)
            return;
        index = (index + 1) % devices.length;
        pending = -1;
    }
}
