// CR-105's elevation signpost: "a device with unconnected ports shows a
// port-count chip (`🔗 0/12`) in the elevation, and clicking it switches to
// the schematic with that device selected."
//
// ═══════════════════════════════════════════════════════════════════════
// SCREEN CHROME, NOT THE SHARED IR — AND THAT IS THE SAME RULING TWICE
// ═══════════════════════════════════════════════════════════════════════
// `render_device_box.dart` already states it for the selection outline:
// "selection is chrome, so like the hover/focus rings it is screen-space
// and not part of the shared IR". The chip is the same class of thing and
// the consequence is sharper: `buildRackScene` feeds BOTH the screen and
// the PDF (CR-086), so a chip emitted into the scene would print on the
// customer's elevation sheet. A navigation affordance on paper is not a
// navigation affordance; it is a smudge.
//
// So it is drawn here, over the replayed fragment, by the render object
// that already draws the rings.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE FUNCTION OWNS THE RECTANGLE, AND THAT IS THE POINT OF THIS FILE
// ═══════════════════════════════════════════════════════════════════════
// Two things need the chip's geometry and they live in different layers:
// `RenderDeviceBox` paints it in the device's LOCAL coordinates, and
// `RackCanvasScreen` hit-tests it in SCENE coordinates before it runs the
// device hit-test (the same precedence `_isTopEdgeGrab` already takes).
// A chip you can see but not click, or click but not see, is what two
// copies of this arithmetic produce the first time one of them is edited.
// [portChipRect] is therefore the only place the numbers exist, and both
// callers pass the same measurer.
//
// ═══════════════════════════════════════════════════════════════════════
// THE GLYPH IS DRAWN, NOT TYPED
// ═══════════════════════════════════════════════════════════════════════
// CR-105 writes the chip as `🔗 0/12`. That emoji is a font gamble — it
// resolves through Segoe UI Emoji on Windows, through nothing at all in
// `flutter test`, and through whatever the host has on Linux — for a mark
// that has to read at eleven diagram units. Two stroked round-rects,
// overlapped, are a chain link at any size and on any host, so the glyph
// is geometry and only the count is text. The ruling asked for a chip that
// says "connections"; this is that chip, drawn rather than transcribed.
import 'package:rackpal_core/rackpal_core.dart';

/// The chip's height in diagram units.
///
/// A 1U device is [RackGeometry.unitsPerRu] = 22 units tall, so this is
/// half of the shortest device that can carry one and still clears
/// `device_layer.dart`'s 4-unit padding top and bottom.
const double kPortChipHeight = 11;

/// The gap between the chip and the device body's bottom-right corner —
/// `device_layer.dart`'s own `_pad`, so the chip lines up with the type
/// line's left margin rather than sitting at its own inset.
const double kPortChipInset = 4;

/// The count's type size. `RackTextSizes.type` (8) is the smallest thing
/// the elevation already draws, and the chip must not be the surface that
/// lowers the floor `RackTypeScale` inflates against.
const double kPortChipTextPt = RackTextSizes.type;

/// Space either side of the count inside the pill.
const double kPortChipTextPad = 3;

/// The chain-link mark's width, and the gap before the count.
const double kPortChipGlyphWidth = 9;
const double kPortChipGlyphGap = 2;

/// Everything the chip needs that is not geometry — colours, in packed
/// ARGB, taken from the host's `ColorScheme` rather than from
/// [RackPalette].
///
/// NOT ON `RackPalette`, deliberately: that type is in core and is read by
/// the PDF backend, and a colour added there is a colour the exporter can
/// reach for. See this file's header.
final class PortChipStyle {
  const PortChipStyle({
    required this.fillArgb,
    required this.strokeArgb,
    required this.textArgb,
    this.strokeWidth = 1,
  });

  final int fillArgb;
  final int strokeArgb;
  final int textArgb;
  final double strokeWidth;
}

/// The chip's rectangle in the device's LOCAL coordinates, or null when
/// the device body cannot carry one.
///
/// Bottom-right, because that corner is the only one free:
/// `device_layer.dart` puts the designator top-left, the U-height badge
/// top-right, and the name and type lines down the left. Returning null
/// rather than clipping is what keeps a half-drawn pill off a 1U device
/// that has been placed at a partial width — and because the hit test
/// calls this same function, a chip that is not drawn is also not
/// clickable.
DBox? portChipRect({
  required double deviceWidth,
  required double deviceHeight,
  required String label,
  required TextMeasurer measurer,
}) {
  final textWidth = measurer.measureText(label, _chipTextStyle(0)).advanceWidth;
  final width =
      kPortChipGlyphWidth +
      kPortChipGlyphGap +
      textWidth +
      2 * kPortChipTextPad;

  // It has to fit INSIDE the body with its inset on both axes, or it is
  // not a chip on this device, it is a smear across its label.
  if (deviceWidth < width + 2 * kPortChipInset) return null;
  if (deviceHeight < kPortChipHeight + 2 * kPortChipInset) return null;

  return DBox.fromLtwh(
    deviceWidth - kPortChipInset - width,
    deviceHeight - kPortChipInset - kPortChipHeight,
    width,
    kPortChipHeight,
  );
}

/// Draws the chip into [canvas] at [rect], which the caller took from
/// [portChipRect] with the same [label] and measurer.
void paintPortChip(
  DiagramCanvas canvas,
  DBox rect,
  String label,
  PortChipStyle style,
) {
  canvas.drawRoundRect(
    rect,
    const Radii.circular(kPortChipHeight / 2),
    fill: Fill(style.fillArgb),
    // `scaleWithGeometry: false` on every stroke here — the pill is a
    // navigation affordance and its outline should stay one screen pixel
    // whether the user is zoomed to a whole 42U rack or to one device.
    // The rack's own rails do the opposite, and that is the difference
    // between chrome and drawing.
    stroke: Stroke(
      argb: style.strokeArgb,
      widthPt: style.strokeWidth,
      scaleWithGeometry: false,
    ),
  );

  // The chain link: two round-rects side by side, stroked in the text
  // colour. Small enough that the radius does the reading — at eleven
  // units this is a link, not two boxes.
  const glyphH = kPortChipHeight - 2 * 3.0;
  const linkW = kPortChipGlyphWidth * 0.62;
  final left = rect.left + kPortChipTextPad;
  final top = rect.top + 3;
  final linkStroke = Stroke(
    argb: style.textArgb,
    widthPt: style.strokeWidth,
    scaleWithGeometry: false,
  );
  canvas
    ..drawRoundRect(
      DBox.fromLtwh(left, top, linkW, glyphH),
      const Radii.circular(glyphH / 2),
      stroke: linkStroke,
    )
    ..drawRoundRect(
      DBox.fromLtwh(left + kPortChipGlyphWidth - linkW, top, linkW, glyphH),
      const Radii.circular(glyphH / 2),
      stroke: linkStroke,
    )
    ..drawText(
      label,
      DPt(
        rect.left + kPortChipTextPad + kPortChipGlyphWidth + kPortChipGlyphGap,
        rect.top + kPortChipHeight / 2,
      ),
      _chipTextStyle(style.textArgb),
    );
}

/// What a screen reader is told about the chip, appended to the device's
/// own label.
///
/// THE CHIP IS POINTER-ONLY, AND THIS SENTENCE IS WHY THAT IS SURVIVABLE
/// RATHER THAN FINE. There is no `KeyBindingId` for "reveal in schematic"
/// — the corpus declares none, and inventing a binding is exactly what
/// `keymap.dart` refuses to do one row at a time. So a keyboard-only user
/// gets the FACT from here and reaches the same sheet with `Ctrl+2`, which
/// is bound. The gap that remains is arriving there with this device
/// already selected; it is recorded on the milestone board rather than
/// papered over with a semantic action that does something a real tap on
/// the same pixels does not.
String portChipSemantics(PortFill fill) =>
    '${fill.connected} of ${fill.total} ports connected';

TextStyleSpec _chipTextStyle(int argb) =>
    rackText(kPortChipTextPt, argb, TextAnchor.midLeft);
