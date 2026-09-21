import QtQuick
import ".."
import "../theme.js" as Theme

// What a locked screen shows: the wallpaper it was locked over, dimmed, and
// one island in the middle drawn the way every other island here is drawn.
//
// The secret is not in this file. It is given the count and draws that many
// points on a rule -- the same plotted-point vocabulary the power selector and
// the clock panel use, standing in for a row of asterisks.
Item {
    id: face

    readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
    readonly property int shown: Math.min(Lock.typed, Theme.lockDotsMax)

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape)
            Lock.clear();
        else if (event.key === Qt.Key_Backspace)
            Lock.erase();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            Lock.submit();
        else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20)
            Lock.type(event.text);
        else
            return;
        event.accepted = true;
    }

    // The desktop it was locked over, so locking reads as a cover being drawn
    // rather than as the machine going somewhere else.
    WallpaperSurface {
        anchors.fill: parent
        source: WallpaperState.current
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.lockScrim
        opacity: Theme.clamp01(Lock.veil)
    }

    Rectangle {
        id: island

        anchors.centerIn: parent
        width: Theme.lockWidth
        height: Theme.lockHeight
        radius: Theme.lockRadius
        color: Theme.lockTint
        antialiasing: true
        border.width: Theme.strokeWeight
        border.color: Theme.lineFaint
        opacity: Theme.clamp01(Lock.veil)

        readonly property real inner: width - Theme.lockPadX * 2

        // The same readout the bar rests as, at the size a locked screen can
        // afford to give it.
        TypedText {
            x: (island.width - width) / 2 + letterSpacing / 2
            y: Theme.lockClockY - height / 2
            content: Lock.time
            capacity: 5
            reveal: Theme.lockPhase(Lock.draw, Theme.drawLockClock)
            ink: Theme.textPrimary
            pixelSize: Theme.lockClockSize
            letterSpacing: 3
            opacity: Theme.opStrong
        }

        TypedText {
            x: (island.width - width) / 2
            y: Theme.lockDateY - height / 2
            content: Lock.date
            capacity: Theme.dateChars
            reveal: Theme.lockPhase(Lock.draw, Theme.drawLockDate)
            ink: Theme.textMuted
            pixelSize: 10
            letterSpacing: 4
            opacity: Theme.opNormal
        }

        // The minute, still running: a locked machine is not a stopped one.
        // The seconds are written at the end of it, because a marker that
        // moves six pixels a second is easy to take for a stopped one.
        TypedText {
            x: island.width - Theme.lockPadX - width
            y: Theme.lockAxisY - height - 6
            content: Lock.seconds
            capacity: 3
            reveal: Theme.lockPhase(Lock.draw, Theme.drawLockAxis)
            ink: Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
        }

        AxisRule {
            x: Theme.lockPadX
            y: Theme.lockAxisY
            width: island.inner
            draw: Theme.pen(Theme.lockPhase(Lock.draw, Theme.drawLockAxis))
            reveal: Theme.remap(
                Theme.lockPhase(Lock.draw, Theme.drawLockAxis), 0.45, 1)
            progress: Lock.minuteProgress
        }

        // ----- the secret ---------------------------------------------------

        Chevron {
            span: 9
            drop: 4
            rotation: -90
            transformOrigin: Item.Center
            x: Theme.lockPadX + 2 - width / 2
            y: Theme.lockFieldY - height / 2
            ink: Lock.failed ? Theme.lineStrong : Theme.lineNormal
            opacity: Lock.checking ? Theme.opFaint : Theme.opNormal
            progress: Theme.pen(Theme.lockPhase(Lock.draw, Theme.drawLockField))

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Repeater {
            model: face.shown
            delegate: Rectangle {
                required property int index

                x: Theme.lockPadX + 20 + index * (Theme.lockDotSize + Theme.lockDotGap)
                y: Theme.lockFieldY - Theme.lockDotSize / 2
                width: Theme.lockDotSize
                height: Theme.lockDotSize
                radius: Theme.lockDotSize / 2
                color: Theme.lineStrong
                antialiasing: true
                opacity: Lock.checking ? Theme.opFaint : Theme.opStrong

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }

        // Where the points are plotted. Brightens when an attempt was refused,
        // which is the whole of the failure state: no colour this bar does not
        // otherwise use, and nothing that moves.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.lockPhase(Lock.draw, Theme.drawLockRule))

            x: Theme.lockPadX
            y: Theme.snap(Theme.lockRuleY, Screen.devicePixelRatio)
            width: island.inner * drawn
            height: face.hairline
            color: Lock.failed ? Theme.lineStrong : Theme.lineFaint
            opacity: Lock.failed ? Theme.opStrong : Theme.opGrid + 0.1
            visible: drawn > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        TypedText {
            x: Theme.lockPadX
            y: Theme.lockStatusY - height / 2
            content: Lock.user
            capacity: Theme.lockUserChars
            reveal: Theme.lockPhase(Lock.draw, Theme.drawLockUser)
            ink: Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
        }

        Text {
            x: island.width - Theme.lockPadX - width
            y: Theme.lockStatusY - height / 2
            text: Lock.status
            color: Lock.failed ? Theme.textPrimary : Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 9
            font.letterSpacing: 2
            opacity: Lock.status === "" ? 0
                : Lock.failed ? Theme.opStrong : Theme.opNormal
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
