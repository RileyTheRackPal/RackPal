// The TYPE chip (docs/08 §3.5, M6-K3 `#980`).
//
// A 16 x 9 pt box holding a horizontal line drawn with the family's exact
// hue, dash and weight over an 18% tint of the same hue, so a schedule row
// and the drawing cross-reference with no legend lookup, and greyscale
// still separates the families by dash and weight (PAL-1).
//
// THE TINT IS PRE-COMPOSITED onto white (§7.6 divergence 9: no alpha in
// the document), so the PDF and the screen fill the same opaque colour.
//
// THE STYLE IS `resolveSignalStyle`'s, the one the legend and the drawings
// read, with the project's colour overrides: a chip that resolved its own
// style would be a second answer to "what does this cable look like".

import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/signal_style.dart';
import 'package:rackpal_core/src/draw/spec.dart';

/// The chip's box, in points (§3.5).
const double kTypeChipWidth = 16;
const double kTypeChipHeight = 9;

/// How much of the hue the background carries (§3.5).
const double kTypeChipTint = 0.18;

/// [argb] at [fraction] strength over white, opaque.
int tintOverWhite(int argb, double fraction) {
  int channel(int shift) {
    final c = (argb >> shift) & 0xFF;
    return (255 - (255 - c) * fraction).round().clamp(0, 255);
  }

  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}

/// The chip's ops, its box's left edge at [left] and centred on [y].
List<DiagramOp> typeChipOps(SignalStyle style, double left, double y) {
  final box = DBox.fromLtwh(
    left,
    y - kTypeChipHeight / 2,
    kTypeChipWidth,
    kTypeChipHeight,
  );
  return <DiagramOp>[
    OpRect(box, fill: Fill(tintOverWhite(style.argb, kTypeChipTint))),
    OpLine(
      DPt(box.left + 1.5, y),
      DPt(box.right - 1.5, y),
      Stroke(argb: style.argb, widthPt: style.widthPt, dash: style.dash),
    ),
  ];
}
