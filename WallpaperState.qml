pragma Singleton

import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "theme.js" as Theme

// The wallpaper: which pictures there are to choose from, and which one is
// chosen.
//
// A singleton, because every screen shows the same picture and the settings
// panel is built per screen: one directory scan and one stored choice, not one
// of each per monitor.
//
// The choice is kept in Quickshell's state directory rather than next to the
// shell's source. It is something the shell picked up from the user, not
// something the user wrote, and this repository should not go dirty because
// somebody changed their wallpaper.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""

    // Where pictures are looked for. The stored source wins; otherwise the
    // first of the documented defaults that actually has something in it.
    property string folderPath: home + "/" + Theme.wallpaperDir
    property bool triedAlternate: false

    readonly property string source: adapter.source !== "" ? adapter.source : folderPath
    readonly property string current: adapter.wallpaper
    readonly property int count: files.length

    // { url, name } per picture, rebuilt whenever the directory changes.
    property var files: []

    FolderListModel {
        id: folder

        folder: "file://" + root.source
        nameFilters: Theme.wallpaperTypes
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        caseSensitive: false

        onCountChanged: root.rescan()
        onStatusChanged: root.rescan()
    }

    function rescan() {
        var out = [];
        for (var i = 0; i < folder.count; i++) {
            out.push({
                url: String(folder.get(i, "fileUrl")),
                name: String(folder.get(i, "fileName"))
            });
        }
        files = out;

        // The default is the first of the documented directories that has
        // anything in it. An explicit choice is never second-guessed.
        if (out.length === 0 && adapter.source === "" && !triedAlternate
            && folder.status === FolderListModel.Ready) {
            triedAlternate = true;
            folderPath = home + "/" + Theme.wallpaperDirAlt;
        }
    }

    function choose(url) {
        adapter.wallpaper = String(url);
        view.writeAdapter();
    }

    function isCurrent(url) {
        return String(url) === adapter.wallpaper;
    }

    FileView {
        id: view

        path: Quickshell.statePath("wallpaper.json")
        watchChanges: true
        // There is no file until something is chosen, which is not an error.
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            // The picture on screen.
            property string wallpaper: ""
            // Where to look for pictures. Empty means the default above; set
            // it here to point the picker somewhere else without touching any
            // code.
            property string source: ""
        }
    }
}
