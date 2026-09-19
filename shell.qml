//@ pragma Env QSG_RENDER_LOOP=threaded
// Animations are then driven by the display's vsync rather than a 16ms timer.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "theme.js" as Theme

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            color: "transparent"

            // Anchored to the top edge only, so the compositor centres the
            // surface horizontally and the bar sits under the screen's midline.
            anchors.top: true
            margins.top: 0

            // Reserve only the resting pill plus its padding. The surface is
            // much taller than this; the opened menu is meant to overlap
            // windows rather than push them down.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Theme.screenPad * 2 + Theme.barHeight

            WlrLayershell.layer: WlrLayer.Top
            // ShojiWM matches this namespace to route the layer through
            // ISLAND_GLASS instead of the generic behind-blur. See README.
            WlrLayershell.namespace: "shoji-bar-3"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Constant. See theme.js: resizing a top-anchored layer surface
            // re-centres it, and that reposition is not frame-synchronised with
            // the redraw that compensates for it.
            implicitWidth: Theme.surfaceWidth
            implicitHeight: Theme.surfaceHeight

            // Input is confined to the silhouettes' rounded bounds, so the
            // rest of the surface — the gap between the islands included —
            // keeps passing clicks through to the windows below.
            mask: Region {
                x: Math.round(bar.blobX)
                y: Math.round(bar.blobY)
                width: Math.round(bar.shapeW)
                height: Math.round(bar.shapeH)
                radius: Math.round(bar.shapeR)

                Region {
                    x: Math.round(bar.dockX)
                    y: Math.round(bar.dockY)
                    width: Math.round(bar.dockW)
                    height: Math.round(bar.dockH)
                    radius: Math.round(bar.dockR)
                }
            }

            ShellBar {
                id: bar
                anchors.fill: parent

                onSectionRequested: (index) => {
                    // Section panels land here: a second LiquidShape growing
                    // out of the menu's lower edge, merged by the same smooth
                    // minimum that joins the islands.
                    console.log("shoji-bar-3: section", index, "requested");
                }
            }

            TrayMenu {
                item: bar.trayMenuItem
                anchorWindow: panel
                anchorRect: bar.trayMenuRect
                onDismissed: bar.closeTrayMenu()
            }
        }
    }
}
