// rackpal_core/src/derived/jumper_rollup.dart, pure Dart.
//
// AC-026: "Jumpers roll up into the materials list by media + length +
// colour." docs/08 §2.2 puts the rollup on `T6.30` (M6-F4, `#339`). This
// computes and never draws.
//
// ═══════════════════════════════════════════════════════════════════════
// FROM THE SCHEDULE'S ROWS, ON `cable_footage.dart`'S REASONING
// ═══════════════════════════════════════════════════════════════════════
// `cableFootageOf` counts the jumpers and power cords it EXCLUDES from the
// spool order, from `buildSchedule`'s rows. This counts the same rows the
// other way round, so the footage note's "4 jumpers and 2 power cords,
// bought by the piece" and this table's quantities are one number read
// twice and cannot disagree.
//
// ═══════════════════════════════════════════════════════════════════════
// A POWER CORD IS BOUGHT LIKE A JUMPER, AND THE MEDIA TELLS THEM APART
// ═══════════════════════════════════════════════════════════════════════
// Both classes are counted here, grouped by MEDIA, and the media name is
// what tells an IEC cord from a Cat6 patch lead. The classifier has
// produced `powerCord` since DR-233 (`#908`), for IEC and NEMA ports in or
// out of a rack; before that a cord was a `jumper` in one rack and missed
// this table entirely when it ran to a wall. A low-voltage DC lead inside
// one rack is still a `jumper` (§11.232.2) and lands here by that road.
//
// ═══════════════════════════════════════════════════════════════════════
// COLOUR IS AS BUILT, AND UNSTATED IS ITS OWN GROUP
// ═══════════════════════════════════════════════════════════════════════
// "Colour matters here because it is how the installer finds the right
// one in the bag" (`#339`). The as-built colour is what is in the bag: the
// pulled exception when one was recorded, otherwise the convention. A
// lead with no colour stated groups as unstated rather than borrowing a
// colour it does not have (G4), and so does one with no length.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/model/jacket_color.dart' show JacketColorDef;
import 'package:rackpal_core/src/model/link.dart' show LinkClass;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart' show MediaTypeDef;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// One line of the rollup: a quantity of one media at one length in one
/// colour.
@immutable
final class JumperLine {
  const JumperLine({
    required this.mediaId,
    required this.media,
    required this.length,
    required this.colour,
    required this.colourId,
    required this.quantity,
  });

  final MediaTypeId mediaId;

  /// Null when the document names a media type it does not carry; the
  /// line still prints, by id.
  final MediaTypeDef? media;

  /// Null when no length is stated: its own group, never a guessed one.
  final Len? length;

  /// The as-built colour, or null when none is stated.
  final JacketColorDef? colour;

  /// The registry key [colour] was found under, null with it. Carried
  /// because `JacketColorDef` holds no id of its own, and two colours may
  /// share a display name.
  final JacketColorId? colourId;

  final int quantity;
}

/// AC-026's rollup: every jumper and power cord, grouped.
@immutable
final class JumperRollup {
  const JumperRollup(this.lines);

  /// Ordered by media name, then length (unstated last), then colour name
  /// (unstated last), then ids: a TOTAL order with no `Map` iteration in
  /// it, so two builds of one document print one table.
  final List<JumperLine> lines;

  int get quantity => lines.fold(0, (n, l) => n + l.quantity);

  /// How many leads have no stated length.
  int get noLengthCount =>
      lines.where((l) => l.length == null).fold(0, (n, l) => n + l.quantity);

  bool get isEmpty => lines.isEmpty;
}

/// [schedule]'s jumpers and power cords, by media, length and colour.
JumperRollup jumperRollupOf(Schedule schedule) {
  final counts = <(MediaTypeId, int?, String?), int>{};
  final media = <MediaTypeId, MediaTypeDef?>{};
  final colours = <String, JacketColorDef>{};
  for (final row in schedule.rows) {
    if (row.linkClass != LinkClass.jumper &&
        row.linkClass != LinkClass.powerCord) {
      continue;
    }
    final colourId = row.jacketColor.asBuiltColorId;
    final colour = row.jacketColor.asBuilt;
    if (colourId != null && colour != null) colours[colourId.v] = colour;
    media[row.mediaId] = row.media;
    // A DANGLING COLOUR ID GROUPS AS UNSTATED: there is no name to print,
    // and inventing one is the thing G4 forbids.
    final key = (
      row.mediaId,
      row.length?.nm,
      colour == null ? null : colourId?.v,
    );
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final lines =
      <JumperLine>[
        for (final MapEntry(key: (id, nm, colourId), value: n)
            in counts.entries)
          JumperLine(
            mediaId: id,
            media: media[id],
            length: nm == null ? null : Len(nm),
            colour: colourId == null ? null : colours[colourId],
            colourId: colourId == null ? null : JacketColorId(colourId),
            quantity: n,
          ),
      ]..sort((a, b) {
        final byName = (a.media?.displayName ?? a.mediaId.v).compareTo(
          b.media?.displayName ?? b.mediaId.v,
        );
        if (byName != 0) return byName;
        final byId = a.mediaId.v.compareTo(b.mediaId.v);
        if (byId != 0) return byId;
        final al = a.length?.nm;
        final bl = b.length?.nm;
        if (al != bl) {
          if (al == null) return 1;
          if (bl == null) return -1;
          return al.compareTo(bl);
        }
        final ac = a.colour;
        final bc = b.colour;
        if (ac == null || bc == null) {
          if (ac == bc) return 0;
          return ac == null ? 1 : -1;
        }
        final byColour = ac.displayName.compareTo(bc.displayName);
        if (byColour != 0) return byColour;
        // TWO COLOURS MAY SHARE A NAME, so the id ends the chain.
        return a.colourId!.v.compareTo(b.colourId!.v);
      });
  return JumperRollup(List.unmodifiable(lines));
}

/// AC-026's rollup for [doc].
JumperRollup buildJumperRollup(RackDocument doc) =>
    jumperRollupOf(buildSchedule(doc));
