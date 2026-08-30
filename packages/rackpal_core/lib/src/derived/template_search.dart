// What a search box compares a placeable template against (`#244`,
// DR-104 §11.103.5).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE MATCHER, BECAUSE CR-104 IS A RULE ABOUT MORE THAN THE WIDGET
// ═══════════════════════════════════════════════════════════════════════
// `device_palette_panel.dart` held a private `_matchesQuery` reading five
// text fields. M4-O's browser needs the same question answered, and a
// browser whose search understood more than the palette's would be
// CR-104's drift arriving through the matcher instead of through a second
// widget. So it moves here and both surfaces call it.
//
// ═══════════════════════════════════════════════════════════════════════
// A FILTER BOX IS NOT A RESOLVER, AND THE CORPUS ALREADY SAYS SO
// ═══════════════════════════════════════════════════════════════════════
// The obvious build is `resolveSignalFamilyToken(registries, query)`, and
// it is wrong here. That function's own docstring draws the distinction:
//
//   > The SERVICE picker's filter box also has to understand `hbt`, but
//   > it FILTERS where this RESOLVES: `@signal=hdb` must refuse, and
//   > typing `hdb` into the box must show HDBaseT.
//
// The resolver matches a whole token exactly, four ways in. A search box
// must match a PREFIX of one, or it is "a search for people who do not
// need one" (`SignalFamilyCellOption.matches`). So this is the FOURTH
// caller of that vocabulary and the SECOND that filters, and it is built
// the way the filtering one is built: the same fields, joined and
// normalised once, compared with `contains`.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO KEYS, AND THE SPLIT IS WHAT KEEPS THE CHANGE ADDITIVE
// ═══════════════════════════════════════════════════════════════════════
// DR-104 §11.103.5: the palette's search is the subject of an unrun
// stopwatch drill (`#251`), so **no query that matched before may stop
// matching**. [TemplateSearchEntry.plain] is the old comparison exactly,
// lowercase `contains` over the same fields; [TemplateSearchEntry.ports]
// is the new vocabulary under the SERVICE picker's normalisation. A hit
// on either is a match, so the change can only ever widen.
//
// `model` joins the plain key, which `#244` asks for in terms: *"`16x16`
// matches the model string."* It was absent from the five fields, so a
// person typing the number on the front of the box matched nothing.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show normaliseMediaToken;

/// One template, precomputed for a filter box.
///
/// PRE-COMPUTED for `SignalFamilyCellOption`'s reason: a filter runs on
/// every keystroke against every row, and building the key in one place
/// is the only way to be sure two surfaces search by the same rule.
@immutable
final class TemplateSearchEntry {
  const TemplateSearchEntry({required this.plain, required this.ports});

  /// The text fields, lowercased and joined: id, display name, type
  /// prefix, category, tags, **and model**.
  ///
  /// Compared with a bare `contains`, which is what the palette did
  /// before `#244` and must keep doing (DR-104 §11.103.5).
  final String plain;

  /// The port vocabulary: every connector and signal family the template
  /// declares, plus each family's tag, display name and aliases when a
  /// registry was supplied.
  ///
  /// Normalised by [normaliseMediaToken], so whitespace, underscores and
  /// hyphens are gone on both sides of the comparison and `hdb`, `hbt`
  /// and `hd-baset` all reach `video.hdbaset`.
  final String ports;

  /// Whether this row survives a box containing [query].
  ///
  /// **EITHER KEY IS ENOUGH**, and the order is cheapest first.
  bool matches(String query) {
    final plainWant = query.trim().toLowerCase();
    if (plainWant.isEmpty) return true;
    if (plain.contains(plainWant)) return true;
    final portWant = normaliseMediaToken(query);
    return portWant.isNotEmpty && ports.contains(portWant);
  }
}

/// Builds [row]'s entry.
///
/// [registries] is optional and only ever ADDS reach. Without it the port
/// key still holds the raw ids, so `hdbaset` and even `hdb` land on
/// `video.hdbaset` by substring. What a registry buys is the vocabulary
/// that is NOT a substring of the id: `hdbt` is docs/06 §4.1's own
/// spelling and DR-060 §11.59.4 authored it as an alias precisely because
/// it "matched no step of that chain".
TemplateSearchEntry buildTemplateSearchEntry(
  PlaceableTemplate row, {
  Registries? registries,
}) => buildTemplateSearchEntryFor(
  row.id,
  row.body,
  registries: registries,
);

/// [buildTemplateSearchEntry] without a `PlaceableTemplate`, for a caller
/// holding a body and an id directly.
TemplateSearchEntry buildTemplateSearchEntryFor(
  String templateId,
  TemplateBody body, {
  Registries? registries,
}) {
  final plain = <String>[
    templateId,
    body.displayName,
    body.typePrefix ?? '',
    body.category,
    // `#244`'s own example, and it was in none of the five fields.
    body.model,
    body.manufacturer,
    ...body.tags,
  ].join(' ').toLowerCase();

  // A SET, because a 68-port template declares the same family 68 times
  // and a joined string of it would be 68 copies of `video.hdmi.2_0` for
  // one fact. The key is built once per template but held for the life
  // of the list.
  final tokens = <String>{};
  for (final port in body.ports) {
    tokens
      ..add(port.connector.v)
      ..add(port.signalFamily.v);
    for (final f in port.carriedProtocols) {
      tokens.add(f.v);
    }
    if (registries == null) continue;
    if (registries.signalFamilies[port.signalFamily] case final def?) {
      tokens
        ..add(def.shortTag ?? '')
        ..add(def.displayName)
        ..addAll(def.aliases);
    }
    // The connector's DISPLAY NAME is deliberately not added, for
    // `resolveConnectorToken`'s stated reason: connector display names
    // are authored for a table cell (`RJ45 (8P8C)`, `3.5 mm stereo
    // (TRS)`), so they "match almost nothing and occasionally match
    // something absurd". The id carries the word people type.
  }
  return TemplateSearchEntry(
    plain: plain,
    ports: normaliseMediaToken(tokens.join(' ')),
  );
}

/// Every row of [rows] that survives [query], in order.
///
/// A convenience over the entries, for a caller with no index of its own
/// and few enough rows not to want one. A surface that filters on every
/// keystroke should build the entries ONCE and hold them.
List<PlaceableTemplate> searchPlaceableTemplates(
  List<PlaceableTemplate> rows,
  String query, {
  Registries? registries,
}) => [
  for (final row in rows)
    if (buildTemplateSearchEntry(row, registries: registries).matches(query))
      row,
];
