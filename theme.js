.pragma library

// shoji-bar-3 design tokens.
// Dynamic Island silhouette + ShojiWM liquid glass + line-drawn instrumentation.
// All geometry is in logical pixels of the layer surface.

// ---------------------------------------------------------------------------
// Placement inside the single layer surface
// ---------------------------------------------------------------------------

// Gap between the screen's top edge and the silhouette.
var screenPad = 10;
// Slack kept around the silhouette inside the surface: antialiasing plus the
// outward bulge of the smooth-minimum blend when shapes merge.
var surfacePad = 40;

// ---------------------------------------------------------------------------
// Silhouette geometry per state
// ---------------------------------------------------------------------------

var barWidth = 152;
var barHeight = 34;
var barRadius = 17;

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
var columns = [0.25, 0.5, 0.75];

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
var launcherPromptX = launcherPadX + 2;
var launcherQueryX = launcherPadX + 24;
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
var lowerIslandHeight = Math.max(dockHeight, launcherHeight);
var surfaceHeight = screenPad + menuHeight + dockGap + lowerIslandHeight + surfacePad;

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

var textPrimary = "#f2f7fc";
var textMuted = "#a9bccd";

var lineStrong = "#c8dcee";
var lineNormal = "#a8c2d8";
var lineFaint = "#8fa8bd";

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
var shapeTempo = 1.25;

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
var drawTempo = 0.6;

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
// These run alongside the menu's stages rather than after them. The islands are
// far enough apart to be read at once, and queueing them would double the time
// the menu takes to finish for no gain. Each island still resolves top to
// bottom within itself, and the island's contents start with the island.
var batteryValueChars = 4;
var batteryStatusChars = 17;

// Where the island starts moving, expressed in schedule milliseconds. Its
// contents start with it, so the island and the drawing inside it read as one
// event rather than two. The island runs on the silhouette's clock, which
// `drawTempo` does not scale, so the crossing is computed rather than written
// down: a constant would drift the moment either clock was retuned.
// Negative when the island starts before the pen's lead-in has even elapsed,
// which the schedule cannot express: nothing on the pen's clock can happen
// earlier than `drawLeadInMs`. Kept unclamped so the check at the end of the
// file can say so rather than letting the two quietly drift apart.
var dockStartsAtRaw = dockStartMs / drawTempo - drawLeadInMs;
var dockStartsAt = Math.max(0, dockStartsAtRaw);

// Offset from that, if the contents should trail the island after all.
var dockContentLeadMs = 0;
var dockContentAt = dockStartsAt + dockContentLeadMs;

var drawBatteryIcon = { at: dockContentAt, ms: 280 };
var drawBatteryValue = { at: dockContentAt + 80, ms: typeMs(batteryValueChars) };
var drawBatteryStatus = { at: dockContentAt + 160, ms: typeMs(batteryStatusChars) };
var drawBatteryGauge = { at: dockContentAt + 300, ms: 560 };
var drawTrayFrame = { at: dockContentAt + 540, ms: 680 };
var drawTrayIcons = { at: dockContentAt + 940, ms: 460 };

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
    stageEnd(drawLabel), stageEnd(drawBatteryIcon), stageEnd(drawBatteryValue),
    stageEnd(drawBatteryStatus), stageEnd(drawBatteryGauge),
    stageEnd(drawTrayFrame), stageEnd(drawTrayIcons));

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

var launcherEmergeMs = shapeMs(520);
var launcherRetractMs = shapeMs(300);

// How much of the outgoing island's retraction the incoming island's emergence
// is allowed to run under. Zero is strictly serial: the socket is empty for an
// instant between the two. Raising it past the retraction starts them together.
var sectionSwapOverlapMs = shapeMs(140);

var launcherStartMs = Math.max(0, dockRetractMs - sectionSwapOverlapMs);
var dockReturnStartMs = Math.max(0, launcherRetractMs - sectionSwapOverlapMs);

// The panel's own pen schedule, on its own driver. The menu's schedule cannot
// carry it: that one is measured from the click, and the panel is drawn on a
// gesture that happens some unknown time later.
//
//   launcherLeadInMs   dead time after the panel starts moving
//   launcherRowStepMs  how far each row trails the one above it
//   <stage>.stagger    whether the stage repeats per row

var launcherLeadInMs = 100;
var launcherRowStepMs = 60;

// One notch of a mouse wheel, in the eighths of a degree Qt reports. A
// touchpad sends pixels instead and is measured against the row height, so the
// two devices move the same list at the same rate.
var wheelNotch = 120;

var drawLauncherPrompt = { at: 0, ms: 220 };
var drawLauncherQuery = { at: 100, ms: 200 };
var drawLauncherAxis = { at: 160, ms: 520 };
var drawLauncherRail = { at: 340, ms: 480 };
var drawLauncherCount = { at: 420, ms: typeMs(launcherCountChars) };
var drawLauncherRow = { at: 520, ms: 300, stagger: true };

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

// When a launcher stage starts, after the panel's lead-in and its row's trail.
function launcherStageStart(stage, index) {
    return launcherLeadInMs + stage.at
        + (stage.stagger ? (index || 0) * launcherRowStepMs : 0);
}

function launcherStageEnd(stage) {
    return launcherStageStart(stage, launcherRows - 1) + stage.ms;
}

var launcherScheduleMs = Math.max(
    launcherStageEnd(drawLauncherPrompt), launcherStageEnd(drawLauncherQuery),
    launcherStageEnd(drawLauncherAxis), launcherStageEnd(drawLauncherRail),
    launcherStageEnd(drawLauncherCount), launcherStageEnd(drawLauncherRow),
    launcherStageEnd(drawLauncherIcon), launcherStageEnd(drawLauncherName));

var durLauncherDraw = Math.round(launcherScheduleMs * drawTempo);
var durLauncherUndraw = Math.round(durLauncherDraw * drawUndrawRatio);

// Progress of one launcher stage, given that panel's 0..1 driver.
function launcherPhase(t, stage, index) {
    var at = launcherStageStart(stage, index);
    return remap(t * launcherScheduleMs, at, at + stage.ms);
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
        surfaceHeight: surfaceHeight,
        durPeek: durPeek,
        durMenu: durMenu,
        dockEmergeMs: dockEmergeMs,
        dockRetractMs: dockRetractMs,
        dockStartMs: dockStartMs,
        menuCloseStartMs: menuCloseStartMs,
        dockStartsAt: dockStartsAt,

        dockContentAt: dockContentAt,
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
        launcherEmergeMs: launcherEmergeMs,
        launcherRetractMs: launcherRetractMs,
        launcherStartMs: launcherStartMs,
        dockReturnStartMs: dockReturnStartMs,
        launcherScheduleMs: launcherScheduleMs,
        durLauncherDraw: durLauncherDraw,
        durLauncherUndraw: durLauncherUndraw,
        launcherGraceMs: launcherGraceMs,
        launcherPadX: launcherPadX,
        launcherRowsY: launcherRowsY,
        wheelNotch: wheelNotch
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
        drawLauncherName: drawLauncherName
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

    if (dockStartsAtRaw < -1) {
        console.warn("theme.js: the lower island starts "
            + Math.round(-dockStartsAtRaw * drawTempo)
            + "ms before the pen's lead-in elapses, so its contents cannot"
            + " start with it and will begin at the lead-in instead."
            + " Lower drawLeadInMs to "
            + Math.floor(dockStartMs / drawTempo)
            + " or below to keep them together.");
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
