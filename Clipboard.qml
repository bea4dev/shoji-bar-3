pragma Singleton

import Quickshell
import Quickshell.Io

// The clipboard's history, read from cliphist.
//
// cliphist is already running in this session -- ShojiWM starts a wl-paste
// watcher per type -- so the history exists whether the bar is up or not, and
// the bar only has to read it. Nothing here keeps a copy of the clipboard
// itself; the list is previews and ids, and the content is fetched only when
// something is actually chosen.
//
// A singleton, because the bar is built per screen and one reader is enough.
Singleton {
    id: root

    // { id, line, primary, note, binary, image, ext }, newest first, as
    // cliphist lists it.
    property var entries: []
    readonly property int count: entries.length

    // ----- thumbnails -----------------------------------------------------
    //
    // cliphist stores an image as bytes behind an id, and Qt loads pictures
    // from files, so a copied image has to be written out before it can be
    // shown. They are written lazily -- only for rows that are actually on
    // screen -- and kept in the cache directory, where growing is what a
    // cache is for. Decoding all 138 of them up front to show six would be
    // work nobody asked for.

    readonly property string cacheDir: Quickshell.cachePath("clipboard")
    // id -> file path. An id present with an empty path was tried and failed,
    // which stops it being retried on every scroll.
    property var thumbs: ({})

    // Types Qt will actually decode. Anything else stays a line of text.
    readonly property var imageTypes: ["png", "jpeg", "jpg", "gif", "webp", "bmp"]

    property var queue: []
    property string activeId: ""
    property string activeFile: ""

    // Asks for one entry's thumbnail. Called by a row as it comes into view,
    // and cheap to call again: an id already known or already queued is
    // dropped here.
    function want(entry) {
        if (!entry || !entry.image || thumbs[entry.id] !== undefined
            || activeId === entry.id)
            return;
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].id === entry.id)
                return;
        }
        queue = queue.concat([{ id: entry.id, ext: entry.ext }]);
        pump();
    }

    function pump() {
        if (activeId !== "" || queue.length === 0)
            return;
        var job = queue[0];
        queue = queue.slice(1);
        activeId = job.id;
        activeFile = cacheDir + "/" + job.id + "." + job.ext;
        // Written once and reused: `-s` keeps a second look at the same entry
        // from decoding it again.
        decoder.command = ["sh", "-c",
            "mkdir -p \"$2\"; [ -s \"$1\" ] || cliphist decode \"$0\" > \"$1\"",
            job.id, activeFile, cacheDir];
        decoder.running = true;
    }

    Process {
        id: decoder

        onExited: (code, status) => {
            root.remember(root.activeId, code === 0 ? "file://" + root.activeFile : "");
            root.activeId = "";
            root.activeFile = "";
            root.pump();
        }
    }

    // A new object each time: QML does not notice a map that was mutated in
    // place, and the rows are bound to this.
    function remember(id, path) {
        var next = {};
        for (var key in thumbs)
            next[key] = thumbs[key];
        next[id] = path;
        thumbs = next;
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    // Read again. The history changes behind the bar's back, so this is called
    // whenever the list is about to be looked at rather than kept live.
    function refresh() {
        lister.running = false;
        lister.running = true;
    }

    function parse(text) {
        var out = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line === "")
                continue;
            var tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            var preview = line.substring(tab + 1);
            var shape = describe(preview);
            out.push({
                id: line.substring(0, tab),
                line: line,
                primary: shape.primary,
                note: shape.note,
                binary: shape.binary,
                image: shape.image,
                ext: shape.ext
            });
        }
        entries = out;
    }

    // cliphist previews an image as "[[ binary data 30 KiB png 1242x1171 ]]",
    // which is four readings crammed into one string. Split it back out: what
    // it is goes where a name goes, how big it is goes where a note goes.
    function describe(preview) {
        var sized = /^\[\[ binary data (.+?) (\w+) ([0-9]+x[0-9]+) \]\]$/.exec(preview);
        if (sized) {
            var kind = sized[2].toLowerCase();
            return {
                primary: sized[2].toUpperCase() + "  " + sized[3],
                note: sized[1].toUpperCase(),
                binary: true,
                image: imageTypes.indexOf(kind) >= 0,
                ext: kind
            };
        }
        var plain = /^\[\[ binary data (.+?) \]\]$/.exec(preview);
        if (plain) {
            return { primary: "BINARY", note: plain[1].toUpperCase(),
                     binary: true, image: false, ext: "" };
        }
        // Tabs and newlines survive in a preview and would draw as gaps.
        return { primary: preview.replace(/\s+/g, " ").trim(), note: "",
                 binary: false, image: false, ext: "" };
    }

    Process { id: picker }

    // Puts it back on the clipboard. Decoding by id rather than piping the
    // preview back: a preview is truncated, and a truncated paste is worse
    // than no paste.
    //
    // Detached rather than managed. `wl-copy` forks a server to hold the
    // selection and its parent exits at once, so there is nothing useful left
    // for the shell to supervise -- and nothing of the shell's own lifetime
    // for somebody's clipboard to hang from.
    function copy(entry) {
        if (!entry)
            return;
        picker.command = ["sh", "-c", "cliphist decode \"$0\" | wl-copy", entry.id];
        picker.startDetached();
    }

    Process {
        id: deleter
        onExited: root.refresh()
    }

    // cliphist deletes by the line it listed, which is passed as an argument
    // rather than interpolated: a clipboard entry is arbitrary text and has no
    // business being parsed by a shell.
    function remove(entry) {
        if (!entry)
            return;
        deleter.running = false;
        deleter.command = ["sh", "-c", "printf '%s\\n' \"$0\" | cliphist delete", entry.line];
        deleter.running = true;
    }
}
