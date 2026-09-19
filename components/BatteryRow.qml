import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import "../theme.js" as Theme

// Charge, read as an instrument: the icon says which state, the figure says how
// much, and the gauge plots it on the same kind of axis the menu uses for time.
// The estimate is written above the gauge, where the sketch put it.
Item {
    id: battery

    property real iconReveal: 1
    property real valueReveal: 1
    property real statusReveal: 1
    property real gaugeDraw: 1

    readonly property var device: UPower.displayDevice
    readonly property bool usable: device.isPresent && device.isLaptopBattery
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device.state === UPowerDeviceState.FullyCharged
    readonly property real level: usable ? Theme.clamp01(device.percentage) : 1

    // UPower reports zero while it has no estimate yet, which is not the same
    // as "no time left"; say so rather than printing 0H 00M.
    readonly property int seconds: charging ? device.timeToFull : device.timeToEmpty

    readonly property string valueText: usable
        ? Math.round(level * 100) + "%" : "AC"
    readonly property string statusText: {
        if (!usable)
            return "LINE POWER";
        if (full)
            return "FULLY CHARGED";
        if (seconds <= 0)
            return charging ? "CHARGING" : "ESTIMATING";
        return (charging ? "CHARGING " : "REMAINING ") + duration(seconds);
    }

    readonly property url iconSource: Qt.resolvedUrl("../assets/icons/battery-"
        + (!usable || charging ? "charge"
           : level >= Theme.batteryFullAt ? "full"
           : level >= Theme.batteryMidAt ? "mid" : "low") + ".svg")

    function duration(total: int): string {
        var hours = Math.floor(total / 3600);
        var minutes = Math.floor((total % 3600) / 60);
        return hours + "H " + (minutes < 10 ? "0" : "") + minutes + "M";
    }

    Image {
        id: glyph
        x: Theme.dockPadX
        y: Theme.batteryRowY - Theme.batteryIconSize / 2
        width: Theme.batteryIconSize
        height: Theme.batteryIconSize
        source: battery.iconSource
        sourceSize.width: Theme.batteryIconSize * 4
        sourceSize.height: Theme.batteryIconSize * 4
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: glyph
        source: glyph
        color: Theme.lineNormal
        opacity: Theme.clamp01(battery.iconReveal) * 0.82
        visible: opacity > 0.001
    }

    TypedText {
        x: Theme.dockPadX + Theme.batteryIconSize + 12
        y: Theme.batteryRowY - height / 2
        content: battery.valueText
        capacity: Theme.batteryValueChars
        reveal: battery.valueReveal
        ink: Theme.textPrimary
        pixelSize: 14
        letterSpacing: 1.5
        opacity: Theme.opStrong
        visible: reveal > 0.001
    }

    TypedText {
        x: Theme.batteryGaugeX
        y: Theme.batteryStatusY
        content: battery.statusText
        capacity: Theme.batteryStatusChars
        reveal: battery.statusReveal
        ink: Theme.textMuted
        pixelSize: 9
        letterSpacing: 2
        opacity: Theme.opNormal
        visible: reveal > 0.001
    }

    // Same instrument as the menu's spine, reading charge instead of seconds.
    AxisRule {
        x: Theme.batteryGaugeX
        y: Theme.batteryRowY
        width: battery.width - Theme.batteryGaugeX - Theme.dockPadX
        divisions: 10
        draw: battery.gaugeDraw
        // The level is the reading, so it fills once the rule is under way.
        reveal: Theme.remap(battery.gaugeDraw, 0.45, 1)
        progress: battery.level
    }
}
