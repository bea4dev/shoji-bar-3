import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Widgets
import ".."
import "../theme.js" as Theme

// The settings panel: the third section, in the same socket as the others.
//
// Four sections along the top and one pane below them. The tabs are the menu's
// row of tiles at a smaller scale, standing on a rule with a tick dropping
// from the chosen one into the pane -- the menu's drop lines, pointing the
// other way. Each tab's icon is the setting's state as well as its name, so
// the row answers "what is on" without the pane being read at all.
//
// The pane is one header line and one list, for every section. Three of the
// four have a list of things to act on -- networks, devices, arrivals -- so
// the shape is built once and each section supplies rows. A row is a state
// mark, a name, an optional level and a note, which is enough for all three:
// how well a network is heard, what a device's battery has left, who sent an
// arrival.
//
// Two pen drivers. `draw` covers the tabs and their rule, drawn once when the
// panel arrives; `paneDraw` covers the pane, drawn again every time another
// section is chosen. Choosing must not redraw the tabs that did the choosing.
Item {
    id: settings

    property real draw: 1
    property real paneDraw: 1
    property int hoveredTab: -1
    property int hoveredControl: -1
    property int hoveredRow: -1
    property int hoveredClose: -1
    property int hoveredScroll: -1
    // Whether the panel may hold the keyboard. Only the passphrase prompt
    // wants it, and only while it is up.
    property bool active: false

    // Which section is showing. The panel opens on notifications.
    property int page: Theme.settingsNotifyPage
    // First visible row of the current section's list.
    property int first: 0
    // The network waiting for a passphrase, or null.
    property var promptNetwork: null
    // What the last attempt did, shown until the next one.
    property string status: ""

    readonly property bool prompting: promptNetwork !== null
    readonly property var labels: ["WIFI", "BLUETOOTH", "POWER", "NOTIFY", "WALL"]

    // ----- the services -----------------------------------------------------

    readonly property var wifiDevice: {
        var devices = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var wifiNetwork: {
        if (!wifiDevice || !wifiDevice.networks)
            return null;
        var networks = wifiDevice.networks.values;
        for (var i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter ? adapter.enabled : false
    readonly property int profile: PowerProfiles.profile
    readonly property bool dnd: ShellState.doNotDisturb

    readonly property var btConnected: {
        var out = [];
        var devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                out.push(devices[i]);
        }
        return out;
    }

    // Scanning costs power and is only worth doing while someone is looking at
    // the list. The binding hands the property back when they stop.
    Binding {
        target: settings.wifiDevice
        property: "scannerEnabled"
        value: true
        when: settings.wifiDevice !== null && settings.visible
            && settings.page === 0 && settings.wifiOn
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Discovery, for the same reason: a device that has never been paired
    // cannot appear in the list until the adapter has looked for it.
    Binding {
        target: settings.adapter
        property: "discovering"
        value: true
        when: settings.adapter !== null && settings.visible
            && settings.page === 1 && settings.btOn
        restoreMode: Binding.RestoreBindingOrValue
    }

    // ----- the rows ---------------------------------------------------------
    //
    // One shape for all three lists: what state it is in, what it is called,
    // how much of something it has, and one word about it.

    readonly property var rows: {
        if (page === 0)
            return wifiRows();
        if (page === 1)
            return btRows();
        if (page === 3)
            return notifyRows();
        if (page === Theme.settingsWallPage)
            return wallRows();
        return [];
    }

    readonly property int visibleRows:
        Theme.settingsListRows - (prompting ? 1 : 0)
    readonly property int lastFirst: Math.max(0, rows.length - visibleRows)
    readonly property bool scrollable: rows.length > visibleRows

    readonly property bool clearable: page === 3 && Notifications.count > 0
    readonly property real clearWidth: 62
    readonly property real clearX: Theme.settingsWidth - Theme.settingsPadX
        - Theme.switchWidth - 14 - readingWidth - 14 - clearWidth
    // Reserved for the header's reading, so the button beside it can be
    // placed without measuring laid-out text from a binding.
    readonly property real readingWidth: reading === "" ? -14 : 56

    function wifiRows() {
        if (!wifiOn || !wifiDevice || !wifiDevice.networks)
            return [];
        var networks = wifiDevice.networks.values.slice();
        // Connected first, then remembered, then by how well they are heard.
        networks.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        var out = [];
        for (var i = 0; i < networks.length; i++) {
            var network = networks[i];
            out.push({
                target: network,
                primary: network.name || "HIDDEN",
                sub: "",
                image: "",
                closable: false,
                note: network.stateChanging
                    ? (network.connected ? "LEAVING" : "JOINING")
                    : network.connected ? "ONLINE" : securityName(network.security),
                // Reported as a fraction, not a percentage.
                level: Theme.clamp01(network.signalStrength || 0),
                marked: network.connected,
                ring: network.known
            });
        }
        return out;
    }

    function btRows() {
        if (!btOn || !adapter)
            return [];
        var devices = Bluetooth.devices ? Bluetooth.devices.values.slice() : [];
        devices.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return (a.name || "") < (b.name || "") ? -1 : 1;
        });
        var out = [];
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i];
            out.push({
                target: device,
                primary: device.name || device.address || "DEVICE",
                sub: "",
                image: "",
                closable: false,
                note: device.pairing ? "PAIRING"
                    : device.connected ? "LINKED"
                    : device.paired ? "PAIRED" : "NEW",
                level: device.batteryAvailable
                    ? Theme.clamp01(device.battery) : -1,
                marked: device.connected,
                ring: device.paired
            });
        }
        return out;
    }

    function wallRows() {
        var pictures = WallpaperState.files;
        var out = [];
        for (var i = 0; i < pictures.length; i++) {
            var picture = pictures[i];
            out.push({
                target: picture.url,
                // The extension says nothing the thumbnail does not.
                primary: picture.name.replace(/\.[^.]+$/, ""),
                sub: "",
                image: picture.url,
                closable: false,
                note: WallpaperState.isCurrent(picture.url) ? "ON SCREEN" : "",
                level: -1,
                marked: WallpaperState.isCurrent(picture.url),
                ring: false
            });
        }
        return out;
    }

    function notifyRows() {
        var kept = Notifications.list;
        var out = [];
        // Newest first: the list is read from the top.
        for (var i = kept.length - 1; i >= 0; i--) {
            var notification = kept[i];
            out.push({
                target: notification,
                primary: notification.summary || "ARRIVAL",
                // Part of what it said, on the same line: a summary alone is
                // "Alice" and says nothing about why she wrote.
                sub: notification.summary ? oneLine(notification.body) : "",
                image: arrivalImage(notification),
                closable: true,
                note: (notification.appName || "").toUpperCase(),
                level: -1,
                marked: notification.urgency === NotificationUrgency.Critical,
                ring: (notification.actions || []).length > 0
            });
        }
        return out;
    }

    // A body is a paragraph and the row is one line; the breaks would show up
    // as gaps otherwise.
    function oneLine(text) {
        return (text || "").replace(/\s+/g, " ").trim();
    }

    // The picture the sender attached, with its application icon standing in.
    function arrivalImage(notification) {
        if (notification.image)
            return notification.image;
        if (notification.appIcon)
            return Quickshell.iconPath(notification.appIcon, "");
        return "";
    }

    // ----- what the header says ---------------------------------------------

    readonly property var profileNames: ["POWER SAVER", "BALANCED", "PERFORMANCE"]

    readonly property string title: ["WIRELESS", "BLUETOOTH", "POWER PROFILE",
        "DO NOT DISTURB", "WALLPAPER"][page]

    readonly property bool hasSwitch: page !== 2 && page !== Theme.settingsWallPage
    readonly property bool switchOn: page === 0 ? wifiOn
        : page === 1 ? btOn : dnd

    // What the list would say if it had anything to say.
    readonly property string empty: {
        if (page === 0)
            return !Networking.wifiHardwareEnabled ? "HARDWARE BLOCKED"
                : !wifiOn ? "RADIO OFF" : "NOTHING IN RANGE";
        if (page === 1)
            return !adapter ? "NO ADAPTER"
                : !btOn ? "RADIO OFF" : "NOTHING FOUND";
        if (page === 3)
            return dnd ? "HELD, NOTHING KEPT" : "NOTHING KEPT";
        if (page === Theme.settingsWallPage)
            return "NOTHING IN " + WallpaperState.source;
        return "";
    }

    // A short reading beside the header, or what the last attempt did.
    readonly property string reading: {
        if (status !== "")
            return status;
        if (page === 0)
            return wifiOn ? connectivityName(Networking.connectivity) : "";
        if (page === 1)
            return btOn && btConnected.length > 0
                ? btConnected.length + " LINKED" : "";
        if (page === 2)
            return profileNames[profile];
        if (page === Theme.settingsWallPage)
            return WallpaperState.count > 0 ? WallpaperState.count + " FOUND" : "";
        return Notifications.count > 0 ? Notifications.count + " KEPT" : "";
    }

    function securityName(value) {
        if (value === WifiSecurityType.Open)
            return "OPEN";
        if (value === WifiSecurityType.Owe)
            return "OWE";
        if (value === WifiSecurityType.Sae || value === WifiSecurityType.Wpa3SuiteB192)
            return "WPA3";
        if (value === WifiSecurityType.Wpa2Psk || value === WifiSecurityType.Wpa2Eap)
            return "WPA2";
        if (value === WifiSecurityType.WpaPsk || value === WifiSecurityType.WpaEap)
            return "WPA";
        if (value === WifiSecurityType.StaticWep || value === WifiSecurityType.DynamicWep)
            return "WEP";
        return "SECURED";
    }

    function connectivityName(value) {
        if (value === NetworkConnectivity.Full)
            return "ONLINE";
        if (value === NetworkConnectivity.Portal)
            return "PORTAL";
        if (value === NetworkConnectivity.Limited)
            return "LIMITED";
        if (value === NetworkConnectivity.None)
            return "OFFLINE";
        return "";
    }

    function failureName(reason) {
        if (reason === ConnectionFailReason.NoSecrets
            || reason === ConnectionFailReason.WifiAuthTimeout)
            return "WRONG PASSPHRASE";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "NETWORK LOST";
        return "COULD NOT JOIN";
    }

    // An open network needs no secret, and one already remembered has one.
    function needsSecret(network) {
        return !network.known
            && network.security !== WifiSecurityType.Open
            && network.security !== WifiSecurityType.Owe;
    }

    // The tab icon reports the section's state, so the row reads as a set of
    // indicators rather than as four labels.
    function tabIcon(index) {
        var name;
        if (index === 0)
            name = !wifiOn ? "wifi-off"
                : !wifiNetwork ? "wifi-nosignal"
                : wifiNetwork.security === WifiSecurityType.Open ? "wifi" : "wifi-safe";
        else if (index === 1)
            name = btOn ? "bluetooth" : "bluetooth-off";
        else if (index === 2)
            name = profile === PowerProfile.PowerSaver ? "power-saver"
                : profile === PowerProfile.Performance ? "performance" : "balanced";
        else if (index === 3)
            name = dnd ? "notif-off"
                : Notifications.count > 0 ? "notif-has" : "notif";
        else
            // An empty folder is the one thing worth reporting here.
            name = WallpaperState.count > 0 ? "picture" : "folder";
        return Qt.resolvedUrl("../assets/icons/" + name + ".svg");
    }

    // A failed attempt says so where the reading goes, rather than leaving the
    // network quietly unjoined. One connection per network in the list.
    Instantiator {
        model: settings.wifiDevice ? settings.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true

            function onConnectionFailed(reason: int): void {
                settings.status = settings.failureName(reason);
            }
        }
    }

    // ----- input ------------------------------------------------------------
    //
    // Hit tests in the panel's own coordinates, called by the bar's single
    // MouseArea. Nothing here accepts input of its own except the passphrase
    // field, which needs the caret.

    function tabAt(lx, ly) {
        if (ly < 4 || ly > Theme.settingsRuleY)
            return -1;
        var half = (Theme.settingsWidth - Theme.settingsPadX * 2)
            / (Theme.settingsTabs * 2) - 4;
        for (var i = 0; i < Theme.settingsTabs; i++) {
            if (Math.abs(lx - Theme.settingsTabX(i)) <= half)
                return i;
        }
        return -1;
    }

    function controlAt(lx, ly) {
        if (page === 2) {
            if (ly < Theme.settingsSelectorY - 16
                || ly > Theme.settingsSelectorLabelY + 12)
                return -1;
            var third = (Theme.settingsWidth - Theme.settingsPadX * 2) / 3;
            for (var i = 0; i < 3; i++) {
                if (Math.abs(lx - (Theme.settingsPadX + third * (i + 0.5))) > third / 2)
                    continue;
                // Offering a profile the daemon does not have would be a
                // control that answers nothing.
                if (i === 2 && !PowerProfiles.hasPerformanceProfile)
                    return -1;
                return i;
            }
            return -1;
        }
        if (!hasSwitch)
            return -1;
        if (Math.abs(ly - (Theme.settingsPaneY + Theme.settingsRowHeight / 2)) > 14)
            return -1;
        var sx = Theme.settingsWidth - Theme.settingsPadX - Theme.switchWidth / 2;
        if (Math.abs(lx - sx) <= Theme.switchWidth / 2 + 10)
            return 0;
        // Emptying the whole list is offered beside the switch that silences
        // it, and only while there is something to empty.
        if (clearable && lx >= clearX - 10 && lx <= clearX + clearWidth + 10)
            return 1;
        return -1;
    }

    // Slot in the visible list, not an index into the rows: the caller never
    // has to know about the scroll offset or the prompt taking the first slot.
    function rowAt(lx, ly) {
        if (lx < 0 || lx > Theme.settingsWidth || rows.length === 0)
            return -1;
        var slot = Math.floor((ly - Theme.settingsListY) / Theme.settingsListRowHeight);
        if (slot < 0 || slot >= Theme.settingsListRows)
            return -1;
        slot -= prompting ? 1 : 0;
        if (slot < 0)
            return -1;
        return first + slot < rows.length ? slot : -1;
    }

    // The dismiss mark of one row, which sits inside that row and therefore
    // has to be asked about before the row itself is.
    function closeAt(lx, ly) {
        if (Math.abs(lx - Theme.settingsCloseX) > Theme.settingsCloseHit / 2)
            return -1;
        var slot = rowAt(lx, ly);
        if (slot < 0)
            return -1;
        var row = rows[first + slot];
        return row && row.closable ? slot : -1;
    }

    // The paging marks in the right margin: 0 steps up, 1 steps down.
    function scrollAt(lx, ly) {
        if (!scrollable || Math.abs(lx - Theme.settingsScrollX) > Theme.settingsScrollHit / 2)
            return -1;
        if (Math.abs(ly - Theme.settingsScrollUpY) <= Theme.settingsScrollHit / 2)
            return first > 0 ? 0 : -1;
        if (Math.abs(ly - Theme.settingsScrollDownY) <= Theme.settingsScrollHit / 2)
            return first < lastFirst ? 1 : -1;
        return -1;
    }

    function dismissRow(slot) {
        var row = rows[first + slot];
        if (row && row.closable)
            row.target.dismiss();
    }

    function activate(index) {
        if (page === 0)
            Networking.wifiEnabled = !Networking.wifiEnabled;
        else if (page === 1) {
            if (adapter)
                adapter.enabled = !adapter.enabled;
        } else if (page === 2)
            PowerProfiles.profile = index;
        else if (index === 1)
            Notifications.clearAll();
        else
            ShellState.doNotDisturb = !ShellState.doNotDisturb;
    }

    // Primary acts, secondary forgets. The destructive one is the one that
    // needs the deliberate button.
    function activateRow(slot, secondary) {
        var row = rows[first + slot];
        if (!row)
            return;
        var target = row.target;
        status = "";
        if (page === 0) {
            if (secondary) {
                if (target.known)
                    target.forget();
                return;
            }
            if (target.connected) {
                target.disconnect();
                return;
            }
            if (needsSecret(target)) {
                promptNetwork = target;
                return;
            }
            target.connect();
        } else if (page === 1) {
            if (secondary) {
                if (target.paired)
                    target.forget();
                return;
            }
            if (target.connected)
                target.disconnect();
            else if (target.paired)
                target.connect();
            else
                target.pair();
        } else if (page === Theme.settingsWallPage) {
            WallpaperState.choose(target);
        } else if (page === 3) {
            if (secondary) {
                target.dismiss();
                return;
            }
            var actions = target.actions || [];
            for (var i = 0; i < actions.length; i++) {
                if (actions[i].identifier === "default") {
                    actions[i].invoke();
                    return;
                }
            }
            target.dismiss();
        }
    }

    function scrollBy(delta) {
        var moved = Math.max(0, Math.min(lastFirst, first + delta));
        if (moved !== first)
            first = moved;
    }

    function submitPrompt() {
        var network = promptNetwork;
        if (!network)
            return;
        var secret = psk.text;
        promptNetwork = null;
        psk.text = "";
        status = "JOINING";
        network.connectWithPsk(secret);
    }

    function cancelPrompt() {
        promptNetwork = null;
        psk.text = "";
    }

    function reset() {
        page = Theme.settingsNotifyPage;
        first = 0;
        status = "";
        cancelPrompt();
    }

    onPageChanged: {
        first = 0;
        status = "";
        cancelPrompt();
    }

    onRowsChanged: {
        if (first > lastFirst)
            first = lastFirst;
    }

    // An item that is not visible cannot hold active focus, so the grab waits
    // for the panel to exist rather than happening when it is asked for.
    function syncFocus() {
        if (active && visible && prompting)
            psk.forceActiveFocus();
        else
            psk.focus = false;
    }

    onActiveChanged: syncFocus()
    onVisibleChanged: syncFocus()
    onPromptingChanged: syncFocus()

    clip: true

    // Contents at the island's full size, centred in its animated box.
    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.settingsWidth - Theme.settingsPadX * 2

        x: (settings.width - Theme.settingsWidth) / 2
        y: (settings.height - Theme.settingsHeight) / 2
        width: Theme.settingsWidth
        height: Theme.settingsHeight

        // ----- tabs ---------------------------------------------------------

        Repeater {
            model: Theme.settingsTabs
            delegate: Item {
                id: tab

                required property int index
                readonly property bool current: settings.page === index
                readonly property bool lit: current || settings.hoveredTab === index
                readonly property real iconReveal: Theme.pen(Theme.settingsPhase(
                    settings.draw, Theme.drawSettingsIcon, index))
                readonly property real labelReveal: Theme.settingsPhase(
                    settings.draw, Theme.drawSettingsLabel, index)

                x: 0
                y: 0
                width: body.width
                height: Theme.settingsRuleY

                InkIcon {
                    x: Theme.settingsTabX(tab.index) - width / 2
                    y: Theme.settingsTabIconY - height / 2
                    width: Theme.settingsTabIconSize
                    height: Theme.settingsTabIconSize
                    source: settings.tabIcon(tab.index)
                    ink: tab.lit ? Theme.lineStrong : Theme.lineNormal
                    reveal: tab.iconReveal
                    strength: tab.lit ? 1 : 0.7
                }

                TypedText {
                    x: Theme.settingsTabX(tab.index) - width / 2
                    y: Theme.settingsTabLabelY - height / 2
                    content: settings.labels[tab.index]
                    capacity: Theme.settingsTabChars
                    reveal: tab.labelReveal
                    ink: tab.lit ? Theme.textPrimary : Theme.textMuted
                    pixelSize: 8
                    letterSpacing: 1.5
                    opacity: tab.current ? Theme.opStrong
                        : tab.lit ? Theme.opNormal : Theme.opFaint
                    visible: tab.labelReveal > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.settingsPhase(settings.draw, Theme.drawSettingsRule))

            x: Theme.settingsPadX
            y: Theme.snap(Theme.settingsRuleY, Screen.devicePixelRatio)
            width: body.inner * drawn
            height: body.hairline
            color: Theme.lineFaint
            opacity: Theme.opGrid + 0.1
            visible: drawn > 0.001
        }

        // The tick that ties the chosen section to the pane. It travels rather
        // than being redrawn, so choosing reads as one mark moving along the
        // rule instead of two marks blinking.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.settingsPhase(settings.draw, Theme.drawSettingsDrop))

            x: Theme.snap(Theme.settingsTabX(settings.page) - body.hairline / 2,
                          Screen.devicePixelRatio)
            y: Theme.settingsRuleY
            width: body.hairline
            height: Theme.settingsDropLen * drawn
            color: Theme.lineStrong
            opacity: Theme.opNormal
            visible: drawn > 0.001

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }

        // ----- header -------------------------------------------------------

        TypedText {
            x: Theme.settingsPadX
            y: Theme.settingsPaneY + (Theme.settingsRowHeight - height) / 2
            content: settings.title
            capacity: Theme.settingsTitleChars
            reveal: Theme.panePhase(settings.paneDraw, Theme.drawPaneTitle)
            ink: Theme.textPrimary
            pixelSize: 11
            letterSpacing: 2
            opacity: Theme.opStrong
            visible: reveal > 0.001
        }

        TypedText {
            x: body.width - Theme.settingsPadX - width
                - (settings.hasSwitch ? Theme.switchWidth + 14 : 0)
            y: Theme.settingsPaneY + (Theme.settingsRowHeight - height) / 2
            content: settings.reading
            capacity: Theme.settingsDetailChars
            reveal: Theme.panePhase(settings.paneDraw, Theme.drawPaneDetail)
            ink: settings.status !== "" ? Theme.textPrimary : Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
            visible: settings.reading !== "" && reveal > 0.001
        }

        // Emptying the list, beside the switch that silences it.
        Text {
            readonly property bool lit: settings.hoveredControl === 1

            x: settings.clearX
            y: Theme.settingsPaneY + (Theme.settingsRowHeight - height) / 2
            width: settings.clearWidth
            horizontalAlignment: Text.AlignRight
            text: "CLEAR ALL"
            color: lit ? Theme.textPrimary : Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 8
            font.letterSpacing: 1.5
            opacity: Theme.clamp01(
                Theme.panePhase(settings.paneDraw, Theme.drawPaneDetail))
                * (lit ? Theme.opStrong : Theme.opFaint)
            visible: settings.clearable && opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        LineSwitch {
            x: body.width - Theme.settingsPadX - width
            y: Theme.settingsPaneY + (Theme.settingsRowHeight - height) / 2
            on: settings.switchOn
            hovered: settings.hoveredControl === 0
            draw: Theme.pen(Theme.panePhase(settings.paneDraw, Theme.drawPaneControl))
            visible: settings.hasSwitch && draw > 0.001
        }

        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.panePhase(settings.paneDraw, Theme.drawPaneRule))

            x: Theme.settingsPadX
            y: Theme.snap(Theme.settingsListY - 6, Screen.devicePixelRatio)
            width: body.inner * drawn
            height: body.hairline
            color: Theme.lineFaint
            opacity: Theme.opGrid * 0.8
            visible: drawn > 0.001
        }

        // ----- the passphrase prompt ----------------------------------------
        //
        // Takes the list's first slot rather than covering it: the network it
        // belongs to is still on screen, one row below.

        Item {
            id: prompt

            x: 0
            y: Theme.settingsListY
            width: body.width
            height: Theme.settingsListRowHeight
            visible: settings.prompting

            Chevron {
                span: 9
                drop: 4
                rotation: -90
                transformOrigin: Item.Center
                x: Theme.settingsMarkX - width / 2
                y: (prompt.height - height) / 2
                ink: Theme.lineStrong
                opacity: Theme.opNormal
            }

            TextInput {
                id: psk

                x: Theme.settingsRowTextX
                y: (prompt.height - height) / 2
                width: body.width - Theme.settingsPadX - 64 - Theme.settingsRowTextX
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 11
                font.letterSpacing: 1.5
                echoMode: TextInput.Password
                passwordCharacter: "·"
                selectionColor: Theme.lineNormal
                selectedTextColor: Theme.textPrimary
                selectByMouse: true
                clip: true

                cursorDelegate: Rectangle {
                    width: body.hairline
                    color: Theme.lineStrong

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: psk.activeFocus
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 520 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 420 }
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape)
                        settings.cancelPrompt();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        settings.submitPrompt();
                    else
                        return;
                    event.accepted = true;
                }
            }

            Text {
                x: psk.x
                y: (prompt.height - height) / 2
                text: settings.promptNetwork
                    ? "KEY FOR " + settings.promptNetwork.name : ""
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 9
                font.letterSpacing: 2
                opacity: Theme.opGrid
                visible: psk.text.length === 0
            }

            Text {
                x: body.width - Theme.settingsPadX - width
                y: (prompt.height - height) / 2
                text: "ENTER"
                color: Theme.lineFaint
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 8
                font.letterSpacing: 2
                opacity: Theme.opGrid
            }
        }

        // ----- the list -----------------------------------------------------

        Repeater {
            model: Theme.settingsListRows
            delegate: Item {
                id: entry

                required property int index
                // The prompt, when it is up, takes the first slot.
                readonly property int slot: index - (settings.prompting ? 1 : 0)
                readonly property var row: slot >= 0
                    ? settings.rows[settings.first + slot] : undefined
                readonly property real drawn: Theme.pen(Theme.panePhase(
                    settings.paneDraw, Theme.drawPaneRow, index))
                readonly property bool lit: slot >= 0 && settings.hoveredRow === slot

                x: 0
                y: Theme.settingsListRowY(entry.index)
                width: body.width
                height: Theme.settingsListRowHeight
                visible: row !== undefined && drawn > 0.001

                // The state mark: filled when the thing is active, hollow when
                // it is merely known, absent otherwise.
                Rectangle {
                    x: Theme.settingsMarkX - width / 2
                    y: (entry.height - height) / 2
                    width: 8
                    height: 8
                    radius: 4
                    color: entry.row && entry.row.marked ? Theme.lineStrong : "transparent"
                    antialiasing: true
                    border.width: Theme.strokeWeight
                    border.color: entry.lit ? Theme.lineStrong : Theme.lineNormal
                    opacity: entry.drawn
                        * (entry.row && (entry.row.marked || entry.row.ring)
                           ? (entry.lit ? Theme.opStrong : Theme.opNormal) : 0)
                    visible: opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                // The sender's picture, where one came with the arrival.
                ClippingRectangle {
                    x: Theme.settingsRowImageX
                    y: (entry.height - height) / 2
                    width: Theme.settingsRowImageSize
                    height: Theme.settingsRowImageSize
                    radius: Theme.settingsRowImageRadius
                    color: "transparent"
                    antialiasing: true
                    border.width: Theme.strokeWeight
                    border.color: entry.lit ? Theme.lineStrong : Theme.lineNormal
                    opacity: entry.drawn * (entry.lit ? 1 : 0.85)
                    visible: entry.row !== undefined && entry.row.image !== ""
                        && opacity > 0.001

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: entry.row ? entry.row.image : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Theme.settingsRowImageSize * 4
                        sourceSize.height: Theme.settingsRowImageSize * 4
                        smooth: true
                        asynchronous: true
                    }
                }

                // Clipped rather than elided: it is written a character at a
                // time, and an elide would rewrite its tail every frame. The
                // box takes the gauge's room on a list that has no levels.
                Item {
                    id: line

                    x: entry.row && entry.row.image !== ""
                        ? Theme.settingsRowImageTextX : Theme.settingsRowTextX
                    y: 0
                    width: body.width - Theme.settingsPadX - Theme.settingsNoteWidth
                        - (entry.row && entry.row.level >= 0
                           ? Theme.settingsGaugeWidth + 12 : 0)
                        - (entry.row && entry.row.closable
                           ? Theme.settingsCloseGutter : 0) - x
                    height: entry.height
                    clip: true

                    TypedText {
                        id: primary
                        y: (entry.height - height) / 2
                        content: entry.row ? entry.row.primary : ""
                        capacity: Theme.settingsRowChars
                        reveal: Theme.panePhase(
                            settings.paneDraw, Theme.drawPaneRow, entry.index)
                        ink: entry.lit || (entry.row && entry.row.marked)
                            ? Theme.textPrimary : Theme.textMuted
                        pixelSize: 11
                        letterSpacing: 0.5
                        opacity: entry.row && entry.row.marked ? 1 : Theme.opStrong
                    }

                    // What it said, after who said it, in the ink of an
                    // annotation: the row is read left to right and stops
                    // wherever it runs out of line.
                    Text {
                        x: primary.width + 10
                        y: (entry.height - height) / 2
                        text: entry.row ? entry.row.sub : ""
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.weight: Font.Light
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                        opacity: Theme.clamp01(Theme.panePhase(
                            settings.paneDraw, Theme.drawPaneRow, entry.index))
                            * (entry.lit ? Theme.opNormal : Theme.opGrid + 0.1)
                        visible: entry.row !== undefined && entry.row.sub !== ""

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // How much of something this row has, on the same instrument
                // the dock uses for charge.
                AxisRule {
                    x: body.width - Theme.settingsPadX - Theme.settingsNoteWidth
                        - Theme.settingsGaugeWidth
                    y: entry.height / 2
                    width: Theme.settingsGaugeWidth
                    divisions: 5
                    draw: entry.drawn
                    reveal: Theme.remap(entry.drawn, 0.45, 1)
                    progress: entry.row ? entry.row.level : 0
                    visible: entry.row !== undefined && entry.row.level >= 0
                }

                // Throws this one away without opening it. Always present on
                // an arrival rather than appearing on hover: a row that grows
                // a button when the pointer arrives is a row you cannot aim at.
                InkIcon {
                    readonly property bool lit:
                        entry.slot >= 0 && settings.hoveredClose === entry.slot

                    x: Theme.settingsCloseX - width / 2
                    y: (entry.height - height) / 2
                    width: Theme.settingsCloseSize
                    height: Theme.settingsCloseSize
                    source: Qt.resolvedUrl("../assets/icons/close.svg")
                    ink: lit ? Theme.lineStrong : Theme.lineNormal
                    reveal: entry.drawn
                    strength: lit ? 1 : entry.lit ? 0.6 : 0.3
                    visible: entry.row !== undefined && entry.row.closable
                }

                Text {
                    x: body.width - Theme.settingsPadX - width
                        - (entry.row && entry.row.closable
                           ? Theme.settingsCloseGutter : 0)
                    y: (entry.height - height) / 2
                    width: Theme.settingsNoteWidth - 8
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: entry.row ? entry.row.note : ""
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.weight: Font.Light
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                    opacity: entry.drawn * (entry.lit ? Theme.opNormal : Theme.opGrid)

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Text {
            x: Theme.settingsRowTextX
            y: Theme.settingsListY + (Theme.settingsListRowHeight - height) / 2
            text: settings.empty
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 9
            font.letterSpacing: 2
            opacity: Theme.opGrid * Theme.clamp01(
                Theme.panePhase(settings.paneDraw, Theme.drawPaneRow, 0))
            visible: settings.page !== 2 && settings.rows.length === 0
                && !settings.prompting && opacity > 0.001
        }

        // ----- the paging column --------------------------------------------
        //
        // A mark to step up, a mark to step down, and a dot per page-worth
        // between them, in the margin at the right. The wheel does the same
        // job, but only for a pointer that has one.

        Item {
            id: paging

            readonly property real reveal: Theme.clamp01(Theme.panePhase(
                settings.paneDraw, Theme.drawPaneRow, 0))
            readonly property int pages: settings.visibleRows > 0
                ? Math.ceil(settings.rows.length / settings.visibleRows) : 0

            x: 0
            y: 0
            width: body.width
            height: body.height
            visible: settings.scrollable && reveal > 0.001

            Chevron {
                readonly property bool lit: settings.hoveredScroll === 0

                span: 9
                drop: 4
                rotation: 180
                transformOrigin: Item.Center
                x: Theme.settingsScrollX - width / 2
                y: Theme.settingsScrollUpY - height / 2
                ink: lit ? Theme.lineStrong : Theme.lineNormal
                opacity: paging.reveal * (settings.first <= 0 ? Theme.opGrid * 0.5
                    : lit ? Theme.opStrong : Theme.opNormal)

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            Chevron {
                readonly property bool lit: settings.hoveredScroll === 1

                span: 9
                drop: 4
                x: Theme.settingsScrollX - width / 2
                y: Theme.settingsScrollDownY - height / 2
                ink: lit ? Theme.lineStrong : Theme.lineNormal
                opacity: paging.reveal
                    * (settings.first >= settings.lastFirst ? Theme.opGrid * 0.5
                       : lit ? Theme.opStrong : Theme.opNormal)

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                model: Math.min(paging.pages, 7)
                delegate: Rectangle {
                    required property int index
                    readonly property int shown:
                        Math.floor(settings.first / settings.visibleRows)

                    x: Theme.settingsScrollX - width / 2
                    y: Theme.settingsScrollUpY + 16 + index * 8
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Theme.lineFaint
                    opacity: paging.reveal
                        * (index === shown ? Theme.opNormal : Theme.opGrid * 0.7)
                }
            }
        }

        // ----- the profile selector -----------------------------------------
        //
        // Three plotted points on one rule: the same mark the clock panel puts
        // at its origin, filled at the reading and hollow elsewhere. A level,
        // drawn, rather than three buttons.

        Item {
            id: profiles

            readonly property real drawn: Theme.pen(
                Theme.panePhase(settings.paneDraw, Theme.drawPaneControl))
            readonly property real third: body.inner / 3

            function markX(index) {
                return Theme.settingsPadX + third * (index + 0.5);
            }

            x: 0
            y: 0
            width: body.width
            height: body.height
            visible: settings.page === 2 && drawn > 0.001

            Rectangle {
                x: profiles.markX(0)
                y: Theme.snap(Theme.settingsSelectorY, Screen.devicePixelRatio)
                width: (profiles.markX(2) - profiles.markX(0)) * profiles.drawn
                height: body.hairline
                color: Theme.lineFaint
                opacity: Theme.opGrid + 0.1
            }

            Repeater {
                model: 3
                delegate: Item {
                    id: mark

                    required property int index
                    readonly property bool current: settings.profile === index
                    readonly property bool lit:
                        current || settings.hoveredControl === index
                    readonly property bool offered: index !== 2
                        || PowerProfiles.hasPerformanceProfile
                    readonly property real reached:
                        Theme.tickReached(profiles.drawn, index / 2)

                    x: profiles.markX(index)
                    y: Theme.settingsSelectorY
                    width: 0
                    height: 0
                    opacity: mark.offered ? 1 : Theme.opFaint
                    visible: mark.reached > 0.001

                    Rectangle {
                        x: -width / 2
                        y: -height / 2
                        width: 9
                        height: 9
                        radius: 4.5
                        color: mark.current ? Theme.lineStrong : "transparent"
                        antialiasing: true
                        border.width: Theme.strokeWeight
                        border.color: mark.lit ? Theme.lineStrong : Theme.lineNormal
                        opacity: mark.reached
                            * (mark.lit ? Theme.opStrong : Theme.opNormal)

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        x: -width / 2
                        y: Theme.settingsSelectorLabelY - Theme.settingsSelectorY
                        text: settings.profileNames[mark.index]
                        color: mark.lit ? Theme.textPrimary : Theme.textMuted
                        font.family: Theme.fontMono
                        font.weight: Font.Light
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        opacity: mark.reached
                            * (mark.current ? Theme.opStrong : Theme.opGrid)

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Text {
                x: Theme.settingsPadX
                y: Theme.settingsSelectorLabelY + 28
                text: PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
                    ? "DEGRADED  LAP DETECTED"
                    : PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature
                    ? "DEGRADED  HIGH TEMPERATURE"
                    : PowerProfiles.hasPerformanceProfile ? "" : "NO PERFORMANCE PROFILE"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 9
                font.letterSpacing: 2
                opacity: Theme.opNormal * Theme.clamp01(
                    Theme.panePhase(settings.paneDraw, Theme.drawPaneDetail))
                visible: text !== "" && opacity > 0.001
            }
        }
    }
}
