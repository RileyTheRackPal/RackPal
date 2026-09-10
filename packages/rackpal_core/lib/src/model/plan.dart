// rackpal_core/src/model/plan.dart — the Plan view's model (docs/15 §3,
// DR-029, DR-037).
//
// Four additions, all additive, all using absent-key-is-unknown (G4,
// CR-114), and none changing an existing field's meaning.
//
// ═══════════════════════════════════════════════════════════════════════
// CR-001 FORBIDS THE OBVIOUS SHAPE, AND THE OBVIOUS SHAPE IS A `double`
// ═══════════════════════════════════════════════════════════════════════
// A scale is a ratio: nanometres per pixel. It cannot be an integer, and
// CR-001 forbids a floating-point length in the model and in any file
// format. Both cannot be satisfied by storing the factor, so THE FACTOR
// IS NEVER STORED. What persists is the two integer pixel coordinates the
// user picked and the one `Len` they typed, which is exactly what they
// supplied and nothing derived from it.
//
// The factor is computed at the point of use. That intermediate IS a
// `double`, and that is allowed on the same terms `Pt` is integer while
// the canvas draws in `DPt`: CR-001 governs what is STORED. Two
// obligations attach and both are met here rather than at call sites:
//
//   * ROUND WITH ONE STATED RULE. Half away from zero, which is Dart's
//     `double.round()`, so two machines given the same file agree on the
//     same nanometre.
//   * ROUND ONCE, AT THE BOUNDARY. Never per segment and then summed.
//     [lengthAlong] exists so that the correct way to measure a
//     multi-segment path is also the easy one; summing [lengthBetween]
//     over the segments would round once per corner and drift.
//
// ═══════════════════════════════════════════════════════════════════════
// AN UNUSABLE SCALE IS `null`, NOT AN EXCEPTION AND NOT A GUESS
// ═══════════════════════════════════════════════════════════════════════
// Two points in the same place have no distance between them, so a
// `PlanScale` whose `a == b` yields no factor. That is G4: the answer is
// unknown, and the caller reports an unknown rather than receiving a
// fabricated one. It is deliberately NOT a constructor assertion, because
// the decoder must be able to read whatever is on disk (CR-093, "read
// never throws") and an assert that fires in a debug build and vanishes
// in a release one is the worst of both.
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/px_pt.dart';

/// The raster formats an underlay member may hold (docs/15 §2).
///
/// Two values, closed on purpose. DR-029 buys PDF IMPORT, and a PDF is
/// resolved to one of these at import: the member written to the container
/// is still PNG or JPEG, so PDF import owes this enum nothing and
/// `rackpal_core` still needs no decoder.
///
/// Read *"rasterised at import"* until DR-138 changed the mechanism to
/// lifting the page's own embedded image. The enum is unaffected, which is
/// why the stale verb survived: the sentence's conclusion stayed true
/// while its premise stopped being.
enum PlanImageFormat {
  png,
  jpeg;

  /// The extension a member of this format carries, without the dot.
  String get extension => switch (this) {
    PlanImageFormat.png => 'png',
    PlanImageFormat.jpeg => 'jpg',
  };
}

/// The calibration a user performs by picking two points and typing the
/// real distance between them (docs/15 §3.2).
@immutable
final class PlanScale {
  const PlanScale({required this.a, required this.b, required this.distance});

  /// The two points picked, in the underlay's own pixel space.
  final PxPt a;
  final PxPt b;

  /// The real-world distance between [a] and [b], as typed.
  final Len distance;

  /// The pixel distance between [a] and [b]. A `double` because it is a
  /// hypotenuse, and an intermediate rather than a stored value.
  double get pixelSpan {
    final dx = (b.px - a.px).toDouble();
    final dy = (b.py - a.py).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Nanometres per image pixel, or `null` when this calibration cannot
  /// yield one.
  ///
  /// Null when the two points coincide, and null when the typed distance
  /// is zero or negative: each of those is somebody's input, not a fact
  /// about the building, and none of them has an answer that is better
  /// than saying so.
  double? get nanometresPerPixel {
    final span = pixelSpan;
    if (span <= 0 || distance.nm <= 0) return null;
    return distance.nm / span;
  }

  /// True when this calibration can produce a length at all.
  bool get isUsable => nanometresPerPixel != null;

  /// The real distance between two points on this underlay, or `null`
  /// when [isUsable] is false.
  ///
  /// **Rounded once, here.** Callers receive nanometres and never a
  /// factor, so there is no second place for a rounding rule to be
  /// chosen differently.
  Len? lengthBetween(PxPt p, PxPt q) {
    final perPixel = nanometresPerPixel;
    if (perPixel == null) return null;
    final dx = (q.px - p.px).toDouble();
    final dy = (q.py - p.py).toDouble();
    return Len((math.sqrt(dx * dx + dy * dy) * perPixel).round());
  }

  /// The real length of a multi-segment path, rounded ONCE at the end.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS EXISTS SO THE CORRECT WAY IS ALSO THE EASY WAY
  /// ═══════════════════════════════════════════════════════════════════
  /// Summing [lengthBetween] over the segments rounds once per corner and
  /// accumulates the error the whole design of this class is arranged to
  /// avoid. The pixel distances are summed first, in pixel space, and the
  /// single conversion happens after. A caller with three points and no
  /// [lengthAlong] would have written the other thing.
  ///
  /// `null` for the same reasons [lengthBetween] is, and `Len.zero` for a
  /// path of fewer than two points, which is a measured zero rather than
  /// an unknown: a path with no segments really is no distance.
  Len? lengthAlong(List<PxPt> path) {
    final perPixel = nanometresPerPixel;
    if (perPixel == null) return null;
    if (path.length < 2) return Len.zero;
    var pixels = 0.0;
    for (var i = 1; i < path.length; i++) {
      final dx = (path[i].px - path[i - 1].px).toDouble();
      final dy = (path[i].py - path[i - 1].py).toDouble();
      pixels += math.sqrt(dx * dx + dy * dy);
    }
    return Len((pixels * perPixel).round());
  }

  @override
  bool operator ==(Object other) =>
      other is PlanScale &&
      other.a == a &&
      other.b == b &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(a, b, distance);

  @override
  String toString() => 'PlanScale($a -> $b = ${distance.nm}nm)';
}

/// A position on one underlay (docs/15 §3.4).
///
/// Carries the underlay id as well as the point, because a document may
/// hold several plans and a bare [PxPt] means nothing without the raster
/// it indexes.
@immutable
final class PlanPin {
  const PlanPin({required this.underlayId, required this.at});

  final Uuid underlayId;
  final PxPt at;

  @override
  bool operator ==(Object other) =>
      other is PlanPin && other.underlayId == underlayId && other.at == at;

  @override
  int get hashCode => Object.hash(underlayId, at);

  @override
  String toString() => 'PlanPin(${underlayId.v} @ $at)';
}

/// The PDF page a RENDERED underlay came from (DR-153 §11.152.6).
///
/// ═══════════════════════════════════════════════════════════════════════
/// KEPT FOR A RENDERED PAGE AND ABSENT FOR A LIFTED ONE
/// ═══════════════════════════════════════════════════════════════════════
/// The asymmetry is the whole design. A lifted page's stored bytes ARE
/// the source: DR-138 §11.137.3 established that lifting is lossless by
/// construction, so a copy of the PDF beside it would store the same
/// drawing twice. **A rendered page has thrown the vector away**, and only
/// the source can bring it back.
///
/// What it buys is that vector passthrough to the exported sheet stays
/// available without re-importing a single plan, which is the half of that
/// decision that cannot be taken later. What it costs is one copy of a
/// file the user already has.
///
/// **IT IS AN ORDINARY ADDITIVE OPTIONAL FIELD** on `riseAllowance`'s
/// precedent (DR-024, and `documentMinReaderVersion`'s own note): an older
/// build drops it, and what is lost is a copy rather than a drawing
/// somebody spent an afternoon making. The question is moot in practice,
/// since a document holding one necessarily holds an underlay and is
/// already stamped `kPlanMinReaderVersion`.
@immutable
final class PlanSourcePage {
  const PlanSourcePage({
    required this.member,
    required this.pageIndex,
    required this.contentHash,
  });

  /// The container member holding the PDF, `sources/<id>.pdf`. A PATH and
  /// not bytes, exactly as [PlanUnderlay.imageMember] is.
  final String member;

  /// Which page of it, counting from zero.
  final int pageIndex;

  /// `sha256:` over the member's bytes, on [PlanUnderlay.contentHash]'s
  /// own terms: **a mismatch is a warning and never a load failure**
  /// (AC-042). A plan that will not open is worse than a plan somebody
  /// has re-saved.
  final String contentHash;

  @override
  bool operator ==(Object other) =>
      other is PlanSourcePage &&
      other.member == member &&
      other.pageIndex == pageIndex &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(member, pageIndex, contentHash);

  @override
  String toString() => 'PlanSourcePage($member page ${pageIndex + 1})';
}

/// An architect's floorplan, carried inside the project (docs/15 §3.1).
final class PlanUnderlay {
  PlanUnderlay({
    required this.id,
    required this.name,
    required this.imageMember,
    required this.format,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.contentHash,
    required this.order,
    required this.meta,
    this.locationId,
    this.scale,
    this.sourcePage,
  });

  final Uuid id;

  // ACCESS CONTROL: mutable pending the @internal retrofit (AC-013), on
  // the pattern every other entity in `RackDocument`'s maps follows. See
  // internal_setter_grep_test.dart.

  /// What a person calls it: "Level 1", "Basement", "Site".
  String name;

  /// The `Location` this depicts, usually a floor. Null is unknown, and
  /// an underlay with no location is perfectly ordinary: a site plan
  /// depicts no room.
  Uuid? locationId;

  /// The container member holding the image, `underlays/<id>.png`
  /// (docs/15 §2). A PATH and not bytes: `rackpal_core` has no image
  /// decoder and the bytes live in the container.
  String imageMember;

  PlanImageFormat format;

  /// Intrinsic size in pixels.
  ///
  /// STORED so the model can lay a plan out, hit-test a pin and size a
  /// sheet WITHOUT DECODING THE IMAGE. That is what keeps core
  /// decoder-free, which matters because core is Flutter-free by gate and
  /// because AC-057 counted the decode surface as a real cost.
  int pixelWidth;
  int pixelHeight;

  /// `sha256:` over the member's bytes. AC-042's survivor: a MISMATCH IS
  /// A WARNING AND NEVER A LOAD FAILURE, because a plan that will not
  /// open is worse than a plan somebody has re-saved.
  String contentHash;

  /// The PDF page this was rendered from, or null when there is none:
  /// an image imported directly, or a page LIFTED rather than rendered,
  /// whose stored bytes are already the source (DR-153 §11.152.6).
  PlanSourcePage? sourcePage;

  /// The calibration, or `null` for UNCALIBRATED.
  ///
  /// Null does not mean 1:1 and it never acquires a guessed value (G4).
  /// An uncalibrated plan still locates every drop, which is the Plan
  /// view's first job; it simply yields no lengths.
  PlanScale? scale;

  FracIndex order;
  EntityMeta meta;

  /// The aspect ratio, for fitting a page without stretching it. Known
  /// without decoding, which is the whole reason the two sizes are here.
  double get aspectRatio => pixelWidth / pixelHeight;

  /// True when this plan can yield a length at all.
  bool get isCalibrated => scale?.isUsable ?? false;
}
