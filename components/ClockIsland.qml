import QtQuick
import QtQuick.Shapes
import "../theme.js" as Theme

// The clock panel: the second section, in the same socket as the dock and the
// launcher.
//
// The menu's headline already says what time it is, so this says where that
// time sits. The day is an axis with a marker travelling along it, and the
// month is a grid of week rows plotted one after another with today bracketed
// at the end -- the same instrument the menu uses for seconds and the dock uses
// for charge, read at two longer scales.
//
// Like the launcher it takes the pen driver itself rather than one reveal per
// element, because its stages repeat per row. It starts no animation of its
// own: every reveal is a pure function of `draw`.
Item {
    id: clock

    // 0..1 pen driver for this panel.
    property real draw: 1
    // Minute precision: the calendar. Second precision: the readout and the
    // marker on the day axis.
    property var day: new Date()
    property var live: new Date()

    // Months away from the one `day` falls in. The marks on the month line
    // page it, the wheel pages it, and opening the panel always starts on the
    // current month.
    property int monthOffset: 0
    // Which month control the pointer is on, hit-tested by the bar's single
    // MouseArea: 0 previous, 1 today, 2 next.
    property int hoveredControl: -1

    readonly property var months: ["JANUARY", "FEBRUARY", "MARCH", "APRIL",
        "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER",
        "DECEMBER"]
    readonly property var weekdays: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

    // The first of the shown month. Normalizing through the Date constructor
    // is what makes paging past December work without any arithmetic here.
    readonly property var shown: new Date(day.getFullYear(),
                                          day.getMonth() + monthOffset, 1)

    // Six weeks of cells, Monday first. A fixed count rather than however many
    // the month needs: the island cannot change height between months.
    readonly property var cells: {
        var year = shown.getFullYear();
        var month = shown.getMonth();
        var lead = (shown.getDay() + 6) % 7;
        var out = [];
        for (var i = 0; i < Theme.clockWeeks * Theme.clockColumns; i++) {
            var d = new Date(year, month, 1 - lead + i);
            out.push({
                n: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.getFullYear() === day.getFullYear()
                    && d.getMonth() === day.getMonth()
                    && d.getDate() === day.getDate()
            });
        }
        return out;
    }

    // Seconds elapsed today, as a fraction of the day. What the axis plots.
    readonly property real dayProgress:
        (live.getHours() * 3600 + live.getMinutes() * 60 + live.getSeconds()) / 86400

    readonly property string nowText: "NOW " + Qt.formatDateTime(live, "HH:mm:ss")
    readonly property string stampText: "W" + isoWeek(day) + "  D" + dayOfYear(day)
    readonly property string monthText:
        months[shown.getMonth()] + " " + shown.getFullYear()
    readonly property string offsetText: monthOffset === 0
        ? "" : (monthOffset > 0 ? "+" : "") + monthOffset

    // ISO-8601: weeks start on Monday and week 1 is the one holding January 4th.
    function isoWeek(d) {
        var t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - ((t.getDay() + 6) % 7));
        var first = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(
            ((t.getTime() - first.getTime()) / 86400000
             - 3 + ((first.getDay() + 6) % 7)) / 7);
    }

    function dayOfYear(d) {
        var start = new Date(d.getFullYear(), 0, 1);
        var here = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        return 1 + Math.round((here.getTime() - start.getTime()) / 86400000);
    }

    function reset() {
        monthOffset = 0;
    }

    function page(delta) {
        monthOffset += delta;
    }

    // What the marks on the month line do, in the order they are drawn.
    function control(index) {
        if (index === 0)
            page(-1);
        else if (index === 2)
            page(1);
        else
            reset();
    }

    // Control hit test, in the contents' own coordinates.
    function controlAt(lx, ly) {
        if (Math.abs(ly - Theme.clockControlY) > Theme.clockControlSize / 2)
            return -1;
        for (var i = 0; i < Theme.clockControls; i++) {
            if (Math.abs(lx - Theme.clockControlX(i)) <= Theme.clockControlSize / 2)
                return i;
        }
        return -1;
    }

    clip: true

    // Contents at the island's full size, centred in its animated box, so
    // nothing shifts as the panel necks out and settles.
    Item {
        id: body

        readonly property real hairline: Theme.hairline(Screen.devicePixelRatio)
        readonly property real inner: Theme.clockWidth - Theme.clockPadX * 2

        // Centre of one weekday column.
        function columnX(index) {
            return Theme.clockPadX + inner * (index + 0.5) / Theme.clockColumns;
        }

        x: (clock.width - Theme.clockWidth) / 2
        y: (clock.height - Theme.clockHeight) / 2
        width: Theme.clockWidth
        height: Theme.clockHeight

        // ----- the readout --------------------------------------------------

        TypedText {
            x: Theme.clockPadX
            y: Theme.clockNowY - height / 2
            content: clock.nowText
            capacity: Theme.clockNowChars
            reveal: Theme.clockPhase(clock.draw, Theme.drawClockNow)
            ink: Theme.textPrimary
            pixelSize: Theme.clockNowSize
            letterSpacing: 1.5
            opacity: Theme.opStrong
            visible: reveal > 0.001
        }

        // Where today sits in the week and in the year: the two readings a
        // calendar cannot show by being a calendar.
        TypedText {
            x: body.width - Theme.clockPadX - width
            y: Theme.clockNowY - height / 2
            content: clock.stampText
            capacity: Theme.clockStampChars
            reveal: Theme.clockPhase(clock.draw, Theme.drawClockStamp)
            ink: Theme.textMuted
            pixelSize: 9
            letterSpacing: 2
            opacity: Theme.opNormal
            visible: reveal > 0.001
        }

        // ----- the day ------------------------------------------------------

        AxisRule {
            x: Theme.clockPadX
            y: Theme.clockDayAxisY
            width: body.inner
            divisions: Theme.clockAxisDivisions
            draw: Theme.pen(Theme.clockPhase(clock.draw, Theme.drawClockAxis))
            reveal: Theme.remap(
                Theme.clockPhase(clock.draw, Theme.drawClockAxis), 0.45, 1)
            progress: clock.dayProgress
        }

        // Labels on the major divisions only, which at twelve divisions is
        // every sixth hour.
        Repeater {
            model: 5
            delegate: Text {
                required property int index
                readonly property real reveal:
                    Theme.clockPhase(clock.draw, Theme.drawClockHours)

                x: Theme.clockPadX + body.inner * index / 4 - width / 2
                y: Theme.clockHourLabelY
                text: (index * 6 < 10 ? "0" : "") + (index * 6)
                color: Theme.lineFaint
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 8
                font.letterSpacing: 1.5
                opacity: Theme.opGrid * Theme.clamp01(reveal)
                visible: opacity > 0.001
            }
        }

        // ----- the month ----------------------------------------------------

        TypedText {
            x: Theme.clockPadX
            y: Theme.clockMonthY - height / 2
            content: clock.monthText
            capacity: Theme.clockMonthChars
            reveal: Theme.clockPhase(clock.draw, Theme.drawClockMonth)
            ink: Theme.textMuted
            pixelSize: 10
            letterSpacing: 3
            opacity: Theme.opNormal
            visible: reveal > 0.001
        }

        // How far the calendar has been paged from the month today falls in.
        // Absent while the panel is showing that month, which is where it
        // opens. Sits left of the marks that did the paging.
        Text {
            x: Theme.clockControlX(0) - Theme.clockControlSize / 2 - 8 - width
            y: Theme.clockMonthY - height / 2
            text: clock.offsetText
            color: Theme.lineStrong
            font.family: Theme.fontMono
            font.weight: Font.Light
            font.pixelSize: 9
            font.letterSpacing: 2
            opacity: Theme.opFaint * Theme.clamp01(
                Theme.clockPhase(clock.draw, Theme.drawClockMonth))
            visible: clock.offsetText !== "" && opacity > 0.001
        }

        // ----- month controls -----------------------------------------------
        //
        // Two chevrons and the origin between them. The chevrons are the peek
        // affordance turned on their sides, as the launcher's prompt is; the
        // origin is a plotted point, filled while the calendar is standing on
        // it and hollow once it has been paged away -- which is also when it
        // becomes worth pressing.

        Repeater {
            model: 2
            delegate: Chevron {
                required property int index
                readonly property bool lit: clock.hoveredControl === index * 2

                span: 9
                drop: 4
                // index 0 points back, index 1 points forward.
                rotation: index === 0 ? 90 : -90
                transformOrigin: Item.Center
                x: Theme.clockControlX(index * 2) - width / 2
                y: Theme.clockControlY - height / 2
                ink: lit ? Theme.lineStrong : Theme.lineNormal
                opacity: lit ? Theme.opStrong : Theme.opNormal
                progress: Theme.pen(
                    Theme.clockPhase(clock.draw, Theme.drawClockMonth))
                visible: progress > 0.001

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            readonly property bool lit: clock.hoveredControl === 1
            readonly property real reveal:
                Theme.clockPhase(clock.draw, Theme.drawClockMonth)

            x: Theme.clockControlX(1) - width / 2
            y: Theme.clockControlY - height / 2
            width: 7
            height: 7
            radius: 3.5
            // Filled at the origin, hollow away from it.
            color: clock.monthOffset === 0 ? Theme.lineStrong : "transparent"
            antialiasing: true
            border.width: Theme.strokeWeight
            border.color: lit ? Theme.lineStrong : Theme.lineNormal
            opacity: Theme.clamp01(reveal)
                * (lit ? Theme.opStrong : Theme.opNormal)
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Repeater {
            model: Theme.clockColumns
            delegate: Text {
                required property int index
                readonly property real reveal:
                    Theme.clockPhase(clock.draw, Theme.drawClockWeekdays)

                x: body.columnX(index) - width / 2
                y: Theme.clockWeekdayY - height / 2
                text: clock.weekdays[index]
                color: Theme.lineFaint
                font.family: Theme.fontMono
                font.weight: Font.Light
                font.pixelSize: 8
                font.letterSpacing: 1.5
                opacity: Theme.opGrid * Theme.clamp01(reveal)
                visible: opacity > 0.001
            }
        }

        // The grid's own axis, drawn under the captions as the weeks are
        // about to be plotted.
        Rectangle {
            readonly property real drawn: Theme.pen(
                Theme.clockPhase(clock.draw, Theme.drawClockWeekdays))

            x: Theme.clockPadX
            y: Theme.snap(Theme.clockGridY - 4, Screen.devicePixelRatio)
            width: body.inner * drawn
            height: body.hairline
            color: Theme.lineFaint
            opacity: Theme.opGrid + 0.08
            visible: drawn > 0.001
        }

        // One week per row, plotted top to bottom: a baseline drawn left to
        // right and the dates resolving over it as it passes.
        Repeater {
            model: Theme.clockWeeks
            delegate: Item {
                id: week

                required property int index
                readonly property real drawn: Theme.pen(
                    Theme.clockPhase(clock.draw, Theme.drawClockRow, index))

                x: 0
                y: Theme.clockGridY + index * Theme.clockRowHeight
                width: body.width
                height: Theme.clockRowHeight
                visible: drawn > 0.001

                Rectangle {
                    x: Theme.clockPadX
                    y: Theme.snap(week.height - 1, Screen.devicePixelRatio)
                    width: body.inner * week.drawn
                    height: body.hairline
                    color: Theme.lineFaint
                    opacity: Theme.opGrid * 0.5
                }

                Repeater {
                    model: Theme.clockColumns
                    delegate: Text {
                        required property int index
                        readonly property var cell:
                            clock.cells[week.index * Theme.clockColumns + index]

                        x: body.columnX(index) - width / 2
                        y: (week.height - height) / 2 - 1
                        text: cell ? cell.n : ""
                        color: cell && cell.today ? Theme.textPrimary
                            : cell && cell.inMonth ? Theme.textMuted : Theme.lineFaint
                        font.family: Theme.fontMono
                        font.weight: Font.Light
                        font.pixelSize: 11
                        font.letterSpacing: 0.5
                        // Days spilling in from the neighbouring months are
                        // kept, not blanked: the grid reads as a window onto a
                        // continuous year rather than as a box of one month.
                        opacity: week.drawn
                            * (!cell ? 0 : cell.inMonth ? Theme.opStrong : Theme.opGrid)
                    }
                }
            }
        }

        // Today, bracketed rather than filled -- the same answer the launcher's
        // rail gives, and drawn last, once the grid it refers to exists.
        Repeater {
            model: Theme.clockWeeks * Theme.clockColumns
            delegate: Shape {
                id: bracket

                required property int index
                readonly property var cell: clock.cells[index]
                readonly property real drawn: Theme.pen(
                    Theme.clockPhase(clock.draw, Theme.drawClockToday))

                x: body.columnX(index % Theme.clockColumns) - Theme.clockCellWidth / 2
                y: Theme.clockGridY
                    + Math.floor(index / Theme.clockColumns) * Theme.clockRowHeight
                    + (Theme.clockRowHeight - Theme.clockCellHeight) / 2 - 1
                width: Theme.clockCellWidth
                height: Theme.clockCellHeight
                preferredRendererType: Shape.CurveRenderer
                opacity: Theme.opNormal
                visible: cell !== undefined && cell.today && drawn > 0.001

                ShapePath {
                    strokeColor: Theme.lineStrong
                    strokeWidth: Theme.strokeWeight
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: Theme.roundedRectPath(
                            Theme.clockCellWidth, Theme.clockCellHeight,
                            Theme.clockCellRadius, bracket.drawn)
                    }
                }
            }
        }
    }
}
