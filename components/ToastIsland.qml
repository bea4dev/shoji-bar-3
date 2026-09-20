import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets
import Quickshell
import "../theme.js" as Theme

// An arriving notification, extruded out of the resting pill.
//
// Read in the order it is written: who it is from and when, then the rule that
// carries the time left, then what it says. The rule is both the pen's first
// stroke and the clock: it is drawn across on arrival and then drains back,
// so the thing that says "this is going away" is a line rather than a number.
Item {
    id: toast

    // 0..1 pen driver.
    property real draw: 1
    // 1..0 fraction of the hold remaining. Held at 1 for a critical arrival,
    // which is never taken away on a timer.
    property real life: 1
    property bool hovered: false

    property var notification: null

    readonly property bool critical: notification
        && notification.urgency === NotificationUrgency.Critical
    readonly property string appText:
        (notification && notification.appName ? notification.appName : "NOTICE").toUpperCase()
    readonly property string summaryText:
        notification && notification.summary ? notification.summary : ""
    readonly property string bodyText:
        notification && notification.body ? notification.body : ""

    // The picture the sender attached -- a Discord avatar, an album cover --
    // which is the thing that identifies the arrival long before its text
    // does. Its own application icon stands in when it sent none, so the
    // layout does not change shape depending on who is talking.
    readonly property string imageSource: {
        if (!notification)
            return "";
        if (notification.image)
            return notification.image;
        if (notification.appIcon)
            return Quickshell.iconPath(notification.appIcon, "");
        return "";
    }
    readonly property bool hasImage: imageSource !== ""
    readonly property real textX: Theme.toastPadX
        + (hasImage ? Theme.toastImageSize + Theme.toastTextGap : 0)

    clip: true

    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.toastWidth - Theme.toastPadX * 2

        x: (toast.width - Theme.toastWidth) / 2
        y: (toast.height - Theme.toastHeight) / 2
        width: Theme.toastWidth
        height: Theme.toastHeight

        // A critical arrival is marked on the rule the way the axis marks a
        // reading: a filled point, not a colour the rest of the bar never uses.
        Rectangle {
            x: Theme.toastPadX - 10
            y: Theme.toastHeaderY - 3
            width: 6
            height: 6
            radius: 3
            color: Theme.lineStrong
            antialiasing: true
            opacity: Theme.opStrong * Theme.clamp01(
                Theme.toastPhase(toast.draw, Theme.drawToastApp))
            visible: toast.critical && opacity > 0.001
        }

        TypedText {
            x: Theme.toastPadX
            y: Theme.toastHeaderY - height / 2
            content: toast.appText
            capacity: Theme.toastAppChars
            reveal: Theme.toastPhase(toast.draw, Theme.drawToastApp)
            ink: toast.critical ? Theme.textPrimary : Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
            visible: reveal > 0.001
        }

        TypedText {
            x: body.width - Theme.toastPadX - width
            y: Theme.toastHeaderY - height / 2
            content: Qt.formatDateTime(new Date(), "HH:mm")
            capacity: Theme.toastTimeChars
            reveal: Theme.toastPhase(toast.draw, Theme.drawToastTime)
            ink: Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opGrid + 0.15
            visible: reveal > 0.001
        }

        // Drawn across on arrival, then drained by the hold. One line doing
        // both jobs, so the toast never has to show a countdown as a figure.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.toastPhase(toast.draw, Theme.drawToastRule))

            x: Theme.toastPadX
            y: Theme.snap(Theme.toastRuleY, Screen.devicePixelRatio)
            width: body.inner * Math.min(drawn, Theme.clamp01(toast.life))
            height: body.hairline
            color: toast.critical ? Theme.lineStrong : Theme.lineFaint
            opacity: toast.hovered ? Theme.opNormal : Theme.opGrid + 0.12
            visible: width > 0.5

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        // The sender's own picture, framed the way everything else here is
        // framed. Clipped to the frame rather than shown square, because a
        // rectangle of somebody's photograph is the one thing in this bar
        // that would read as a different design.
        ClippingRectangle {
            x: Theme.toastPadX
            y: Theme.toastContentY
            width: Theme.toastImageSize
            height: Theme.toastImageSize
            radius: Theme.toastImageRadius
            color: "transparent"
            antialiasing: true
            border.width: Theme.strokeWeight
            border.color: Theme.lineNormal
            opacity: Theme.clamp01(
                Theme.toastPhase(toast.draw, Theme.drawToastImage))
            visible: toast.hasImage && opacity > 0.001

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: toast.imageSource
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Theme.toastImageSize * 3
                sourceSize.height: Theme.toastImageSize * 3
                smooth: true
                asynchronous: true
            }
        }

        // Clipped rather than elided: it is written a character at a time, and
        // an elide would rewrite its tail every frame.
        Item {
            x: toast.textX
            y: Theme.toastContentY
            width: body.width - Theme.toastPadX - toast.textX
            height: Theme.toastSummaryHeight
            clip: true

            TypedText {
                y: (parent.height - height) / 2
                content: toast.summaryText
                capacity: Theme.toastSummaryChars
                reveal: Theme.toastPhase(toast.draw, Theme.drawToastSummary)
                ink: Theme.textPrimary
                pixelSize: 12
                letterSpacing: 0.5
                opacity: Theme.opStrong
                visible: reveal > 0.001
            }
        }

        // The body is a paragraph, so it fades rather than being written: at
        // the rate the rest of the bar writes, a long one would outlast the
        // toast holding it.
        Text {
            x: toast.textX
            y: Theme.toastContentY + Theme.toastSummaryHeight + 2
            width: body.width - Theme.toastPadX - toast.textX
            maximumLineCount: Theme.toastBodyLines
            lineHeight: Theme.toastBodyLeading
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            text: toast.bodyText
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 10
            font.letterSpacing: 0.5
            opacity: Theme.opNormal * Theme.clamp01(
                Theme.toastPhase(toast.draw, Theme.drawToastBody))
            visible: toast.bodyText !== "" && opacity > 0.001
        }
    }
}
