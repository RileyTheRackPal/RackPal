// What a template's occupancy fields imply about each other (DR-203,
// `#951`). Pure Dart; the Device Builder writes what this returns as
// consequences of the edit a person made, inside the same undo entry.
//
// ═════════════════════════════════════════════════════════════════════
// SIX FIELDS, AND A PERSON STATES THREE OF THEM
// ═════════════════════════════════════════════════════════════════════
// CR-036 makes occupancy a struct: `frontU`, `rearU`, `side`,
// `mountMethod`, `widthClass`, `nominalSpanTwelfths`. The builder asked
// for all six, on two sections, and three of them are arithmetic on the
// other three. The user reported the result as data entered more than
// once: a 2U amplifier needed its height on Identity, the same height
// again as `RU height (rear)` on Physical, and then `Occupies` corrected
// by hand, because DR-157 §11.156.5's derivation only ever filled a blank.
// `0U mount` did not light Save until `Occupies` said 0U as well, and
// `Half rack` left `nominalSpanTwelfths` at 12, so the file said half and
// full at once.
//
// So a person says HOW IT MOUNTS, HOW TALL, and HOW WIDE, and the rest is
// [derivedOccupancy]. The seeded catalog is the check that the derivation
// is the trade's and not ours: every one of its rack-ear, hosted, 0U and
// field templates already satisfies it.
//
// ═════════════════════════════════════════════════════════════════════
// WHICH MOUNTS TAKE RACK UNITS IS TRADE KNOWLEDGE, AND IT WAS ASKED
// ═════════════════════════════════════════════════════════════════════
// Rack ears, a shelf and a rear rail put a device in the rails' height.
// A 0U mount, a card hosted in another device, and gear that is not in a
// rack take none. **Side-mounted and in-furniture gear take none either**,
// which is the user's answer on 2026-09-29 to a question put rather than
// guessed (DR-203 §11.202.4).
import 'package:rackpal_core/src/model/template.dart';

/// Whether a device mounted this way occupies rack units (DR-203
/// §11.202.4).
bool mountTakesRackUnits(MountMethod mount) => switch (mount) {
  MountMethod.rackEars || MountMethod.shelf || MountMethod.rearRail => true,
  MountMethod.zeroU ||
  MountMethod.sideMount ||
  MountMethod.furniture ||
  MountMethod.hosted ||
  MountMethod.notInRack => false,
};

/// The span in twelfths of a rack a width class stands for, or null for
/// [WidthClass.customWidth], whose span is the one a person types
/// (CR-030: half-rack is a class PLUS a span, so a custom width still
/// needs its number).
int? twelfthsForWidth(WidthClass width) => switch (width) {
  WidthClass.full => 12,
  WidthClass.half => 6,
  WidthClass.third => 4,
  WidthClass.quarter => 3,
  WidthClass.customWidth => null,
};

/// The occupancy [body]'s mount, heights and width imply.
///
/// **A mount that takes no rack units has zero height by definition**, so
/// its heights come back 0 and its side is `zeroUVertical` for a 0U mount
/// and `none` otherwise. That is not tidiness: `{frontU: 2, side: none}`
/// is the body DR-157 refuses to place, and switching a 2U device to
/// `Hosted` would otherwise leave exactly that behind.
///
/// A mount that does take rack units derives its side from its heights,
/// which is the reading DR-157 §11.156.5 already made of a typed front
/// height, now made of both heights every time rather than of a blank.
({int frontU, int rearU, OccupancySide side, int nominalSpanTwelfths})
derivedOccupancy(TemplateBody body) {
  final span = twelfthsForWidth(body.widthClass) ?? body.nominalSpanTwelfths;
  if (!mountTakesRackUnits(body.mountMethod)) {
    return (
      frontU: 0,
      rearU: 0,
      side: body.mountMethod == MountMethod.zeroU
          ? OccupancySide.zeroUVertical
          : OccupancySide.none,
      nominalSpanTwelfths: span,
    );
  }
  final f = body.frontU;
  final r = body.rearU;
  return (
    frontU: f,
    rearU: r,
    side: f > 0 && r > 0
        ? OccupancySide.both
        : f > 0
        ? OccupancySide.front
        : r > 0
        ? OccupancySide.rear
        : OccupancySide.none,
    nominalSpanTwelfths: span,
  );
}

/// Whether [body]'s occupancy was MEANT, which is AC-049's third required
/// fact (DR-203 §11.202.5).
///
/// A rack mount means it with a height, front or rear: a rear lacing bar
/// is `{front: 0, rear: 1}` in docs/06 §3.2's own words and was refused by
/// a front-only check. Every other mount means a zero by being chosen,
/// the way `notInRack` already did (DR-107 §11.106.2): a hosted card has
/// no height to state. `zeroUVertical` stays admitted for a body written
/// before its mount method said 0U.
bool hasMeantOccupancy(TemplateBody body) =>
    !mountTakesRackUnits(body.mountMethod) ||
    body.frontU > 0 ||
    body.rearU > 0 ||
    body.side == OccupancySide.zeroUVertical;
