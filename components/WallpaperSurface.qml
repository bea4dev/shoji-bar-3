import QtQuick
import "../theme.js" as Theme

// The picture itself, on the background layer.
//
// Two images that trade places rather than one that changes source: a single
// Image goes blank while the next file is decoded, and a wallpaper blinking to
// black between choices is worse than no animation at all. The incoming one is
// only faded up once it reports itself ready, so the crossfade always has
// something to cross to.
Item {
    id: wall

    property string source: ""

    // Which of the two is the one being shown.
    property bool showFirst: true

    function settle(image) {
        if (image.status !== Image.Ready)
            return;
        if (String(image.source) !== String(wall.source))
            return;
        showFirst = image === first;
    }

    onSourceChanged: {
        if (source === "")
            return;
        var target = showFirst ? second : first;
        // Already decoded on the other side: nothing to wait for.
        if (String(target.source) === String(source))
            showFirst = !showFirst;
        else
            target.source = source;
    }

    // Under both, so a picture that does not cover the output has something
    // to sit on rather than showing whatever the compositor last drew.
    Rectangle {
        anchors.fill: parent
        color: Theme.wallpaperGround
    }

    Image {
        id: first
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        opacity: wall.showFirst ? 1 : 0
        visible: opacity > 0.001
        onStatusChanged: wall.settle(first)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.wallpaperFadeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    Image {
        id: second
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        opacity: wall.showFirst ? 0 : 1
        visible: opacity > 0.001
        onStatusChanged: wall.settle(second)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.wallpaperFadeMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }
    }
}
