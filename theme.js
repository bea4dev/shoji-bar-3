.pragma library

// shoji-bar-3 design tokens.
// Dynamic Island silhouette + ShojiWM liquid glass + line-drawn instrumentation.
// All geometry is in logical pixels of the layer surface.

// ---------------------------------------------------------------------------
// Placement inside the single layer surface
// ---------------------------------------------------------------------------

// Gap between the screen's top edge and the silhouette.
var screenPad = 6;
// Slack kept around the silhouette inside the surface: antialiasing plus the
// outward bulge of the smooth-minimum blend when shapes merge.
var surfacePad = 40;

// ---------------------------------------------------------------------------
// Silhouette geometry per state
// ---------------------------------------------------------------------------

var barWidth = 152;
var barHeight = 34;
var barRadius = 17;

// How much of the screen the bar reserves for itself through the layer shell,
// measured down from the top edge. Only the resting pill and its padding: the
// menu and everything it opens are meant to overlap windows rather than push
// them down, so none of that is counted here.
//
// `exclusiveZonePad` is the knob. Positive keeps windows further away than the
// pill needs, negative lets them come closer -- far enough negative and they
// pass under it. Zero is the pill plus its own padding, top and bottom.
//
// Declared here rather than beside `screenPad`, because it reads `barHeight`:
// this file is a `.pragma library`, where anything written above its own
// inputs quietly evaluates to NaN.
var exclusiveZonePad = -8;
var exclusiveZone = screenPad * 2 + barHeight + exclusiveZonePad;

var peekWidth = 236;
var peekHeight = 48;
var peekRadius = 24;

var menuWidth = 424;
var menuHeight = 244;
var menuRadius = 34;

// Joining band for LiquidGroup's smooth minimum. Section panels growing out of
// the menu use this to form the neck.
var blendRadius = 40;


// ---------------------------------------------------------------------------
// Main menu content layout, relative to the silhouette's top-left corner
// ---------------------------------------------------------------------------

// Column centres as a fraction of the silhouette width, shared by the peek
// chevrons and the menu tiles so the two states line up during the morph.
var columns = [0.2, 0.4, 0.6, 0.8];

var clockCenterCollapsed = 14;
var clockCenterPeek = 17;
var clockCenterMenu = 60;

var clockSizeCollapsed = 15;
var clockSizePeek = 16;
var clockSizeMenu = 46;

var chevronCenterY = 35;
var chevronSpan = 13;
var chevronDrop = 5;

var dateY = 92;
var axisY = 120;
var axisInset = 40;
var tileY = 142;
var tileSize = 64;
var tileRadius = 18;
var iconSize = 24;
var labelY = 212;

// ---------------------------------------------------------------------------
// Dock island: the second shape, below the menu
// ---------------------------------------------------------------------------

// Clearance between the two islands. The smooth minimum reaches `blendRadius`
// from each surface, so a gap much below that leaves the pair visibly bridged
// instead of separated.
var dockGap = 32;
var dockWidth = 396;
var dockHeight = 116;
var dockRadius = 30;
var dockPadX = 18;

// Battery row, in dock-local coordinates.
var batteryIconSize = 20;
var batteryRowY = 30;
var batteryGaugeX = 122;
var batteryStatusY = 9;
// Charge fractions at which the icon changes. Charging overrides both.
var batteryFullAt = 0.65;
var batteryMidAt = 0.3;

// Tray row.
var trayFrameY = 54;
var trayFrameHeight = 46;
var trayFrameRadius = 16;
var trayIconSize = 20;
var trayIconGap = 16;
// Third-party tray icons are the one thing here not drawn in our own ink.
// 0 keeps them exactly as their applications authored them; 1 renders them as
// line work like everything else, at the cost of telling them apart.
var trayDesaturate = 0.0;

// ---------------------------------------------------------------------------
// Power island: the fourth section panel
// ---------------------------------------------------------------------------
//
// Three ways to end the session, as three of the menu's own tiles at a larger
// size. A frame that is drawn rather than an icon that merely appears is what
// gives the panel something to animate, and it is the vocabulary the menu
// already uses one island up.
var powerWidth = dockWidth;
var powerRadius = dockRadius;
var powerPadX = 24;
var powerPadTop = 20;
var powerPadBottom = 22;

// The rule the tiles hang from, as in the menu.
var powerAxisY = powerPadTop + 8;
var powerTileY = powerAxisY + 26;
var powerTileSize = 72;
var powerTileRadius = 20;
var powerIconSize = 28;
var powerLabelGap = 18;
var powerColumns = [0.2, 0.5, 0.8];
// Longest caption, including the one an armed tile shows.
var powerLabelChars = 11;

var powerLabelY = powerTileY + powerTileSize + powerLabelGap;
var powerHeight = powerLabelY + 14 + powerPadBottom;

// What each tile does. Written here so the commands are one line to change,
// and so nothing in the QML has to know how a session ends on this machine.
var powerActions = [
    { label: "POWER OFF", icon: "power", command: ["systemctl", "poweroff"] },
    { label: "RESTART", icon: "restart", command: ["systemctl", "reboot"] },
    { label: "LOG OUT", icon: "logout",
      command: ["sh", "-c", "loginctl terminate-session \"${XDG_SESSION_ID:-self}\""] }
];

// Ending a session is not something to do on a slipped click: the first press
// arms a tile and the second one carries it out. This is what an armed tile
// says instead of its name.
var powerArmedLabel = "PRESS AGAIN";

// Centre of one tile, from the island's left edge.
function powerTileX(index) {
    return powerColumns[index] * powerWidth;
}

// ---------------------------------------------------------------------------
// Media island: the dock's second half, below it
// ---------------------------------------------------------------------------
//
// Not a section panel: it arrives and leaves with the dock, as one thing in
// two boxes. The dock reads what the machine is doing to itself -- charge,
// tray -- and this reads what it is doing for you: how loud, how bright, what
// is playing.
var mediaWidth = dockWidth;
var mediaRadius = dockRadius;
var mediaPadX = 20;
var mediaPadTop = 16;
var mediaPadBottom = 16;

// Two instrument rows, each an icon, a slider, a reading and the device the
// row is driving.
var mediaRows = 2;
var mediaRowHeight = 28;
var mediaIconSize = 18;
var mediaIconX = mediaPadX + 9;
var mediaSliderX = mediaPadX + 30;
var mediaSliderWidth = 160;
var mediaValueWidth = 34;
var mediaDeviceWidth = 104;
var mediaDeviceChars = 14;

var mediaRuleY = mediaPadTop + mediaRows * mediaRowHeight + 8;

// What is playing. The cover is the one picture in the bar besides an
// arrival's sender, and it earns its place the same way.
var mediaArtY = mediaRuleY + 10;
var mediaArtSize = 56;
var mediaArtRadius = 12;
var mediaTextX = mediaPadX + mediaArtSize + 14;
var mediaTitleY = mediaArtY + 4;
var mediaArtistY = mediaTitleY + 18;
var mediaSeekY = mediaArtY + mediaArtSize - 8;
var mediaTitleChars = 22;
var mediaArtistChars = 24;

// Previous, play/pause, next.
var mediaControls = 3;
var mediaControlSize = 16;
var mediaControlStep = 26;
var mediaControlY = mediaTitleY + 10;
var mediaControlInset = mediaPadX + 8;

var mediaHeight = mediaSeekY + 22 + mediaPadBottom;

// Centre of one transport control, from the island's left edge.
function mediaControlX(index) {
    return mediaWidth - mediaControlInset
        - (mediaControls - 1 - index) * mediaControlStep;
}

// Centre line of one instrument row.
function mediaRowY(index) {
    return mediaPadTop + index * mediaRowHeight + mediaRowHeight / 2;
}

// ---------------------------------------------------------------------------
// Launcher island: the first section panel, shown in the dock's place
// ---------------------------------------------------------------------------
//
// Same width and corner as the dock island, because the two trade places in
// the same socket under the menu: a change of outline there would read as the
// bar rebuilding itself rather than as one drawer replacing another. Only the
// height differs, and the surface is sized for whichever island is taller.
var launcherWidth = dockWidth;
var launcherRadius = dockRadius;

// The panel's margins. Everything inside is placed off these rather than
// written down independently, so widening the margin moves the contents with
// it instead of merely clipping them closer to the edge.
var launcherPadX = 24;
var launcherPadTop = 22;
var launcherPadBottom = 22;

// Query row, in launcher-local coordinates.
//
// The chip at the left says which corpus the field is searching and is also
// the switch between them: applications, or the clipboard's history. One chip
// rather than a pair of tabs, because there are two of them and a switch that
// shows its own state costs no width.
var launcherModes = ["APPS", "CLIP"];
var launcherAppMode = 0;
var launcherClipMode = 1;
var launcherModeChars = 4;
var launcherModeX = launcherPadX;
var launcherModeWidth = 34;

var launcherPromptX = launcherModeX + launcherModeWidth + 10;
var launcherQueryX = launcherPromptX + 14;
var launcherQueryY = launcherPadTop + 8;
var launcherQuerySize = 13;
var launcherAxisY = launcherQueryY + 22;

// Results hang off a vertical rail the way samples hang off an axis: the rail
// is drawn once, and each row is a tick branching out of it.
var launcherRowsY = launcherAxisY + 22;
var launcherRowHeight = 36;
var launcherRows = 7;
var launcherRailX = launcherPadX + 18;
var launcherBranch = 10;
var launcherIconX = launcherPadX + 36;
var launcherIconSize = 20;

// A copied picture, shown as itself. Wider than it is tall, because most of
// what lands on a clipboard is a screenshot.
var launcherThumbX = launcherIconX - 2;
var launcherThumbWidth = 34;
var launcherThumbHeight = 24;
var launcherThumbRadius = 5;
// Where a row's text starts when a picture is standing in front of it.
var launcherThumbTextX = launcherThumbX + launcherThumbWidth + 10;
var launcherNameX = launcherPadX + 66;
// Width reserved at the right for the row's annotation, measured from the
// island's inner edge.
var launcherNoteWidth = 92;

// Characters each text stage is sized for. A shorter string is written at the
// same rate and then waits, rather than being stretched to fill its window.
var launcherIndexChars = 2;
var launcherCountChars = 11;
var launcherNameChars = 16;

// As with the tray, third-party icons are the one thing here not drawn in our
// own ink. 0 leaves them as their applications authored them; 1 renders them
// as line work, at the cost of telling them apart.
var launcherDesaturate = 0.0;

// Derived: the rows block, and the island that has to hold it.
var launcherRowsHeight = launcherRows * launcherRowHeight;
var launcherHeight = launcherRowsY + launcherRowsHeight + launcherPadBottom;

// ---------------------------------------------------------------------------
// Clock island: the second section panel, in the same socket
// ---------------------------------------------------------------------------
//
// The menu's headline already says what time it is. This panel says where that
// time sits: the day plotted as an axis with a marker on it, and the month
// plotted as a grid with today bracketed. Same width and corner as the others,
// because every island in the socket is the same drawer.
var clockWidth = dockWidth;
var clockRadius = dockRadius;

var clockPadX = 24;
var clockPadTop = 22;
var clockPadBottom = 22;

// Live readout and its annotations, in clock-local coordinates.
var clockNowY = clockPadTop + 8;
var clockNowSize = 15;

// The day, 0..24, on the same rule the menu uses for seconds.
var clockDayAxisY = clockNowY + 26;
var clockHourLabelY = clockDayAxisY + 10;
var clockAxisDivisions = 12;

// The month, as a grid. Six week rows is the most any month needs once the
// weeks start on Monday, and a fixed count keeps the island from resizing
// between months.
var clockMonthY = clockHourLabelY + 34;
var clockWeekdayY = clockMonthY + 22;
var clockGridY = clockWeekdayY + 12;
var clockRowHeight = 26;
var clockWeeks = 6;
var clockColumns = 7;
// Today is bracketed, not filled -- the same answer the launcher's rail gives.
var clockCellRadius = 8;
var clockCellWidth = 30;
var clockCellHeight = 22;

var clockNowChars = 12;
var clockStampChars = 10;
var clockMonthChars = 14;

// Month controls: previous, today, next, in a row at the right of the month
// line. Their hit boxes are square and centred on each mark, and the marks are
// spaced far enough apart that the boxes do not touch.
var clockControls = 3;
var clockControlSize = 22;
var clockControlStep = 26;
// Centre of the last mark, measured in from the island's right edge.
var clockControlInset = clockPadX + 7;
var clockControlY = clockMonthY;

// Centre of one control, from the island's left edge.
function clockControlX(index) {
    return clockWidth - clockControlInset
        - (clockControls - 1 - index) * clockControlStep;
}

var clockGridHeight = clockWeeks * clockRowHeight;
var clockHeight = clockGridY + clockGridHeight + clockPadBottom;

// ---------------------------------------------------------------------------
// Settings island: the third section panel, in the same socket
// ---------------------------------------------------------------------------
//
// Four sections along the top and one pane below them. The tabs are the menu's
// own row of tiles at a smaller scale, and each tab's icon is the setting's
// state indicator as well as its name: the row says what is on without the
// pane having to be opened.
var settingsWidth = dockWidth;
var settingsRadius = dockRadius;

var settingsPadX = 24;
var settingsPadTop = 22;
var settingsPadBottom = 22;

var settingsTabs = 5;
var settingsTabIconSize = 20;
var settingsTabIconY = settingsPadTop + 11;
var settingsTabLabelY = settingsTabIconY + 20;
// The rule the tabs stand on, and the tick that ties the chosen one to the
// pane -- the menu's drop lines, pointing the other way.
var settingsRuleY = settingsTabLabelY + 16;
var settingsDropLen = 12;
// Longest caption, so every tab is written at the same rate.
var settingsTabChars = 9;

// The pane: one header line, then a list. Every section that has more than a
// switch has a list of things to act on -- networks, devices, arrivals -- so
// the pane is that shape once and each section fills it.
var settingsPaneY = settingsRuleY + 14;
var settingsRowHeight = 30;
var settingsTitleChars = 14;
var settingsDetailChars = 24;

var settingsListY = settingsPaneY + settingsRowHeight + 8;
var settingsListRows = 6;
var settingsListRowHeight = 30;

// Inside one list row: a state mark, an optional image, the name, an optional
// level, a note. An arrival that carries a picture of its sender is the only
// thing here that is not line work, and it earns its place: a Discord message
// is its avatar long before it is its text.
var settingsMarkX = settingsPadX + 5;
var settingsRowTextX = settingsPadX + 20;
var settingsRowImageX = settingsPadX + 20;
var settingsRowImageSize = 20;
var settingsRowImageRadius = 5;
var settingsRowImageTextX = settingsRowImageX + settingsRowImageSize + 10;

// The mark that throws one arrival away, at the end of its own row, and the
// room it takes from the note beside it.
var settingsCloseSize = 12;
// Kept clear of the paging column beside it: the two hit boxes must not
// overlap, or aiming at one row's dismiss mark would page the list instead.
var settingsCloseHit = 18;
var settingsCloseX = settingsWidth - settingsPadX - 4 - settingsCloseSize / 2;
var settingsCloseGutter = settingsCloseSize + 16;

// The list's paging column, in the margin at the right: a mark to step up, a
// mark to step down, and a dot per page-worth between them. A wheel does the
// same job, but only for a pointer that has one.
var settingsScrollX = settingsWidth - 13;
var settingsScrollHit = 16;
var settingsGaugeWidth = 56;
var settingsNoteWidth = 78;
var settingsRowChars = 22;

// The power section has no list; its three marks sit where one would start.
var settingsSelectorY = settingsListY + 26;
var settingsSelectorLabelY = settingsSelectorY + 12;

function settingsListRowY(index) {
    return settingsListY + index * settingsListRowHeight;
}

var settingsListHeight = settingsListRows * settingsListRowHeight;
var settingsScrollUpY = settingsListY + 13;
var settingsScrollDownY = settingsListY + settingsListHeight - 13;

// The section shown when the panel opens, and the one that has no switch of
// its own besides the power selector.
var settingsNotifyPage = 3;
var settingsWallPage = 4;

// ---------------------------------------------------------------------------
// Wallpaper
// ---------------------------------------------------------------------------
//
// Relative to the home directory, because a `.pragma library` has no way to
// ask what that is. The first of the two that has pictures in it is the
// default; the stored state overrides both.
var wallpaperDir = "Pictures/wallpaper";
var wallpaperDirAlt = "Pictures/wallpapers";
var wallpaperTypes = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif",
                      "*.bmp", "*.jxl"];
// What shows through where a picture does not cover the output, and between
// two pictures while they trade places.
var wallpaperGround = "#0b0f16";
var wallpaperFadeMs = 420;

// A switch, drawn: a stadium with a plotted point in it.
var switchWidth = 34;
var switchHeight = 16;
var switchKnob = 4.5;
var switchInset = 8;

// Centre of one tab, and top of one pane row, from the island's left/top.
function settingsTabX(index) {
    return settingsPadX + (settingsWidth - settingsPadX * 2)
        * (index + 0.5) / settingsTabs;
}

var settingsHeight = settingsListY + settingsListRows * settingsListRowHeight
    + settingsPadBottom;

// ---------------------------------------------------------------------------
// Toast island: an arriving notification, in the same socket
// ---------------------------------------------------------------------------
//
// A notification is not a section, but it belongs in the same place: it is
// extruded out of the resting pill the way a panel is extruded out of the
// menu, which is the whole point of a bar shaped like this. It is narrower
// than the panels because it comes out of the pill rather than out of the
// menu, and it only ever appears while the menu is closed -- with the menu
// open the socket is already spoken for, and the notification is one row of a
// list the settings panel is showing anyway.
var toastWidth = 360;
var toastRadius = 26;
var toastPadX = 20;
var toastPadTop = 16;
var toastPadBottom = 16;

var toastHeaderY = toastPadTop + 6;
var toastRuleY = toastHeaderY + 14;

// Below the rule: the sender's picture, if it sent one, and what it said.
var toastContentY = toastRuleY + 12;
var toastImageSize = 40;
var toastImageRadius = 10;
var toastTextGap = 12;
var toastSummaryHeight = 16;
var toastBodyLines = 2;
var toastBodyLeading = 14;
var toastContentHeight = Math.max(
    toastImageSize, toastSummaryHeight + 2 + toastBodyLines * toastBodyLeading);

var toastAppChars = 14;
var toastTimeChars = 5;
var toastSummaryChars = 26;

// How long a toast is held when the sender does not say. A sender that does
// say is obeyed; a critical one is never taken away on a timer.
var toastHoldMs = 5200;

var toastHeight = toastContentY + toastContentHeight + toastPadBottom;

// Context menu, drawn in the same vocabulary as the bar. It is a popup, not
// part of the layer, so the compositor's island glass does not reach it and it
// has to carry its own ground. Its alpha must also clear ShojiWM's popup-blur
// `opacity_threshold` (0.25), or that blur is clipped away too and the menu
// ends up as bare text over whatever is behind it.
// The ground the popup carries. `menuOpacity` is the knob; it must stay above
// ShojiWM's popup-blur threshold or that blur is clipped away as well.
var menuOpacity = 0.3;
var menuTint = withAlpha("121a26", menuOpacity);
var menuItemHeight = 26;
// Shared by the rows and by the measurement that sizes the popup, so the two
// cannot disagree about how wide a string is.
var menuItemFontSize = 11;
var menuItemTracking = 0.5;
var menuItemPadX = 14;
var menuMinWidth = 180;
var menuMaxWidth = 340;
var menuRadiusPopup = 14;

// Declared here because it measures both islands: a `var` read before its
// assignment is undefined, and the arithmetic would silently yield NaN.
//
// The layer surface is one fixed size, large enough for the widest silhouette
// it will ever show, and is never resized. A layer-shell reconfigure moves a
// top-anchored surface horizontally, because the compositor re-centres it on
// the output; that move and the client redraw compensating for it do not land
// on the same frame, so a resize reads as a one-frame jump of half the delta.
// Growing this costs compositor work: the glass pipeline runs over the whole
// layer rect, so a section panel should extend the height no further than the
// panel actually needs.
var surfaceWidth = menuWidth + surfacePad * 2;
// Sized for the taller of the two lower islands, since they share the socket
// and the surface itself is never resized.
// The dock occupies the socket as a pair: itself, a gap, and the media island
// under it.
var dockPairHeight = dockHeight + dockGap + mediaHeight;
var lowerIslandHeight = Math.max(dockPairHeight, launcherHeight, clockHeight,
                                 settingsHeight, powerHeight);
// An arrival appears below whatever the socket is showing, never instead of
// it, so the surface has to hold the tallest panel and a toast underneath it.
var surfaceHeight = screenPad + menuHeight + dockGap + lowerIslandHeight
    + dockGap + toastHeight + surfacePad;

// ---------------------------------------------------------------------------
// Material
// ---------------------------------------------------------------------------

// The alpha of `tint` MUST match ISLAND_GLASS_OPTIONS.surfaceOpacity in
// ~/.config/shojiwm/src/island-glass.ts (currently 0.20 == 0x33). The
// compositor recovers geometric coverage as alpha / surfaceOpacity; a mismatch
// breaks the silhouette the glass is clipped to.
var surfaceOpacity = 0.2;
// Derived, not restated: the two can no longer drift apart.
var tint = withAlpha("1a2433", surfaceOpacity);

// ---------------------------------------------------------------------------
// Ink: everything is drawn as thin strokes and sparse type.
// ---------------------------------------------------------------------------

var textPrimary = "#ffffff";
var textMuted = "#e9eced";

var lineStrong = "#ffffff";
var lineNormal = "#e8e2e8";
var lineFaint = "#efe8ed";

var opStrong = 0.92;
var opNormal = 0.55;
// The instrument lines have to be visible enough that watching them get drawn
// is worth the time it takes. Below roughly a quarter they read as absent on a
// bright backdrop, and the drawing reads as a pop.
var opFaint = 0.42;
var opGrid = 0.27;

// Nominal stroke weight in logical pixels. Straight runs snap this to whole
// device pixels; curves keep it fractional and let the curve renderer's
// analytic coverage do the work.
var strokeWeight = 1.0;
var strokeWeightHover = 1.5;

var fontMono = "Noto Sans Mono";

// ---------------------------------------------------------------------------
// Motion: the silhouette
// ---------------------------------------------------------------------------

// Two control points plus the required (1, 1) endpoint, for Easing.BezierSpline.
// cubicBezier(0.1, 0.9, 0.2, 1.0): leaves at roughly nine times the average
// speed and arrives at zero. The silhouette commits immediately and then only
// settles, which is what keeps a large shape from reading as heavy.
var easeOut = [0.1, 0.9, 0.2, 1.0, 1.0, 1.0];

// An alternative for `dockCurve` below, kept because the trade-off is not
// obvious. `easeOut` resolves 96% of a shape in the first eighth of its
// duration, and the neck only exists while `dock` is inside a band partway up
// the range, so the stretch is over in a few tens of milliseconds whatever
// `dockEmergeMs` says — the extrusion reads as a snap. This curve sustains
// through the middle and spends its time where the motion is, at the cost of
// no longer matching everything else.
var easeSustained = [0.35, 0.0, 0.25, 1.0, 1.0, 1.0];

// Each island runs its own animation, one after the other, rather than one
// curve stretched across both. Assign `easeSustained` here to trade the lower
// island's snap for a visible stretch.
//
// Every curve this can be set to is declared ABOVE it. This file is a
// `.pragma library`: `var` hoists the name but not the assignment, so a
// reference to something declared further down silently evaluates to
// `undefined`, and an undefined bezierCurve disables the easing without any
// error. The check at the end of the file catches that class of mistake.
var dockCurve = easeOut;

// One number for the speed of every silhouette, the counterpart of `drawTempo`
// for the pen. 1.0 is the durations as written below; 0.5 halves all of them.
// Everything derived from them follows, including the point at which the pen's
// schedule believes the lower island starts moving.
var shapeTempo = 1.0;

function shapeMs(ms) {
    return Math.round(ms * shapeTempo);
}

// A front-loaded curve spends most of its duration on an almost invisible
// tail, so these stay short; length here reads as sluggish, not as grace.
var durPeek = shapeMs(300);
var durMenu = shapeMs(440);

// The lower island is a silhouette, so it is timed here with the others and on
// the same curve, not on the pen's clock.
var dockEmergeMs = shapeMs(560);
var dockRetractMs = shapeMs(340);

// How far the two islands' animations are allowed to run together.
//
// Zero is strictly serial: the island is extruded only once the menu's own
// animation has finished, and absorbed completely before the menu starts to
// collapse. A positive value pulls the second animation that many milliseconds
// earlier, so the two overlap for that long; `dockOverlapMs = durMenu` starts
// both at the same instant. A negative value pushes it later and leaves a gap.
var dockOverlapMs = shapeMs(250);
// Closing takes the same overlap unless it is given its own.
var dockCloseOverlapMs = dockOverlapMs;

// Derived: when the second animation of each transition starts, measured from
// the beginning of that transition. Clamped, because neither can start before
// the transition itself does.
var dockStartMs = Math.max(0, durMenu - dockOverlapMs);
var menuCloseStartMs = Math.max(0, dockRetractMs - dockCloseOverlapMs);

// How far inside the menu the island is born. It has to overlap, not merely
// touch: two shapes that only meet at an edge give the smooth minimum nothing
// to bridge, and the pair separates without ever forming a neck.
var dockEmergeDepth = 16;

// Delay before an unhovered menu collapses, so crossing a gap does not close it.
var closeGraceMs = 260;
// The launcher is the one state where the pointer is not the input, so the
// grace is longer there: a bump of the mouse should not take a half-typed
// query with it.
var launcherGraceMs = 1400;

// ---------------------------------------------------------------------------
// Motion: the pen
// ---------------------------------------------------------------------------
//
// Drawing runs on its own linear driver rather than on the eased silhouette
// value. Under `easeOut` the silhouette is 96% resolved at 12% of its duration,
// so a schedule keyed to it would fire every stage inside the first few frames.
// Linear time is what a pen actually moves in.
//
// TUNING. The schedule below is written in milliseconds, and everything else
// is derived from it: the driver's duration, the normalized windows each
// element reads, and the total. Change a number and the rest follows.
//
//   drawTempo          scales the whole schedule without changing its shape
//   drawLeadInMs       dead time before the first stroke
//   drawColumnStepMs   how far each column trails the one to its left
//   typeCharMs         how fast text is written, per character
//   <stage>.at         when that stroke starts, from the top of the schedule
//   <stage>.ms         how long that stroke takes
//   <stage>.stagger    whether the stage repeats per column

// One number to make the whole thing faster or slower. 1.0 is the schedule as
// written below; 0.5 halves every delay and duration in it.
var drawTempo = 0.4;

// Dead time before the first stroke, so the silhouette lands before anything
// starts being drawn into it. Every stage's `at` is measured after this, and it
// extends the schedule rather than eating into it. Raise it if the opening
// beats go by before the eye has arrived.
var drawLeadInMs = 250;

// Each column starts this much after the one to its left.
var drawColumnStepMs = 150;

// Milliseconds spent writing one character. This is the whole speed control for
// text: every text stage takes its duration from this and the number of
// characters it has to write, so a long readout takes longer than a short one
// and all of them are written at the same rate. Text reveals linearly rather
// than through `pen`, so this figure is the real rate and not an average.
var typeCharMs = 34;

// How much each text stage has to write. The date format is fixed; the caption
// stage is sized by the longest section name, so a shorter caption finishes
// early and waits instead of being written slower to fill the window.
var dateChars = 15;
var labelChars = 8;

function typeMs(chars) {
    return Math.round(chars * typeCharMs);
}

// Top to bottom, which is also the order the eye reads the menu in. The date
// sits above the axis, so it is written before the axis is drawn: running them
// together means a 10px muted readout types itself while a rule sweeps the full
// width of the menu underneath it, and only the rule is seen.
var drawDate = { at: 0, ms: typeMs(dateChars) };
var drawAxis = { at: 380, ms: 660 };
var drawDrop = { at: 780, ms: 320, stagger: true };
var drawFrame = { at: 940, ms: 640, stagger: true };
var drawSweep = { at: 1320, ms: 340 };

// The glyph is not pen work: it only fades, and it finishes exactly as its own
// frame closes. Anchoring it to the end of `drawFrame` rather than to a time of
// its own keeps the two in step whenever the frame's timing is retuned, per
// column, because both carry the same stagger.
var drawGlyphMs = 300;
var drawGlyph = {
    at: drawFrame.at + drawFrame.ms - drawGlyphMs,
    ms: drawGlyphMs,
    stagger: true
};

// ----- the dock island's contents -------------------------------------------
//
// How much the dock's own text stages have to write. The stages themselves are
// further down, with the other islands': the dock is drawn on its own driver
// like every one of them.
var batteryValueChars = 4;
var batteryStatusChars = 17;

// The caption is written once the frame that holds it is closed.
var drawLabel = {
    at: drawFrame.at + drawFrame.ms + 20,
    ms: typeMs(labelChars),
    stagger: true
};

// ---------------------------------------------------------------------------
// Motion: the peek
// ---------------------------------------------------------------------------
//
// Hover has its own little schedule on its own driver, independent of both the
// silhouette and the menu, because it is a different gesture with a different
// budget: one stroke, answered immediately, on a bar the pointer merely
// brushed. The pill's resting indicator is erased, and then the chevron is
// drawn; the lead-in is the pause between the two.

// Dead time after the hover lands, before the chevron starts being drawn.
var drawPeekLeadInMs = 0;
// How long the chevron stroke itself takes.
var drawPeekMs = 300;
// How long the minute indicator takes to be erased on the way in.
var drawMinuteMs = 220;

// How long the menu takes to erase the chevron once it commits. Measured on the
// menu driver, not this one, because it answers the click rather than the hover.
var drawChevronClearMs = 260;

var peekScheduleMs = Math.max(drawMinuteMs, drawPeekLeadInMs + drawPeekMs);

// Erasing is not drawing played backwards at the same speed. Ink leaves with
// the mass that carried it, and the mass leaves in `durMenu`, so the return
// trip is a small fraction of the schedule rather than a reversal of it.
var drawUndrawRatio = 0.18;

// How much of the rule's own progress a tick takes to resolve once the rule
// reaches it. Relative to the rule, not to the clock, because the rule is what
// is doing the drawing.
var tickLead = 0.07;

// How far a mark sitting at `pos` along a stroke has resolved, given how much
// of the stroke is drawn. The positions are scaled by (1 - tickLead) so the
// mark at the very end still completes: keyed to `pos` alone its window would
// run past the end of the stroke, and the last tick of every axis would sit at
// zero forever.
function tickReached(draw, pos) {
    return clamp01((draw - pos * (1 - tickLead)) / tickLead);
}

// When a stage starts, after the lead-in and its own column's trail.
function stageStart(stage, index) {
    return drawLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * drawColumnStepMs : 0);
}

// When a stage finishes, including its per-column trail.
function stageEnd(stage) {
    return stageStart(stage, columns.length - 1) + stage.ms;
}

// The schedule's own length, before tempo. Every window is expressed against
// this, so `phase` stays correct at any tempo.
var drawScheduleMs = Math.max(
    stageEnd(drawDate), stageEnd(drawAxis), stageEnd(drawDrop),
    stageEnd(drawFrame), stageEnd(drawSweep), stageEnd(drawGlyph),
    stageEnd(drawLabel));

var durMenuDraw = Math.round(drawScheduleMs * drawTempo);
var durMenuUndraw = Math.round(durMenuDraw * drawUndrawRatio);
var durPeekDraw = Math.round(peekScheduleMs * drawTempo);
var durPeekUndraw = Math.round(durPeekDraw * drawUndrawRatio);

// ---------------------------------------------------------------------------
// Motion: the launcher island
// ---------------------------------------------------------------------------
//
// A section panel does not open next to the dock, it takes its place: the dock
// is absorbed back into the menu and the panel is extruded out of the same
// edge. Two shapes crossing in one socket, so the swap is treated like the
// entrance was — one curve after another, with an overlap knob rather than a
// single curve stretched over both.

// Every island in the socket moves on the same clock. They differ in what they
// hold and how tall they are, not in how fast they arrive -- a panel that
// entered faster than the dock would read as a different mechanism rather than
// as the same drawer with something else in it. The dock's tuned numbers are
// the socket's.
var socketEmergeMs = dockEmergeMs;
var socketRetractMs = dockRetractMs;

// How much of the outgoing island's retraction the incoming island's emergence
// is allowed to run under. Zero is strictly serial: the socket is empty for an
// instant between the two. Raising it past the retraction starts them together.
var sectionSwapOverlapMs = shapeMs(140);

// When the incoming island starts, measured from the beginning of a swap.
var socketAdmitMs = Math.max(0, socketRetractMs - sectionSwapOverlapMs);

// ---------------------------------------------------------------------------
// How the panels' schedules are spaced
// ---------------------------------------------------------------------------
//
// The main menu reads as being drawn rather than as appearing, and most of
// that is spacing: its stages start well apart -- the date, then the axis,
// then the drop lines, then the frames -- and each column trails the one to
// its left. The panels were written tighter than that and arrived as a lump.
//
// These are the knobs that give them the menu's spacing. Every panel below
// puts its stage starts through `spread` and trails its items by one of the
// two steps, so the whole set moves together.
//
//   panelSpread      multiplies every panel stage's START, never its length:
//                    the strokes keep their own speed and only begin further
//                    apart. 1.0 is the schedules as they were written.
//   panelLeadInMs    dead time after a panel starts moving, before the first
//                    stroke. The menu's own lead-in.
//   panelStepMs      how far each item trails the previous one where there
//                    are only a few: tiles, tabs, instrument rows. The menu's
//                    own column step.
//   panelRowStepMs   the same for a list, where there are many more of them
//                    and the menu's step would make the list crawl.

var panelSpread = 2.0;
var panelLeadInMs = drawLeadInMs;
var panelStepMs = drawColumnStepMs;
var panelRowStepMs = 60;

function spread(at) {
    return Math.round(at * panelSpread);
}

// Each panel's own pen schedule, on its own driver. The menu's schedule cannot
// carry them: that one is measured from the click, and a panel is drawn on a
// gesture that happens some unknown time later.
//
//   <stage>.stagger   whether the stage repeats per row

// ----- the dock island's pen schedule ---------------------------------------
//
// Its own driver, like every other island's.
//
// It used to ride the menu's, which was fine while the dock could only arrive
// when the menu did. The moment a section panel could be swapped back out for
// it that became wrong: the menu's driver is already at 1 by then, so the
// dock's contents were simply there, fully drawn, the instant the box arrived.
// Only a full close and reopen put the menu's driver back to zero, which is
// exactly the case that still looked right.

var dockLeadInMs = panelLeadInMs;

var drawBatteryIcon = { at: spread(0), ms: 280 };
var drawBatteryValue = { at: spread(80), ms: typeMs(batteryValueChars) };
var drawBatteryStatus = { at: spread(160), ms: typeMs(batteryStatusChars) };
var drawBatteryGauge = { at: spread(300), ms: 560 };
var drawTrayFrame = { at: spread(540), ms: 680 };
var drawTrayIcons = { at: spread(940), ms: 460 };

var dockScheduleMs = dockLeadInMs + Math.max(
    drawBatteryIcon.at + drawBatteryIcon.ms,
    drawBatteryValue.at + drawBatteryValue.ms,
    drawBatteryStatus.at + drawBatteryStatus.ms,
    drawBatteryGauge.at + drawBatteryGauge.ms,
    drawTrayFrame.at + drawTrayFrame.ms,
    drawTrayIcons.at + drawTrayIcons.ms);

var durDockDraw = Math.round(dockScheduleMs * drawTempo);
var durDockUndraw = Math.round(durDockDraw * drawUndrawRatio);

function dockPhase(t, stage) {
    var at = dockLeadInMs + stage.at;
    return remap(t * dockScheduleMs, at, at + stage.ms);
}

var launcherLeadInMs = panelLeadInMs;
var launcherRowStepMs = panelRowStepMs;

// One notch of a mouse wheel, in the eighths of a degree Qt reports. A
// touchpad sends pixels instead and is measured against the row height, so the
// two devices move the same list at the same rate.
var wheelNotch = 120;

// Two schedules on two drivers, as the settings panel has. The frame -- the
// chip, the prompt, the field, the rule and the rail -- is drawn once when the
// panel arrives. The list is drawn again every time the corpus under it
// changes, and switching corpus must not redraw the switch that did it.

var drawLauncherMode = { at: spread(0), ms: 220 };
var drawLauncherPrompt = { at: spread(60), ms: 220 };
var drawLauncherQuery = { at: spread(100), ms: 200 };
var drawLauncherAxis = { at: spread(160), ms: 520 };
var drawLauncherRail = { at: spread(340), ms: 480 };

// When a launcher stage starts, after the panel's lead-in and its row's trail.
function launcherStageStart(stage, index) {
    return launcherLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * launcherRowStepMs : 0);
}

function launcherStageEnd(stage) {
    return launcherStageStart(stage, launcherRows - 1) + stage.ms;
}

var launcherScheduleMs = Math.max(
    launcherStageEnd(drawLauncherMode), launcherStageEnd(drawLauncherPrompt),
    launcherStageEnd(drawLauncherQuery), launcherStageEnd(drawLauncherAxis),
    launcherStageEnd(drawLauncherRail));

var durLauncherDraw = Math.round(launcherScheduleMs * drawTempo);
var durLauncherUndraw = Math.round(durLauncherDraw * drawUndrawRatio);

// ----- the launcher's list --------------------------------------------------

var drawLauncherCount = { at: spread(0), ms: typeMs(launcherCountChars) };
var drawLauncherRow = { at: spread(100), ms: 300, stagger: true };

// The icon only fades, and lands as its own row's branch finishes, the way the
// menu's glyphs land with their frames.
var drawLauncherIconMs = 220;
var drawLauncherIcon = {
    at: drawLauncherRow.at + drawLauncherRow.ms - drawLauncherIconMs,
    ms: drawLauncherIconMs,
    stagger: true
};
var drawLauncherName = {
    at: drawLauncherRow.at + 120,
    ms: typeMs(launcherNameChars),
    stagger: true
};

function launcherListStageStart(stage, index) {
    return stage.at + (stage.stagger ? (index || 0) * launcherRowStepMs : 0);
}

var launcherListScheduleMs = Math.max(
    launcherListStageStart(drawLauncherCount, launcherRows - 1) + drawLauncherCount.ms,
    launcherListStageStart(drawLauncherRow, launcherRows - 1) + drawLauncherRow.ms,
    launcherListStageStart(drawLauncherIcon, launcherRows - 1) + drawLauncherIcon.ms,
    launcherListStageStart(drawLauncherName, launcherRows - 1) + drawLauncherName.ms);

var durLauncherListDraw = Math.round(launcherListScheduleMs * drawTempo);
var durLauncherListUndraw = Math.round(durLauncherListDraw * drawUndrawRatio);

// How long after the panel starts moving the list begins, so the rail it hangs
// from is already on its way across. On the pen's clock, converted.
var launcherListLeadMs = Math.round(
    (launcherLeadInMs + drawLauncherRail.at) * drawTempo);

function launcherListPhase(t, stage, index) {
    var at = launcherListStageStart(stage, index);
    return remap(t * launcherListScheduleMs, at, at + stage.ms);
}

// Progress of one launcher stage, given that panel's 0..1 driver.
function launcherPhase(t, stage, index) {
    var at = launcherStageStart(stage, index);
    return remap(t * launcherScheduleMs, at, at + stage.ms);
}

// ----- the clock panel's pen schedule ---------------------------------------
//
// Top to bottom, which is also the order the panel is read in: the readout,
// the day it sits in, then the month that day sits in. The bracket around
// today is drawn last, as the answer to the grid rather than part of it.

var clockLeadInMs = panelLeadInMs;
var clockRowStepMs = panelRowStepMs;

var drawClockNow = { at: spread(0), ms: typeMs(clockNowChars) };
var drawClockStamp = { at: spread(140), ms: typeMs(clockStampChars) };
var drawClockAxis = { at: spread(200), ms: 560 };
var drawClockHours = { at: spread(560), ms: 280 };
var drawClockMonth = { at: spread(480), ms: typeMs(clockMonthChars) };
var drawClockWeekdays = { at: spread(640), ms: 300 };
var drawClockRow = { at: spread(780), ms: 320, stagger: true };

var drawClockTodayMs = 300;
var drawClockToday = {
    at: drawClockRow.at + (clockWeeks - 1) * clockRowStepMs + drawClockRow.ms + 40,
    ms: drawClockTodayMs
};

function clockStageStart(stage, index) {
    return clockLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * clockRowStepMs : 0);
}

function clockStageEnd(stage) {
    return clockStageStart(stage, clockWeeks - 1) + stage.ms;
}

var clockScheduleMs = Math.max(
    clockStageEnd(drawClockNow), clockStageEnd(drawClockStamp),
    clockStageEnd(drawClockAxis), clockStageEnd(drawClockHours),
    clockStageEnd(drawClockMonth), clockStageEnd(drawClockWeekdays),
    clockStageEnd(drawClockRow), clockStageEnd(drawClockToday));

var durClockDraw = Math.round(clockScheduleMs * drawTempo);
var durClockUndraw = Math.round(durClockDraw * drawUndrawRatio);

// ----- the power panel's pen schedule ---------------------------------------
//
// One tile at a time, left to right: the rule, the tick that ties a tile to
// it, the frame, then the glyph landing as its own frame closes and the
// caption written under it.

var powerLeadInMs = panelLeadInMs;
var powerTileStepMs = panelStepMs;

var drawPowerAxis = { at: spread(0), ms: 460 };
var drawPowerDrop = { at: spread(260), ms: 240, stagger: true };
var drawPowerFrame = { at: spread(380), ms: 620, stagger: true };
var drawPowerGlyphMs = 300;
var drawPowerGlyph = {
    at: drawPowerFrame.at + drawPowerFrame.ms - drawPowerGlyphMs,
    ms: drawPowerGlyphMs,
    stagger: true
};
var drawPowerLabel = {
    at: drawPowerFrame.at + drawPowerFrame.ms + 20,
    ms: typeMs(powerLabelChars),
    stagger: true
};

function powerStageStart(stage, index) {
    return powerLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * powerTileStepMs : 0);
}

function powerStageEnd(stage) {
    return powerStageStart(stage, powerColumns.length - 1) + stage.ms;
}

var powerScheduleMs = Math.max(
    powerStageEnd(drawPowerAxis), powerStageEnd(drawPowerDrop),
    powerStageEnd(drawPowerFrame), powerStageEnd(drawPowerGlyph),
    powerStageEnd(drawPowerLabel));

var durPowerDraw = Math.round(powerScheduleMs * drawTempo);
var durPowerUndraw = Math.round(durPowerDraw * drawUndrawRatio);

function powerPhase(t, stage, index) {
    var at = powerStageStart(stage, index);
    return remap(t * powerScheduleMs, at, at + stage.ms);
}

// Progress of one clock stage, given that panel's 0..1 driver.
function clockPhase(t, stage, index) {
    var at = clockStageStart(stage, index);
    return remap(t * clockScheduleMs, at, at + stage.ms);
}

// ----- the settings panel's pen schedules -----------------------------------
//
// Two drivers, not one. The tabs and the rule they stand on are drawn once,
// when the panel arrives; the pane below is drawn again every time a different
// section is chosen, and a section swap must not redraw the tabs that did the
// choosing.

var settingsLeadInMs = panelLeadInMs;
var settingsTabStepMs = panelStepMs;

var drawSettingsIcon = { at: spread(0), ms: 260, stagger: true };
var drawSettingsLabel = { at: spread(160), ms: typeMs(settingsTabChars), stagger: true };
var drawSettingsRule = { at: spread(360), ms: 520 };
var drawSettingsDrop = { at: spread(760), ms: 220 };

function settingsStageStart(stage, index) {
    return settingsLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * settingsTabStepMs : 0);
}

function settingsStageEnd(stage) {
    return settingsStageStart(stage, settingsTabs - 1) + stage.ms;
}

var settingsScheduleMs = Math.max(
    settingsStageEnd(drawSettingsIcon), settingsStageEnd(drawSettingsLabel),
    settingsStageEnd(drawSettingsRule), settingsStageEnd(drawSettingsDrop));

var durSettingsDraw = Math.round(settingsScheduleMs * drawTempo);
var durSettingsUndraw = Math.round(durSettingsDraw * drawUndrawRatio);

function settingsPhase(t, stage, index) {
    var at = settingsStageStart(stage, index);
    return remap(t * settingsScheduleMs, at, at + stage.ms);
}

// The pane's own schedule, on its own driver. The list is plotted row by row,
// the way the launcher's results and the clock's weeks are.
var settingsRowStepMs = panelRowStepMs;

var drawPaneTitle = { at: spread(0), ms: typeMs(settingsTitleChars) };
var drawPaneControl = { at: spread(140), ms: 300 };
var drawPaneRule = { at: spread(200), ms: 480 };
var drawPaneDetail = { at: spread(380), ms: typeMs(settingsDetailChars) };
var drawPaneRow = { at: spread(300), ms: 300, stagger: true };

function paneStageEnd(stage) {
    return stage.at + stage.ms
        + (stage.stagger ? (settingsListRows - 1) * settingsRowStepMs : 0);
}

var paneScheduleMs = Math.max(
    paneStageEnd(drawPaneTitle), paneStageEnd(drawPaneControl),
    paneStageEnd(drawPaneRule), paneStageEnd(drawPaneDetail),
    paneStageEnd(drawPaneRow));

var durSettingsPaneDraw = Math.round(paneScheduleMs * drawTempo);
var durSettingsPaneUndraw = Math.round(durSettingsPaneDraw * drawUndrawRatio);

// How long after the panel starts drawing the first pane begins, so the rule
// the pane hangs from is already most of the way across. Expressed on the
// pen's clock and converted, because the two run at different rates.
var settingsPaneLeadMs = Math.round(
    (settingsLeadInMs + drawSettingsRule.at + drawSettingsRule.ms * 0.5) * drawTempo);

function panePhase(t, stage, index) {
    var at = stage.at
        + (stage.stagger ? (index || 0) * settingsRowStepMs : 0);
    return remap(t * paneScheduleMs, at, at + stage.ms);
}

// ----- the toast's pen schedule ---------------------------------------------
//
// Shorter than a panel's, because a toast is read in the time it is on screen
// rather than opened and studied. The body only fades: it is a paragraph, and
// typing one at the rate the rest of the bar writes would outlast the toast.

var toastLeadInMs = 60;

var drawToastApp = { at: 0, ms: typeMs(toastAppChars) };
var drawToastTime = { at: 80, ms: typeMs(toastTimeChars) };
var drawToastRule = { at: 120, ms: 420 };
var drawToastSummary = { at: 240, ms: typeMs(toastSummaryChars) };
var drawToastBody = { at: 420, ms: 320 };
// The picture is not pen work, so it only fades, and it lands with the line
// that introduces it.
var drawToastImage = { at: 200, ms: 300 };

var toastScheduleMs = toastLeadInMs + Math.max(
    drawToastApp.at + drawToastApp.ms, drawToastTime.at + drawToastTime.ms,
    drawToastRule.at + drawToastRule.ms,
    drawToastSummary.at + drawToastSummary.ms,
    drawToastBody.at + drawToastBody.ms,
    drawToastImage.at + drawToastImage.ms);

var durToastDraw = Math.round(toastScheduleMs * drawTempo);
var durToastUndraw = Math.round(durToastDraw * drawUndrawRatio);

function toastPhase(t, stage) {
    var at = toastLeadInMs + stage.at;
    return remap(t * toastScheduleMs, at, at + stage.ms);
}

// ----- the media island's pen schedule --------------------------------------
//
// Its own driver, like a panel's: the dock's contents ride the menu's
// schedule, but this island arrives a beat after the dock and its strokes have
// to be measured from its own start rather than from the click.

var mediaLeadInMs = panelLeadInMs;
var mediaRowStepMs = panelStepMs;

var drawMediaRow = { at: spread(0), ms: 420, stagger: true };
var drawMediaIcon = { at: spread(120), ms: 260, stagger: true };
var drawMediaValue = { at: spread(220), ms: typeMs(4), stagger: true };
var drawMediaDevice = { at: spread(300), ms: typeMs(mediaDeviceChars), stagger: true };
var drawMediaRule = { at: spread(420), ms: 460 };
var drawMediaArt = { at: spread(560), ms: 320 };
var drawMediaTitle = { at: spread(620), ms: typeMs(mediaTitleChars) };
var drawMediaArtist = { at: spread(700), ms: typeMs(mediaArtistChars) };
var drawMediaSeek = { at: spread(820), ms: 420 };
var drawMediaControls = { at: spread(900), ms: 300 };

function mediaStageStart(stage, index) {
    return mediaLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * mediaRowStepMs : 0);
}

function mediaStageEnd(stage) {
    return mediaStageStart(stage, mediaRows - 1) + stage.ms;
}

var mediaScheduleMs = Math.max(
    mediaStageEnd(drawMediaRow), mediaStageEnd(drawMediaIcon),
    mediaStageEnd(drawMediaValue), mediaStageEnd(drawMediaDevice),
    mediaStageEnd(drawMediaRule), mediaStageEnd(drawMediaArt),
    mediaStageEnd(drawMediaTitle), mediaStageEnd(drawMediaArtist),
    mediaStageEnd(drawMediaSeek), mediaStageEnd(drawMediaControls));

var durMediaDraw = Math.round(mediaScheduleMs * drawTempo);
var durMediaUndraw = Math.round(durMediaDraw * drawUndrawRatio);

// How far the media island trails the dock it belongs to. They are one thing
// in two boxes, so this is a beat, not a separate entrance.
var mediaTrailMs = shapeMs(120);

function mediaPhase(t, stage, index) {
    var at = mediaStageStart(stage, index);
    return remap(t * mediaScheduleMs, at, at + stage.ms);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function mix(a, b, t) {
    return a + (b - a) * t;
}

// Normalized progress of `t` across the sub-range [a, b], clamped. A window of
// zero width switches instantly rather than returning NaN, so a stage or a
// lead-in can be tuned all the way down to nothing.
function remap(t, a, b) {
    if (b <= a)
        return t >= b ? 1 : 0;
    return Math.max(0, Math.min(1, (t - a) / (b - a)));
}

function clamp01(t) {
    return Math.max(0, Math.min(1, t));
}

// "#AARRGGBB" from a base colour and an opacity, so alpha is tuned as a number
// rather than as a hex byte — and so a surface's opacity can be derived from
// the one thing that has to agree with it rather than restated next to it.
function withAlpha(rgb, alpha) {
    var byte = Math.round(clamp01(alpha) * 255).toString(16);
    return "#" + (byte.length < 2 ? "0" + byte : byte) + rgb;
}

// The largest amount of roundness a box can actually hold. Scaling a radius
// with its box keeps the ratio but not the reading: a 20x6 sliver with a
// proportional 1.5px radius has visibly square corners. Keep the designed
// radius while it fits and fall back to a stadium once it does not, so a shape
// shrinking to nothing stays round the whole way down.
function cornerRadius(nominal, w, h) {
    return Math.min(Math.max(0, nominal), Math.max(0, Math.min(w, h) / 2));
}

// Progress of one stage, given the 0..1 draw driver. `t` is rescaled to
// schedule milliseconds, so the windows stay put when the tempo changes.
function phase(t, stage, index) {
    var at = stageStart(stage, index);
    return remap(t * drawScheduleMs, at, at + stage.ms);
}

// Progress of a plain millisecond window on the menu driver. Not subject to the
// lead-in: the only user is clearing the peek chevron, which has to happen the
// moment the menu commits rather than after the pause.
function phaseMs(t, fromMs, toMs) {
    return remap(t * drawScheduleMs, fromMs, toMs);
}

// The chevron's stroke, on the peek driver, after its own lead-in.
function peekPhase(t) {
    return remap(t * peekScheduleMs, drawPeekLeadInMs,
                 drawPeekLeadInMs + drawPeekMs);
}

// Erasing the pill's resting indicator, on the same driver, before it.
function peekErasePhase(t) {
    return remap(t * peekScheduleMs, 0, drawMinuteMs);
}

// Each individual stroke carries its own acceleration, even though the
// schedule dispatching the strokes runs on linear time: a pen touches down,
// travels, and lifts. inOutCubic over one short window reads as exactly that.
function pen(t) {
    var x = clamp01(t);
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(2 - 2 * x, 3) / 2;
}

// ---------------------------------------------------------------------------
// Hairlines
// ---------------------------------------------------------------------------
//
// A straight hairline wants to be crisp, not feathered. At a fractional
// display scale a one-logical-pixel line covers 1.8 device pixels and the
// rasterizer resolves it to one or two of them depending on where it happens
// to land, so nominally identical lines come out at different weights. Pick
// the nearest whole device pixel instead and express it back in logical units.

function hairline(dpr) {
    var scale = Math.max(dpr, 0.0001);
    return Math.max(1, Math.round(strokeWeight * scale)) / scale;
}

// Snap a coordinate to the device pixel grid, so a snapped weight actually
// lands on whole pixels rather than straddling two.
function snap(v, dpr) {
    var scale = Math.max(dpr, 0.0001);
    return Math.round(v * scale) / scale;
}

// ---------------------------------------------------------------------------
// Partial paths
// ---------------------------------------------------------------------------
//
// Strokes are truncated geometrically rather than with a dash pattern. Qt only
// honours dash patterns in the geometry renderer, which has no analytic
// antialiasing, so a dashed draw-on forces every curve to be jagged. Building
// the partial path instead leaves the curve renderer free to do per-pixel
// coverage, and gives the growing end a real round cap.

// An SVG path for the first `progress` of a rounded rectangle's outline,
// clockwise from the top centre so the stroke closes opposite where it began.
function roundedRectPath(w, h, r, progress) {
    var radius = Math.max(0, Math.min(r, Math.min(w, h) / 2));
    var arcLen = Math.PI * radius / 2;
    var halfRun = Math.max(0, w / 2 - radius);
    var runW = Math.max(0, w - 2 * radius);
    var runH = Math.max(0, h - 2 * radius);

    var segments = [
        { to: [w - radius, 0], len: halfRun },
        { centre: [w - radius, radius], from: -90, len: arcLen },
        { to: [w, h - radius], len: runH },
        { centre: [w - radius, h - radius], from: 0, len: arcLen },
        { to: [radius, h], len: runW },
        { centre: [radius, h - radius], from: 90, len: arcLen },
        { to: [0, radius], len: runH },
        { centre: [radius, radius], from: 180, len: arcLen },
        { to: [w / 2, 0], len: halfRun }
    ];

    var total = 2 * halfRun + runW + 2 * runH + 4 * arcLen;
    var p = clamp01(progress);
    // Overshoot when complete, so float error cannot leave a seam at the top.
    var budget = p >= 0.999 ? total * 2 : total * p;

    var x = w / 2;
    var y = 0;
    var d = "M" + x.toFixed(2) + "," + y.toFixed(2);

    for (var i = 0; i < segments.length && budget > 0; i++) {
        var seg = segments[i];
        if (seg.len <= 0.0001)
            continue;
        var f = Math.min(1, budget / seg.len);
        budget -= seg.len;
        if (seg.centre) {
            var a = (seg.from + 90 * f) * Math.PI / 180;
            x = seg.centre[0] + radius * Math.cos(a);
            y = seg.centre[1] + radius * Math.sin(a);
            // A quarter turn at most, always clockwise in this y-down space.
            d += "A" + radius.toFixed(2) + "," + radius.toFixed(2)
                + " 0 0 1 " + x.toFixed(2) + "," + y.toFixed(2);
        } else {
            x += (seg.to[0] - x) * f;
            y += (seg.to[1] - y) * f;
            d += "L" + x.toFixed(2) + "," + y.toFixed(2);
        }
    }
    return d;
}

// ---------------------------------------------------------------------------
// Load-time check
// ---------------------------------------------------------------------------
//
// This file is a `.pragma library`, so `var` hoists a name but not its
// assignment: anything written above its own inputs evaluates to `undefined`
// or `NaN` and then fails quietly. That has already cost a layer surface that
// never mapped (a NaN height) and an easing curve that silently turned itself
// off (an undefined bezierCurve). Neither produced an error — both read as
// design problems. Naming the derived values here makes the next one announce
// itself on reload.
(function checkDerivedValues() {
    var derived = {
        surfaceWidth: surfaceWidth,
        exclusiveZone: exclusiveZone,
        surfaceHeight: surfaceHeight,
        durPeek: durPeek,
        durMenu: durMenu,
        dockEmergeMs: dockEmergeMs,
        dockRetractMs: dockRetractMs,
        dockStartMs: dockStartMs,
        menuCloseStartMs: menuCloseStartMs,

        dockScheduleMs: dockScheduleMs,
        durDockDraw: durDockDraw,
        durDockUndraw: durDockUndraw,
        peekScheduleMs: peekScheduleMs,
        drawScheduleMs: drawScheduleMs,
        durMenuDraw: durMenuDraw,
        durMenuUndraw: durMenuUndraw,
        durPeekDraw: durPeekDraw,
        durPeekUndraw: durPeekUndraw,
        tint: tint,
        menuTint: menuTint,
        easeOut: easeOut,
        easeSustained: easeSustained,
        dockCurve: dockCurve,

        launcherHeight: launcherHeight,
        lowerIslandHeight: lowerIslandHeight,
        clockHeight: clockHeight,
        powerHeight: powerHeight,
        settingsHeight: settingsHeight,
        mediaHeight: mediaHeight,
        dockPairHeight: dockPairHeight,
        toastHeight: toastHeight,
        socketEmergeMs: socketEmergeMs,
        socketRetractMs: socketRetractMs,
        socketAdmitMs: socketAdmitMs,
        launcherScheduleMs: launcherScheduleMs,
        durLauncherDraw: durLauncherDraw,
        durLauncherUndraw: durLauncherUndraw,
        launcherListScheduleMs: launcherListScheduleMs,
        durLauncherListDraw: durLauncherListDraw,
        durLauncherListUndraw: durLauncherListUndraw,
        launcherListLeadMs: launcherListLeadMs,
        launcherGraceMs: launcherGraceMs,
        panelSpread: panelSpread,
        panelLeadInMs: panelLeadInMs,
        panelStepMs: panelStepMs,
        panelRowStepMs: panelRowStepMs,
        launcherPadX: launcherPadX,
        launcherRowsY: launcherRowsY,
        wheelNotch: wheelNotch,
        clockScheduleMs: clockScheduleMs,
        durClockDraw: durClockDraw,
        durClockUndraw: durClockUndraw,
        powerScheduleMs: powerScheduleMs,
        durPowerDraw: durPowerDraw,
        durPowerUndraw: durPowerUndraw,
        settingsScheduleMs: settingsScheduleMs,
        durSettingsDraw: durSettingsDraw,
        durSettingsUndraw: durSettingsUndraw,
        paneScheduleMs: paneScheduleMs,
        durSettingsPaneDraw: durSettingsPaneDraw,
        durSettingsPaneUndraw: durSettingsPaneUndraw,
        settingsPaneLeadMs: settingsPaneLeadMs,
        toastScheduleMs: toastScheduleMs,
        durToastDraw: durToastDraw,
        durToastUndraw: durToastUndraw,
        mediaScheduleMs: mediaScheduleMs,
        durMediaDraw: durMediaDraw,
        durMediaUndraw: durMediaUndraw,
        mediaTrailMs: mediaTrailMs
    };

    var stages = {
        drawDate: drawDate, drawAxis: drawAxis, drawDrop: drawDrop,
        drawFrame: drawFrame, drawSweep: drawSweep, drawGlyph: drawGlyph,
        drawLabel: drawLabel, drawBatteryIcon: drawBatteryIcon,
        drawBatteryValue: drawBatteryValue, drawBatteryStatus: drawBatteryStatus,
        drawBatteryGauge: drawBatteryGauge, drawTrayFrame: drawTrayFrame,
        drawTrayIcons: drawTrayIcons,
        drawLauncherPrompt: drawLauncherPrompt,
        drawLauncherQuery: drawLauncherQuery,
        drawLauncherAxis: drawLauncherAxis,
        drawLauncherRail: drawLauncherRail,
        drawLauncherCount: drawLauncherCount,
        drawLauncherRow: drawLauncherRow,
        drawLauncherIcon: drawLauncherIcon,
        drawLauncherName: drawLauncherName,
        drawLauncherMode: drawLauncherMode,
        drawClockNow: drawClockNow,
        drawClockStamp: drawClockStamp,
        drawClockAxis: drawClockAxis,
        drawClockHours: drawClockHours,
        drawClockMonth: drawClockMonth,
        drawClockWeekdays: drawClockWeekdays,
        drawClockRow: drawClockRow,
        drawClockToday: drawClockToday,
        drawPowerAxis: drawPowerAxis,
        drawPowerDrop: drawPowerDrop,
        drawPowerFrame: drawPowerFrame,
        drawPowerGlyph: drawPowerGlyph,
        drawPowerLabel: drawPowerLabel,
        drawSettingsIcon: drawSettingsIcon,
        drawSettingsLabel: drawSettingsLabel,
        drawSettingsRule: drawSettingsRule,
        drawSettingsDrop: drawSettingsDrop,
        drawPaneTitle: drawPaneTitle,
        drawPaneControl: drawPaneControl,
        drawPaneRule: drawPaneRule,
        drawPaneDetail: drawPaneDetail,
        drawPaneRow: drawPaneRow,
        drawToastApp: drawToastApp,
        drawToastTime: drawToastTime,
        drawToastRule: drawToastRule,
        drawToastSummary: drawToastSummary,
        drawToastBody: drawToastBody,
        drawToastImage: drawToastImage,
        drawMediaRow: drawMediaRow,
        drawMediaIcon: drawMediaIcon,
        drawMediaValue: drawMediaValue,
        drawMediaDevice: drawMediaDevice,
        drawMediaRule: drawMediaRule,
        drawMediaArt: drawMediaArt,
        drawMediaTitle: drawMediaTitle,
        drawMediaArtist: drawMediaArtist,
        drawMediaSeek: drawMediaSeek,
        drawMediaControls: drawMediaControls
    };

    function broken(value) {
        if (value === undefined || value === null)
            return true;
        if (typeof value === "number")
            return !isFinite(value);
        if (value instanceof Array)
            return value.length === 0 || value.some(function (n) {
                return typeof n !== "number" || !isFinite(n);
            });
        return false;
    }


    var name;
    for (name in derived) {
        if (broken(derived[name]))
            console.warn("theme.js: " + name + " is " + derived[name]
                + " — it is probably assigned above something it reads.");
    }
    for (name in stages) {
        if (broken(stages[name].at) || broken(stages[name].ms))
            console.warn("theme.js: stage " + name + " has at="
                + stages[name].at + " ms=" + stages[name].ms);
    }
})();
