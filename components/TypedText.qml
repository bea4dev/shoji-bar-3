import QtQuick
import "../theme.js" as Theme

// Type cannot be drawn with a pen, so it is written instead: one character at a
// time, with the character currently being written fading in under the nib.
//
// Layout is measured from the complete string and never from the visible
// prefix, so a centred readout fills in place instead of sliding as it grows.
// The font is monospaced, which makes the advance per character exact.
Item {
    id: typed

    property string content: ""
    property real reveal: 1
    property color ink: Theme.textMuted
    property real pixelSize: 10
    property real letterSpacing: 4
    property int weight: Font.Light

    // Characters the caller's window was sized for. A string shorter than this
    // is written at the same rate as the longest one and then simply waits,
    // instead of being stretched to fill the window. Never below the string's
    // own length, so a caption longer than the budget still completes.
    property int capacity: 0

    readonly property int span: Math.max(capacity, content.length)
    readonly property real written: Theme.clamp01(reveal) * span
    readonly property int complete: Math.min(content.length, Math.floor(written))
    readonly property real partial: Theme.clamp01(written - complete)
    // Qt appends the tracking after every glyph, the last one included, so the
    // advance is uniform and the trailing gap is not part of the visible run.
    readonly property real advance: content.length > 0
        ? metrics.width / content.length : 0

    implicitWidth: Math.max(0, metrics.width - letterSpacing)
    implicitHeight: metrics.height

    Text {
        id: metrics
        text: typed.content
        font.family: Theme.fontMono
        font.weight: typed.weight
        font.pixelSize: typed.pixelSize
        font.letterSpacing: typed.letterSpacing
        visible: false
    }

    Text {
        text: typed.content.substring(0, typed.complete)
        color: typed.ink
        font: metrics.font
    }

    Text {
        x: typed.complete * typed.advance
        text: typed.complete < typed.content.length
            ? typed.content.charAt(typed.complete) : ""
        color: typed.ink
        font: metrics.font
        opacity: typed.partial
        visible: opacity > 0.001
    }
}
