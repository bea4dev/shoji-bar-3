pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

// The audio node the bar is driving, and the list of ones it could drive.
//
// Pipewire hands out a volume per node, not one volume for the machine, so the
// row picks a node: the default sink to begin with, and any other output or
// playing stream after that. Per-application volume falls out of the same
// list -- a stream is a node like any other.
//
// The default sink is read-only here; this does not repoint the system's
// output, it points the row at something else to look at.
Singleton {
    id: root

    // What the row was pointed at. Null means "whatever the default sink is",
    // which is also where it goes back to if the pinned node disappears.
    property var pinned: null

    readonly property var node: pinned && pinned.ready
        ? pinned : Pipewire.defaultAudioSink

    readonly property var choices: {
        var out = [];
        var sink = Pipewire.defaultAudioSink;
        if (sink)
            out.push(sink);
        var nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < nodes.length; i++) {
            var candidate = nodes[i];
            if (!candidate.audio || candidate === sink)
                continue;
            if (isOutput(candidate))
                out.push(candidate);
        }
        return out;
    }

    readonly property real volume: node && node.audio ? node.audio.volume : 0
    readonly property bool muted: node && node.audio ? node.audio.muted : false
    readonly property bool usable: node !== null && node !== undefined
    readonly property string label: nodeLabel(node)

    function isOutput(candidate) {
        var type = candidate.type;
        return (type & PwNodeType.AudioSink) === PwNodeType.AudioSink
            || (type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream;
    }

    // A stream is worth naming by the application behind it; a device by
    // whatever the card calls itself.
    function nodeLabel(candidate) {
        if (!candidate)
            return "NO OUTPUT";
        var properties = candidate.properties || {};
        if (candidate.isStream && properties["application.name"])
            return String(properties["application.name"]).toUpperCase();
        return String(candidate.nickname || candidate.description
                      || candidate.name || "OUTPUT").toUpperCase();
    }

    function setVolume(value) {
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function cycle() {
        var list = choices;
        if (list.length === 0)
            return;
        var at = list.indexOf(node);
        var next = list[(at + 1) % list.length];
        // Back to following the default rather than pinning it in place.
        pinned = next === Pipewire.defaultAudioSink ? null : next;
    }

    // Without this the nodes report nothing: Pipewire data is only bound for
    // objects something is holding.
    PwObjectTracker {
        objects: root.choices
    }
}
