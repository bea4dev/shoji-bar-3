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
            // The bar is a pointer instrument and takes the keyboard only
            // while the launcher is showing, which is the one panel that reads
            // typing. ShojiWM hands focus to a layer the moment it asks for it
            // and gives it back the moment it stops, so this is also what
            // returns the keyboard to the window underneath.
            WlrLayershell.keyboardFocus: bar.launcherOpen
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Constant. See theme.js: resizing a top-anchored layer surface
            // re-centres it, and that reposition is not frame-synchronised with
            // the redraw that compensates for it.
            implicitWidth: Theme.surfaceWidth
            implicitHeight: Theme.surfaceHeight

            // Input is confined to the silhouettes plus the neck that joins
            // them, so the rest of the surface keeps passing clicks through to
            // the windows below.
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

                Region {
                    x: Math.round(bar.launcherX)
                    y: Math.round(bar.launcherY)
                    width: Math.round(bar.launcherW)
                    height: Math.round(bar.launcherH)
                    radius: Math.round(bar.launcherR)
                }

                Region {
                    x: Math.round(bar.clockX)
                    y: Math.round(bar.clockY)
                    width: Math.round(bar.clockW)
                    height: Math.round(bar.clockH)
                    radius: Math.round(bar.clockR)
                }

                // The neck between the islands draws as glass but is not part
                // of either rounded box, and a hole in the input region reads
                // to the client as "the pointer left the bar": crossing the
                // gap dismissed the menu under the cursor. One per lower
                // island, each spanning its own width and collapsing to
                // nothing while that island still overlaps the menu.
                Region {
                    readonly property int top: Math.round(bar.blobY + bar.shapeH) - 1
                    x: Math.round(bar.dockX)
                    y: top
                    width: Math.round(bar.dockW)
                    height: Math.max(0, Math.round(bar.dockY) - top + 1)
                }

                Region {
                    readonly property int top: Math.round(bar.blobY + bar.shapeH) - 1
                    x: Math.round(bar.launcherX)
                    y: top
                    width: Math.round(bar.launcherW)
                    height: Math.max(0, Math.round(bar.launcherY) - top + 1)
                }

                Region {
                    readonly property int top: Math.round(bar.blobY + bar.shapeH) - 1
                    x: Math.round(bar.clockX)
                    y: top
                    width: Math.round(bar.clockW)
                    height: Math.max(0, Math.round(bar.clockY) - top + 1)
                }
            }

            ShellBar {
                id: bar
                anchors.fill: parent

                onSectionRequested: (index) => {
                    // Only tiles without a panel of their own reach here. The
                    // launcher is built into the bar (LauncherIsland), and the
                    // remaining two follow that shape: another island in the
                    // same socket, swapped for whichever one is showing.
                    console.log("shoji-bar-3: section", index, "requested");
                }
            }

            // Requests from outside the bar: a compositor keybinding, a
            // script. The request names a screen so a binding can send it to
            // the monitor under the pointer -- ShojiWM's config already
            // computes that for its other shell calls -- and an empty name
            // addresses every screen.
            Connections {
                target: LauncherIpc

                function onRequested(action: string, screenName: string): void {
                    if (screenName !== "" && screenName !== panel.screen.name)
                        return;
                    if (action === "open")
                        bar.openLauncher();
                    else if (action === "close")
                        bar.closeLauncher();
                    else
                        bar.toggleLauncher();
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
