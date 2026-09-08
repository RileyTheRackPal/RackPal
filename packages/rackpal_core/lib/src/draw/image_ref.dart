// rackpal_core/src/draw/image_ref.dart — pure Dart, no decoder.
//
// The opaque handle `DiagramCanvas.drawImage` takes (docs/08-pdf-export.md
// §7.3 row 17, docs/15-plan-view.md §7), added under `canvas.dart`'s own
// amendment clause by DR-029 §11.28.6.
//
// ═══════════════════════════════════════════════════════════════════════
// IT CARRIES A REFERENCE. IT NEVER CARRIES PIXELS.
// ═══════════════════════════════════════════════════════════════════════
// A display list is compared byte for byte (M2-C's determinism clause) and
// every scene builder's output is held in memory while a sheet set is laid
// out. An `OpImage` holding a `Uint8List` would put megabytes into the one
// structure whose entire purpose is to be cheap to compare and cheap to
// hold, and it would drag an image decoder into a package that is
// Flutter-free by gate and has no business owning one.
//
// So this is a NAME plus the two facts a layout pass needs about the
// picture without opening it: its intrinsic pixel size, and its encoding.
// Each backend resolves [member] to bytes through its own
// `ImageResolver` — `ui.Image` on the screen, `PdfImage` in the export —
// and neither image type ever reaches the IR.
//
// WHY THE INTRINSIC SIZE IS HERE AND NOT LOOKED UP: `BoundsCanvas` must
// report a scene's ink extent without touching the bytes, and a scene
// builder must be able to preserve aspect ratio while choosing the
// destination rect. docs/15 §3.1 puts `pixelWidth`/`pixelHeight` on
// `PlanUnderlay` for exactly this reason, "so aspect is known without
// decoding"; this type is where that fact is consumed.

import 'package:meta/meta.dart';

/// The encodings a container member may hold.
///
/// Two values, and the list is closed on purpose (docs/15 §2). A PDF
/// floorplan is resolved to one of these AT IMPORT and the member written
/// to the container is still PNG or JPEG, so no third value is owed by
/// DR-029's PDF import and `rackpal_core` still needs no decoder.
///
/// This said *"rasterised at IMPORT"* until DR-138, and the mechanism
/// changed under it: a page that is one full-page image has that image
/// **lifted** verbatim, and a page that is not is refused by name. The
/// conclusion is untouched (what lands in the container is still PNG or
/// JPEG) and only the verb was wrong, which is exactly the kind of
/// sentence that survives a sweep aimed at the conclusion.
///
/// The two are NOT interchangeable to the PDF backend and the difference
/// is worth knowing here rather than discovering downstream: `PdfImage.jpeg`
/// embeds the source bytes verbatim under `/Filter /DCTDecode`, while a PNG
/// is decoded to raw RGB and costs the document `width × height × 3` bytes.
enum ImageFormat {
  png,
  jpeg;

  /// The extension a container member of this format carries, without the
  /// dot. The container's member layout is `underlays/<uuid>.<ext>`
  /// (docs/15 §2).
  String get extension => switch (this) {
    ImageFormat.png => 'png',
    ImageFormat.jpeg => 'jpg',
  };
}

/// An opaque handle to a raster held in the document's container.
///
/// Value equality on all three fields, so two ops referring to the same
/// member compare equal and a display list stays comparable by data
/// (docs/08 §7.9).
@immutable
final class ImageRef {
  const ImageRef({
    required this.member,
    required this.format,
    required this.pixelWidth,
    required this.pixelHeight,
  }) : assert(pixelWidth > 0, 'ImageRef.pixelWidth must be positive'),
       assert(pixelHeight > 0, 'ImageRef.pixelHeight must be positive');

  /// The container member path, `underlays/<uuid>.png` (docs/15 §2).
  ///
  /// A path and not a `Uuid`, because DR-030's title-block logo is the
  /// second consumer of this op and does not live under `underlays/`.
  final String member;

  final ImageFormat format;

  /// Intrinsic size in pixels. Never a drawing size: the destination rect
  /// is the `drawImage` argument, and nothing here implies a scale.
  final int pixelWidth;
  final int pixelHeight;

  /// Intrinsic width over height. What a scene builder multiplies by to
  /// fit a picture into a box without stretching it (DR-030's fit rule:
  /// aspect preserved, never stretched).
  double get aspectRatio => pixelWidth / pixelHeight;

  @override
  bool operator ==(Object other) =>
      other is ImageRef &&
      other.member == member &&
      other.format == format &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight;

  @override
  int get hashCode => Object.hash(member, format, pixelWidth, pixelHeight);

  @override
  String toString() =>
      'ImageRef($member, ${format.name}, ${pixelWidth}x$pixelHeight)';
}

/// Thrown by a backend asked to draw an [ImageRef] its resolver does not
/// know.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT THROWS RATHER THAN DRAWING NOTHING, DELIBERATELY.
/// ═══════════════════════════════════════════════════════════════════════
/// A missing underlay that draws nothing produces a `T1.01` that is a
/// title block over white paper, printed, handed to somebody at seven in
/// the morning, and indistinguishable from a plan with no pins on it. That
/// is the exact failure the Plan view exists to prevent, arriving silently.
///
/// Nothing constructs an `OpImage` yet, so this is unreachable in shipped
/// code today. It becomes reachable when PLAN-C and PLAN-D wire the
/// underlay to a container member, and the person who does that decides
/// what the USER sees; what this type guarantees is that they cannot skip
/// the question by accident, which is `cable_footage.dart:302`'s idiom one
/// package over.
final class MissingImageError extends Error {
  MissingImageError(this.ref);

  final ImageRef ref;

  @override
  String toString() =>
      'MissingImageError: no image resolved for container member '
      '"${ref.member}". The canvas was handed an OpImage whose member is '
      'not in its resolver. This is a wiring fault, not user data.';
}
