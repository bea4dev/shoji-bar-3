import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import "../theme.js" as Theme

// A tray item's own DBus menu, drawn in the bar's vocabulary.
//
// This is the one surface outside the bar's single layer, and deliberately so:
// a context menu is as tall as the application decides, and reserving room for
// the tallest possible one inside the bar would make the compositor run the
// glass pipeline over that whole rectangle for the entire session. It is an
// xdg-popup parented to the bar, which ShojiWM already routes through its
// layer-popup blur.
PopupWindow {
    id: popup

    property var item: null
    property var anchorWindow: null
    property rect anchorRect: Qt.rect(0, 0, 1, 1)

    signal dismissed

    readonly property var entries: opener.children ? opener.children.values : []

    color: "transparent"
    visible: item !== null && entries.length > 0

    anchor.window: popup.anchorWindow
    anchor.rect: popup.anchorRect
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    implicitWidth: Math.min(Theme.menuMaxWidth,
                            Math.max(Theme.menuMinWidth, widest + Theme.menuItemPadX * 2))
    implicitHeight: column.implicitHeight + 16

    QsMenuOpener {
        id: opener
        menu: popup.item ? popup.item.menu : null
    }

    // The popup has to be sized before it is shown, so widths come from the
    // entry strings rather than from the laid-out rows.
    //
    // Measured through FontMetrics, which answers a question instead of holding
    // an answer. Driving a hidden Text by assigning its `text` inside a binding
    // that reads its `implicitWidth` is a binding loop: the assignment is what
    // invalidates the binding that made it. Tracking is added by hand because
    // advanceWidth does not apply it.
    FontMetrics {
        id: metrics
        font.family: Theme.fontMono
        font.weight: Font.Light
        font.pixelSize: Theme.menuItemFontSize
    }

    readonly property real widest: {
        var widest = 0;
        for (var i = 0; i < entries.length; i++) {
            var text = entries[i].text || "";
            widest = Math.max(widest, metrics.advanceWidth(text)
                + Theme.menuItemTracking * text.length);
        }
        return widest;
    }

    // Its own silhouette, since the compositor's island glass is clipped to the
    // bar's layer and does not reach here.
    Rectangle {
        anchors.fill: parent
        radius: Theme.menuRadiusPopup
        color: Theme.menuTint
        antialiasing: true
        border.width: Theme.strokeWeight
        border.color: Theme.lineFaint
    }

    // The leave detector is the rows' ancestor, not a sheet laid over them:
    // Qt delivers hover to every item under the pointer along the parent chain,
    // so this stays hovered while a row is, which a sibling would not.
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
                    height: modelData.isSeparator ? 9 : Theme.menuItemHeight

                    Rectangle {
                        visible: row.modelData.isSeparator
                        x: Theme.menuItemPadX
                        y: 4
                        width: column.width - Theme.menuItemPadX * 2
                        height: Theme.hairline(Screen.devicePixelRatio)
                        color: Theme.lineFaint
                        opacity: Theme.opGrid
                    }

                    // Selection is a drawn bracket down the left edge, not a fill.
                    Rectangle {
                        visible: !row.modelData.isSeparator && pointer.containsMouse
                            && row.modelData.enabled
                        x: 6
                        y: 4
                        width: Theme.hairline(Screen.devicePixelRatio) * 2
                        height: row.height - 8
                        color: Theme.lineStrong
                        opacity: Theme.opStrong
                    }

                    Text {
                        visible: !row.modelData.isSeparator
                        x: Theme.menuItemPadX
                        y: (row.height - height) / 2
                        width: column.width - Theme.menuItemPadX * 2
                        elide: Text.ElideRight
                        text: row.modelData.text || ""
                        color: pointer.containsMouse ? Theme.textPrimary : Theme.textMuted
                        font.family: Theme.fontMono
                        font.weight: Font.Light
                        font.pixelSize: 11
                        font.letterSpacing: 0.5
                        opacity: row.modelData.enabled ? 1 : Theme.opFaint
                    }

                    // Checkable entries keep the line vocabulary: an open mark that
                    // fills rather than a platform checkbox.
                    Rectangle {
                        visible: !row.modelData.isSeparator
                            && row.modelData.buttonType !== QsMenuButtonType.None
                        x: column.width - Theme.menuItemPadX - 9
                        y: (row.height - 9) / 2
                        width: 9
                        height: 9
                        radius: row.modelData.buttonType === QsMenuButtonType.RadioButton ? 4.5 : 2
                        color: row.modelData.checkState === Qt.Checked
                            ? Theme.lineStrong : "transparent"
                        antialiasing: true
                        border.width: Theme.strokeWeight
                        border.color: Theme.lineNormal
                        opacity: Theme.opNormal
                    }

                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !row.modelData.isSeparator && row.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Submenus are not opened in place; triggering the entry
                            // is what the item expects either way.
                            row.modelData.triggered();
                            popup.dismissed();
                        }
                    }
                }
            }
        }
    }

    // The bar dismisses on leaving its silhouette; this does the same, since a
    // popup with no keyboard focus never sees a click landing outside it.
    Timer {
        id: leaveTimer
        interval: Theme.closeGraceMs
        onTriggered: popup.dismissed()
    }
}
