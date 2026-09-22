import QtQuick
import Quickshell
import ".."
import "../theme.js" as Theme

// A dock tile's menu: pin it, unpin it, start another window, close it.
//
// An xdg-popup parented to the dock's layer, the same as the tray's menu and
// for the same reason -- a menu is as tall as its contents decide, and
// reserving room for the tallest one inside the layer would make the
// compositor run the glass pipeline over that rectangle all session.
//
// It carries its own ground: ShojiWM's island glass is clipped to the layer
// and does not reach a popup, and the popup blur that does reach it is itself
// clipped to the surface's alpha, so a transparent menu would blur away to
// bare text over whatever is behind it.
PopupWindow {
    id: popup

    // One entry of Dock.entries.
    property var item: null
    property var anchorWindow: null
    property rect anchorRect: Qt.rect(0, 0, 1, 1)

    signal dismissed

    readonly property var entries: {
        var dock = popup.item;
        if (!dock)
            return [];
        var list = [];
        // Only an application we can find a .desktop file for can be started
        // again, or usefully remembered.
        if (dock.entry)
            list.push({ id: "launch", text: "NEW WINDOW" });
        if (dock.entry || dock.pinned)
            list.push({ id: dock.pinned ? "unpin" : "pin",
                        text: dock.pinned ? "UNPIN" : "PIN" });
        if (dock.windows.length > 0)
            list.push({ id: "close",
                        text: dock.windows.length > 1 ? "CLOSE ALL" : "CLOSE" });
        return list;
    }

    color: "transparent"
    visible: item !== null && entries.length > 0

    anchor.window: popup.anchorWindow
    anchor.rect: popup.anchorRect
    // The dock is at the bottom of the screen, so its menus stand on it.
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    implicitWidth: Math.min(Theme.menuMaxWidth,
                            Math.max(Theme.menuMinWidth,
                                     widest + Theme.menuItemPadX * 2))
    implicitHeight: column.implicitHeight + 16

    // The popup has to be sized before it is shown, so the width comes from
    // the strings rather than from the laid-out rows. Measured through
    // FontMetrics, which answers a question instead of holding an answer:
    // driving a hidden Text by assigning its `text` inside a binding that
    // reads its `implicitWidth` is a binding loop.
    FontMetrics {
        id: metrics
        font.family: Theme.fontMono
        font.weight: Font.Light
        font.pixelSize: Theme.menuItemFontSize
    }

    readonly property real widest: {
        var widest = 0;
        for (var i = 0; i < entries.length; i++) {
            var text = entries[i].text;
            widest = Math.max(widest, metrics.advanceWidth(text)
                + Theme.menuItemTracking * text.length);
        }
        return widest;
    }

    function run(id) {
        var dock = popup.item;
        popup.dismissed();
        if (!dock)
            return;
        if (id === "launch")
            Dock.launch(dock);
        else if (id === "pin")
            Dock.pin(dock.key);
        else if (id === "unpin")
            Dock.unpin(dock.key);
        else if (id === "close")
            Dock.closeAll(dock);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.menuRadiusPopup
        color: Theme.menuTint
        antialiasing: true
        border.width: Theme.strokeWeight
        border.color: Theme.lineFaint
    }

    // The leave detector is the rows' ancestor, not a sheet laid over them:
    // Qt delivers hover to every item under the pointer along the parent
    // chain, so this stays hovered while a row is, which a sibling would not.
    MouseArea {
        id: bounds
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: leaveTimer.stop()
        onExited: leaveTimer.restart()

        Column {
            id: column
            x: 0
            y: 8
            width: parent.width

            Repeater {
                model: popup.entries

                delegate: Item {
                    id: row
                    required property var modelData

                    width: column.width
                    height: Theme.menuItemHeight

                    // Selection is a drawn bracket down the left edge, not a
                    // fill.
                    Rectangle {
                        visible: pointer.containsMouse
                        x: 6
                        y: 4
                        width: Theme.hairline(Screen.devicePixelRatio) * 2
                        height: row.height - 8
                        color: Theme.lineStrong
                        opacity: Theme.opStrong
                    }

                    Text {
                        x: Theme.menuItemPadX
                        y: (row.height - height) / 2
                        width: column.width - Theme.menuItemPadX * 2
                        elide: Text.ElideRight
                        text: row.modelData.text
                        color: pointer.containsMouse ? Theme.textPrimary
                            : Theme.textMuted
                        font.family: Theme.fontMono
                        font.weight: Font.Light
                        font.pixelSize: Theme.menuItemFontSize
                        font.letterSpacing: Theme.menuItemTracking
                    }

                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.run(row.modelData.id)
                    }
                }
            }
        }
    }

    // A popup with no keyboard focus never sees a click landing outside it,
    // so leaving is what dismisses it -- the same as the bar's menus.
    Timer {
        id: leaveTimer
        interval: Theme.closeGraceMs
        onTriggered: popup.dismissed()
    }
}
