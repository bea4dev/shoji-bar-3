import QtQuick
import Quickshell.Widgets
import ".."
import "../theme.js" as Theme

// The dock's second half: how loud, how bright, and what is playing.
//
// Two instrument rows over a rule, and under it whatever is on the wire. The
// rows are the same axis the dock uses for charge and the menu uses for
// seconds, this time with a hand on them: the marker is the reading and also
// the handle.
//
// Like a section panel it takes the pen driver itself rather than one reveal
// per element, because its stages repeat per row. It starts no animation of
// its own.
Item {
    id: media

    property real draw: 1
    // Which control the pointer is on, hit-tested by the bar's single
    // MouseArea. -1 none.
    property int hoveredIcon: -1      // 0 volume (mute), 1 backlight
    property int hoveredDevice: -1    // 0 volume, 1 backlight
    property int hoveredControl: -1   // 0 previous, 1 play/pause, 2 next
    property bool hoveredSeek: false

    readonly property var levels: [Audio.volume, Backlight.level]
    readonly property var labels: [Audio.label, Backlight.label]
    readonly property var usable: [Audio.usable, Backlight.usable]

    // ----- input ------------------------------------------------------------
    //
    // Hit tests in the island's own coordinates. Nothing here accepts input.

    function iconAt(lx, ly) {
        if (Math.abs(lx - Theme.mediaIconX) > 12)
            return -1;
        return rowAt(ly);
    }

    function deviceAt(lx, ly) {
        if (lx < Theme.mediaWidth - Theme.mediaPadX - Theme.mediaDeviceWidth
            || lx > Theme.mediaWidth - Theme.mediaPadX)
            return -1;
        return rowAt(ly);
    }

    // The slider's own band, which is wider than the hairline it draws so it
    // can actually be grabbed.
    function sliderAt(lx, ly) {
        if (lx < Theme.mediaSliderX - 8
            || lx > Theme.mediaSliderX + Theme.mediaSliderWidth + 8)
            return -1;
        return rowAt(ly);
    }

    function rowAt(ly) {
        for (var i = 0; i < Theme.mediaRows; i++) {
            if (Math.abs(ly - Theme.mediaRowY(i)) <= Theme.mediaRowHeight / 2)
                return usable[i] ? i : -1;
        }
        return -1;
    }

    function seekAt(lx, ly) {
        return Media.usable && Media.length > 0
            && lx >= Theme.mediaTextX - 8 && lx <= seekRight + 8
            && Math.abs(ly - Theme.mediaSeekY) <= 12;
    }

    function controlAt(lx, ly) {
        if (!Media.usable || Math.abs(ly - Theme.mediaControlY) > 14)
            return -1;
        for (var i = 0; i < Theme.mediaControls; i++) {
            if (Math.abs(lx - Theme.mediaControlX(i)) <= Theme.mediaControlStep / 2)
                return i;
        }
        return -1;
    }

    // Where along a slider a pointer at `lx` is.
    function fractionAt(lx) {
        return Theme.clamp01((lx - Theme.mediaSliderX) / Theme.mediaSliderWidth);
    }

    function seekFractionAt(lx) {
        return Theme.clamp01((lx - Theme.mediaTextX) / (seekRight - Theme.mediaTextX));
    }

    function setRow(row, fraction) {
        if (row === 0)
            Audio.setVolume(fraction);
        else if (row === 1)
            Backlight.setLevel(fraction);
    }

    function activateIcon(row) {
        if (row === 0)
            Audio.toggleMute();
        else if (row === 1)
            Backlight.cycle();
    }

    function activateDevice(row) {
        if (row === 0)
            Audio.cycle();
        else if (row === 1)
            Backlight.cycle();
    }

    function activateControl(index) {
        if (index === 0)
            Media.previous();
        else if (index === 1)
            Media.toggle();
        else
            Media.next();
    }

    readonly property real seekRight:
        Theme.mediaControlX(0) - Theme.mediaControlStep / 2 - 10

    clip: true

    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.mediaWidth - Theme.mediaPadX * 2

        x: (media.width - Theme.mediaWidth) / 2
        y: (media.height - Theme.mediaHeight) / 2
        width: Theme.mediaWidth
        height: Theme.mediaHeight

        // ----- the instrument rows ------------------------------------------

        Repeater {
            model: Theme.mediaRows
            delegate: Item {
                id: row

                required property int index
                readonly property bool present: media.usable[row.index]
                readonly property real value: media.levels[row.index]
                readonly property bool mutedRow: row.index === 0 && Audio.muted
                readonly property bool iconLit: media.hoveredIcon === row.index
                readonly property bool deviceLit: media.hoveredDevice === row.index
                readonly property real drawn: Theme.pen(
                    Theme.mediaPhase(media.draw, Theme.drawMediaRow, row.index))

                x: 0
                y: Theme.mediaRowY(row.index) - Theme.mediaRowHeight / 2
                width: body.width
                height: Theme.mediaRowHeight
                visible: drawn > 0.001

                InkIcon {
                    x: Theme.mediaIconX - width / 2
                    y: (row.height - height) / 2
                    width: Theme.mediaIconSize
                    height: Theme.mediaIconSize
                    source: Qt.resolvedUrl("../assets/icons/"
                        + (row.index === 0
                           ? (row.mutedRow ? "volume-off" : "volume") : "bright")
                        + ".svg")
                    ink: row.iconLit ? Theme.lineStrong : Theme.lineNormal
                    reveal: Theme.pen(Theme.mediaPhase(
                        media.draw, Theme.drawMediaIcon, row.index))
                    strength: row.mutedRow ? 0.55 : row.iconLit ? 1 : 0.85
                }

                // The reading and the handle are the same mark.
                AxisRule {
                    x: Theme.mediaSliderX
                    y: row.height / 2
                    width: Theme.mediaSliderWidth
                    divisions: 10
                    draw: row.drawn
                    reveal: Theme.remap(row.drawn, 0.4, 1)
                    progress: row.present && !row.mutedRow ? row.value : 0
                    opacity: row.present ? 1 : Theme.opFaint
                }

                TypedText {
                    x: Theme.mediaSliderX + Theme.mediaSliderWidth + 10
                    y: (row.height - height) / 2
                    content: row.present
                        ? Math.round(row.value * 100) + "%" : "--"
                    capacity: 4
                    reveal: Theme.mediaPhase(
                        media.draw, Theme.drawMediaValue, row.index)
                    ink: row.mutedRow ? Theme.textMuted : Theme.textPrimary
                    pixelSize: 10
                    letterSpacing: 1
                    opacity: row.mutedRow ? Theme.opNormal : Theme.opStrong
                }

                // Which device the row is driving, and the way to the next one.
                Item {
                    x: body.width - Theme.mediaPadX - width
                    y: 0
                    width: Theme.mediaDeviceWidth
                    height: row.height
                    clip: true

                    TypedText {
                        x: parent.width - width
                        y: (row.height - height) / 2
                        content: media.labels[row.index]
                        capacity: Theme.mediaDeviceChars
                        reveal: Theme.mediaPhase(
                            media.draw, Theme.drawMediaDevice, row.index)
                        ink: row.deviceLit ? Theme.textPrimary : Theme.textMuted
                        pixelSize: 8
                        letterSpacing: 1.5
                        opacity: row.deviceLit ? Theme.opStrong : Theme.opGrid + 0.1

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.mediaPhase(media.draw, Theme.drawMediaRule))

            x: Theme.mediaPadX
            y: Theme.snap(Theme.mediaRuleY, Screen.devicePixelRatio)
            width: body.inner * drawn
            height: body.hairline
            color: Theme.lineFaint
            opacity: Theme.opGrid + 0.08
            visible: drawn > 0.001
        }

        // ----- what is playing ----------------------------------------------

        ClippingRectangle {
            x: Theme.mediaPadX
            y: Theme.mediaArtY
            width: Theme.mediaArtSize
            height: Theme.mediaArtSize
            radius: Theme.mediaArtRadius
            color: "transparent"
            antialiasing: true
            border.width: Theme.strokeWeight
            border.color: Theme.lineNormal
            opacity: Theme.clamp01(
                Theme.mediaPhase(media.draw, Theme.drawMediaArt))
                * (Media.usable ? 1 : Theme.opFaint)
            visible: opacity > 0.001

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Theme.mediaArtSize * 3
                sourceSize.height: Theme.mediaArtSize * 3
                smooth: true
                asynchronous: true
                visible: Media.art !== ""
            }

            // Nothing playing: the frame stays, empty, so the island does not
            // change shape when something starts.
            InkIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("../assets/icons/play.svg")
                ink: Theme.lineNormal
                strength: 0.35
                visible: Media.art === ""
            }
        }

        Item {
            x: Theme.mediaTextX
            y: Theme.mediaTitleY
            width: media.seekRight - Theme.mediaTextX
            height: 16
            clip: true

            TypedText {
                y: (parent.height - height) / 2
                content: Media.usable ? Media.title : "NOTHING PLAYING"
                capacity: Theme.mediaTitleChars
                reveal: Theme.mediaPhase(media.draw, Theme.drawMediaTitle)
                ink: Media.usable ? Theme.textPrimary : Theme.textMuted
                pixelSize: 11
                letterSpacing: 0.5
                opacity: Media.usable ? Theme.opStrong : Theme.opNormal
            }
        }

        Item {
            x: Theme.mediaTextX
            y: Theme.mediaArtistY
            width: media.seekRight - Theme.mediaTextX
            height: 14
            clip: true
            visible: Media.usable && Media.artist !== ""

            TypedText {
                y: (parent.height - height) / 2
                content: Media.artist
                capacity: Theme.mediaArtistChars
                reveal: Theme.mediaPhase(media.draw, Theme.drawMediaArtist)
                ink: Theme.textMuted
                pixelSize: 9
                letterSpacing: 1.5
                opacity: Theme.opNormal
            }
        }

        // Elapsed, on the same rule as everything else.
        AxisRule {
            readonly property real drawn: Theme.pen(
                Theme.mediaPhase(media.draw, Theme.drawMediaSeek))

            x: Theme.mediaTextX
            y: Theme.mediaSeekY
            width: media.seekRight - Theme.mediaTextX
            divisions: 8
            draw: drawn
            reveal: Theme.remap(drawn, 0.4, 1)
            progress: Media.length > 0
                ? Theme.clamp01(Media.position / Media.length) : 0
            opacity: media.hoveredSeek ? 1 : 0.85
            visible: Media.usable && drawn > 0.001
        }

        // Below the rule's ticks, not through them.
        Text {
            x: Theme.mediaTextX
            y: Theme.mediaSeekY + 10
            text: Media.clock(Media.position) + " / " + Media.clock(Media.length)
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 8
            font.letterSpacing: 1.5
            opacity: Theme.opGrid * Theme.clamp01(
                Theme.mediaPhase(media.draw, Theme.drawMediaSeek))
            visible: Media.usable && Media.length > 0 && opacity > 0.001
        }

        // Transport: three marks, the middle one saying what a press would do.
        Repeater {
            model: Theme.mediaControls
            delegate: InkIcon {
                required property int index
                readonly property bool lit: media.hoveredControl === index
                readonly property bool offered: index === 1
                    ? (Media.usable && Media.player.canTogglePlaying)
                    : index === 0 ? (Media.usable && Media.player.canGoPrevious)
                    : (Media.usable && Media.player.canGoNext)

                x: Theme.mediaControlX(index) - width / 2
                y: Theme.mediaControlY - height / 2
                width: Theme.mediaControlSize
                height: Theme.mediaControlSize
                source: Qt.resolvedUrl("../assets/icons/"
                    + (index === 0 ? "arrow-left"
                       : index === 1 ? (Media.playing ? "pause" : "play")
                       : "arrow-right") + ".svg")
                ink: lit ? Theme.lineStrong : Theme.lineNormal
                reveal: Theme.clamp01(
                    Theme.mediaPhase(media.draw, Theme.drawMediaControls))
                strength: !offered ? 0.25 : lit ? 1 : 0.8
                visible: Media.usable
            }
        }
    }
}
