import QtQuick
import "../theme.js" as Theme

// Contents of the lower island. The item itself is the silhouette's animated
// box and clips; the contents are laid out at the island's full size and
// centred inside it, so nothing shifts as the island necks out and settles.
Item {
    id: dock

    property var trayItems: []
    property int trayHovered: -1

    property real batteryIconReveal: 1
    property real batteryValueReveal: 1
    property real batteryStatusReveal: 1
    property real batteryGaugeDraw: 1
    property real trayFrameDraw: 1
    property real trayIconsReveal: 1

    readonly property alias tray: trayRow

    clip: true

    Item {
        x: (dock.width - Theme.dockWidth) / 2
        y: (dock.height - Theme.dockHeight) / 2
        width: Theme.dockWidth
        height: Theme.dockHeight

        BatteryRow {
            anchors.fill: parent
            iconReveal: dock.batteryIconReveal
            valueReveal: dock.batteryValueReveal
            statusReveal: dock.batteryStatusReveal
            gaugeDraw: dock.batteryGaugeDraw
        }

        TrayRow {
            id: trayRow
            anchors.fill: parent
            items: dock.trayItems
            frameDraw: dock.trayFrameDraw
            iconsReveal: dock.trayIconsReveal
            hoveredIndex: dock.trayHovered
        }
    }
}
