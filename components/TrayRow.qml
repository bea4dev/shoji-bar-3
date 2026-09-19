import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../theme.js" as Theme

// The tray, held in a drawn frame. Pointer handling belongs to the bar's single
// MouseArea, which hit-tests these positions; nothing here accepts input, so
// nothing here can steal the hover state that keeps the menu open.
Item {
    id: tray

    property var items: []
    property real frameDraw: 1
    property real iconsReveal: 1
    property int hoveredIndex: -1

    readonly property int count: items.length
    readonly property real pitch: Theme.trayIconSize + Theme.trayIconGap
    readonly property real runWidth: count > 0
        ? count * Theme.trayIconSize + (count - 1) * Theme.trayIconGap : 0

    // Dock-local x of one icon's left edge. The bar hit-tests with the same
    // function, so the two can never drift apart.
    function iconX(index: int): real {
        return (tray.width - runWidth) / 2 + index * pitch;
    }

    readonly property real frameWidth: tray.width - Theme.dockPadX * 2

    Shape {
        x: Theme.dockPadX
        y: Theme.trayFrameY
        width: tray.frameWidth
        height: Theme.trayFrameHeight
        preferredRendererType: Shape.CurveRenderer
        opacity: Theme.opNormal
        visible: tray.frameDraw > 0.001

        ShapePath {
            strokeColor: Theme.lineNormal
            strokeWidth: Theme.strokeWeight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: Theme.roundedRectPath(tray.frameWidth, Theme.trayFrameHeight,
                                            Theme.trayFrameRadius, tray.frameDraw)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.trayFrameY + (Theme.trayFrameHeight - height) / 2
        text: "NO ITEMS"
        color: Theme.textMuted
        font.family: Theme.fontMono
        font.weight: Font.Light
        font.pixelSize: 9
        font.letterSpacing: 2
        opacity: Theme.opGrid * Theme.clamp01(tray.iconsReveal)
        visible: tray.count === 0 && opacity > 0.001
    }

    Repeater {
        model: tray.items
        delegate: Item {
            id: cell
            required property int index
            required property var modelData

            // Each icon takes its own slice of the stage, left to right.
            readonly property real reveal:
                Theme.clamp01(tray.iconsReveal * tray.count - index)
            readonly property bool hovered: tray.hoveredIndex === index

            x: tray.iconX(index)
            y: Theme.trayFrameY + (Theme.trayFrameHeight - Theme.trayIconSize) / 2
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            visible: reveal > 0.001

            // Hover is a drawn bracket rather than a fill, matching the tiles.
            Rectangle {
                anchors.centerIn: parent
                width: Theme.trayIconSize + 12
                height: Theme.trayIconSize + 12
                radius: 9
                color: "transparent"
                antialiasing: true
                border.width: Theme.strokeWeight
                border.color: Theme.lineStrong
                opacity: cell.hovered ? Theme.opFaint : 0

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            Image {
                id: appIcon
                anchors.fill: parent
                source: cell.modelData.icon
                sourceSize.width: Theme.trayIconSize * 3
                sourceSize.height: Theme.trayIconSize * 3
                smooth: true
                visible: Theme.trayDesaturate <= 0.001
                opacity: cell.reveal * (cell.hovered ? 1 : 0.88)
            }

            Desaturate {
                anchors.fill: appIcon
                source: appIcon
                desaturation: Theme.trayDesaturate
                visible: Theme.trayDesaturate > 0.001
                opacity: cell.reveal * (cell.hovered ? 1 : 0.88)
            }
        }
    }
}
