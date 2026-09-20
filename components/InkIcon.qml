import QtQuick
import Qt5Compat.GraphicalEffects
import "../theme.js" as Theme

// A stroked SVG asset recoloured at draw time, so the palette stays in
// theme.js and the files stay swappable.
//
// A raster glyph cannot be drawn stroke by stroke, so these only fade, and
// their window is meant to be anchored to whatever line work they belong with
// rather than pretending to be pen work of their own.
Item {
    id: icon

    property url source
    property color ink: Theme.lineNormal
    property real reveal: 1
    // Weight within the reveal: how present the icon is once it has arrived.
    property real strength: 1

    implicitWidth: 20
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight

    Image {
        id: glyph
        anchors.fill: parent
        source: icon.source
        // Rasterize the SVG well above its drawn size; these are thin strokes.
        sourceSize.width: icon.width * 4
        sourceSize.height: icon.height * 4
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: glyph
        source: glyph
        color: icon.ink
        opacity: Theme.clamp01(icon.reveal) * icon.strength
        visible: opacity > 0.001

        Behavior on opacity {
            enabled: icon.reveal >= 0.999
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }
}
