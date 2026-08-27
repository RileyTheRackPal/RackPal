// rackpal_core/src/structure/csv_header_map.dart — pure Dart.
//
// THE SHIPPED SYNONYM TABLE, AND THE CAP IS THE DELIVERABLE. Board M3-F/1
// (#159), docs/07 §5.1, RJ-004.
//
// ═════════════════════════════════════════════════════════════════════
// THE ROADMAP NAMES THIS FEATURE AS M3'S SCOPE HAZARD, BY NAME
// ═════════════════════════════════════════════════════════════════════
// roadmap §4, M3's Risks, verbatim: "CSV synonym mapping is an
// INFINITE-TAIL feature; cap it at the shipped synonym table and let
// unmapped columns fall through to a manual assign step."
//
// That is the design and not a simplification of it. There is NO fuzzy
// matching here, no edit distance, no stemming, no learning step and no
// per-project synonym store. [matchCsvHeader] answers from this table or
// answers null, and `csv_header_map_test.dart` fails if it ever answers
// for a header the table does not contain. **The gate is the feature**:
// without it the table grows one plausible-looking entry at a time until
// somebody is maintaining a natural-language parser for spreadsheet
// column names.
//
// ═════════════════════════════════════════════════════════════════════
// MEDIA IS NOT IN THIS TABLE, AND THAT IS DELIBERATE
// ═════════════════════════════════════════════════════════════════════
// docs/07 §5.1 lists media synonyms (`cat6 / cat-6 / c6 / cat6 utp`, and
// so on) beside the column synonyms, and it is easy to read that as one
// table. They are two different questions:
//
//   * WHICH COLUMN is this? — a fixed set of canonical targets, capped
//     here, identical in every project.
//   * WHICH MEDIA TYPE is this CELL? — open by design, per document, and
//     ALREADY SHIPPED AS DATA: `MediaTypeDef.aliases` carries exactly the
//     tokens §5.1 lists, seeded at `seed_media_types.dart` (DR-010), and
//     RJ-009 lets a shop add its own.
//
// So cell-level media resolution reads the DOCUMENT'S registry and must
// not be duplicated here. A second hard-coded copy would answer for a
// media type the project does not carry, and would go stale the first
// time somebody added one.
//
// ═════════════════════════════════════════════════════════════════════
// NORMALISATION IS EXACTLY THE FOUR TRANSFORMS §5.1 STATES
// ═════════════════════════════════════════════════════════════════════
// "case-, space-, underscore- and hyphen-insensitive". Four, and no
// more. See [normaliseCsvHeader] for the one consequence that is worth
// knowing about before it surprises somebody.

/// Every column §5.1 can map a header onto.
///
/// THE CANONICAL TARGET, not the field. Several of these land somewhere
/// non-obvious and the doc comments say where, because the mapping sheet
/// shows this name to a person and the importer has to put the value
/// somewhere specific.
enum CsvColumnTarget {
  /// → `Location`, matched by name then code (§5.3). REQUIRED.
  location,

  /// → `Location.floorNumber`.
  floor,

  /// → the building, which this model does not carry as an entity; the
  /// importer folds it into the location match's scope.
  building,

  /// → `Outlet.designation`.
  outlet,

  /// → `StructureOrigin.fieldLabel`. Unique project-wide (CR-113).
  fieldLabel,

  /// → `StructureOrigin.rackLabel`. Optional, unique where set.
  rackLabel,

  /// → `MediaTypeId`, resolved against the DOCUMENT'S registry aliases
  /// and not against anything in this file. REQUIRED in the long shape.
  media,

  /// How many drops this row is. Absent means one.
  qty,

  /// → the label's `{SERVICE}` token (DR-023).
  service,

  /// → `SignalFamilyId`.
  signal,

  /// → `Pathway.name`, matched project-wide (§5.3).
  ///
  /// NOT `Pathway.designator`. DR-026 §11.25.1 keeps the two apart, and a
  /// contractor's `Bundle` column is a description of where a group of
  /// runs goes, which is what `name` is for.
  pathway,

  /// → `Link.routedLength`.
  routedLength,

  /// → `PlaceEndpoint.intendedTermination` at the RACK end, where that
  /// end is still a place. §5.1's note: a `PortEndpoint` carries no
  /// termination type because the panel port is the source of truth, so
  /// the column is dropped with an import note there.
  rackTermination,

  /// → `StructureOrigin.terminationField`, the wall-plate end.
  terminationField,

  /// → `Link.roughInStatus`.
  roughInStatus,

  /// → `Link.jacketColorId`. The CONVENTION side: what the run IS.
  jacketColor,

  /// → `Link.jacketColorPulledId`. The EXCEPTION side: what was actually
  /// pulled. Imports independently of [jacketColor] and is never promoted
  /// into it (§5.1's note, G4).
  jacketColorPulled,

  /// → `Link.notes`.
  notes,
}

/// docs/07 §5.1's table, verbatim, and **nothing else may be added
/// without amending that section.**
///
/// Keys are already normalised by [normaliseCsvHeader] so the matcher
/// does no work at lookup time and so a malformed entry here fails the
/// table's own consistency test rather than silently never matching.
const Map<String, CsvColumnTarget> kCsvHeaderSynonyms = {
  // location — REQUIRED
  'location': CsvColumnTarget.location,
  'room': CsvColumnTarget.location,
  'area': CsvColumnTarget.location,
  'zone': CsvColumnTarget.location,
  'space': CsvColumnTarget.location,
  'destination': CsvColumnTarget.location,

  'floor': CsvColumnTarget.floor,
  'level': CsvColumnTarget.floor,
  'story': CsvColumnTarget.floor,

  'building': CsvColumnTarget.building,
  'site': CsvColumnTarget.building,

  'outlet': CsvColumnTarget.outlet,
  'plate': CsvColumnTarget.outlet,
  'jack': CsvColumnTarget.outlet,
  'wallplate': CsvColumnTarget.outlet,
  'wallplateid': CsvColumnTarget.outlet,
  'box': CsvColumnTarget.outlet,

  'label': CsvColumnTarget.fieldLabel,
  'identifier': CsvColumnTarget.fieldLabel,
  'tag': CsvColumnTarget.fieldLabel,
  'cablelabel': CsvColumnTarget.fieldLabel,
  'dropid': CsvColumnTarget.fieldLabel,
  'cableid': CsvColumnTarget.fieldLabel,
  'runid': CsvColumnTarget.fieldLabel,
  // Survives normalisation intact: `#` contains none of the four
  // characters the four transforms remove. See [normaliseCsvHeader].
  '#': CsvColumnTarget.fieldLabel,

  'tiaid': CsvColumnTarget.rackLabel,
  'tia606': CsvColumnTarget.rackLabel,
  'racklabel': CsvColumnTarget.rackLabel,
  'panelid': CsvColumnTarget.rackLabel,

  // media — REQUIRED in the long shape. The CELL is resolved against the
  // document's registry aliases; only the HEADER is matched here.
  'media': CsvColumnTarget.media,
  'cabletype': CsvColumnTarget.media,
  'type': CsvColumnTarget.media,
  'wire': CsvColumnTarget.media,
  'cable': CsvColumnTarget.media,

  'qty': CsvColumnTarget.qty,
  'quantity': CsvColumnTarget.qty,
  'count': CsvColumnTarget.qty,
  'ea': CsvColumnTarget.qty,
  'number': CsvColumnTarget.qty,

  'service': CsvColumnTarget.service,
  'use': CsvColumnTarget.service,
  'purpose': CsvColumnTarget.service,
  'function': CsvColumnTarget.service,
  'application': CsvColumnTarget.service,

  'signal': CsvColumnTarget.signal,

  'bundle': CsvColumnTarget.pathway,
  'bundleid': CsvColumnTarget.pathway,
  'run': CsvColumnTarget.pathway,
  'group': CsvColumnTarget.pathway,
  'homerun': CsvColumnTarget.pathway,
  'conduit': CsvColumnTarget.pathway,
  'raceway': CsvColumnTarget.pathway,
  'pathway': CsvColumnTarget.pathway,

  'length': CsvColumnTarget.routedLength,
  'lengthft': CsvColumnTarget.routedLength,
  'footage': CsvColumnTarget.routedLength,
  'ft': CsvColumnTarget.routedLength,
  'len': CsvColumnTarget.routedLength,

  'terminationrack': CsvColumnTarget.rackTermination,
  'rackend': CsvColumnTarget.rackTermination,
  'panel': CsvColumnTarget.rackTermination,
  'panelport': CsvColumnTarget.rackTermination,
  'headend': CsvColumnTarget.rackTermination,

  'terminationfield': CsvColumnTarget.terminationField,
  'deviceend': CsvColumnTarget.terminationField,
  'fieldend': CsvColumnTarget.terminationField,
  'farend': CsvColumnTarget.terminationField,

  'status': CsvColumnTarget.roughInStatus,
  'state': CsvColumnTarget.roughInStatus,
  'phase': CsvColumnTarget.roughInStatus,

  'jacket': CsvColumnTarget.jacketColor,
  'color': CsvColumnTarget.jacketColor,
  'colour': CsvColumnTarget.jacketColor,
  'jacketcolor': CsvColumnTarget.jacketColor,

  'colorpulled': CsvColumnTarget.jacketColorPulled,
  'colourpulled': CsvColumnTarget.jacketColorPulled,
  'jacketcolorpulled': CsvColumnTarget.jacketColorPulled,
  'actualcolor': CsvColumnTarget.jacketColorPulled,
  'aspulled': CsvColumnTarget.jacketColorPulled,

  'notes': CsvColumnTarget.notes,
  'comments': CsvColumnTarget.notes,
  'remarks': CsvColumnTarget.notes,
  'note': CsvColumnTarget.notes,
};

/// §5.1's normalisation: **case, space, underscore and hyphen**, and
/// nothing else.
///
/// FOUR TRANSFORMS, COUNTED, because every additional one is a heuristic
/// wearing normalisation's clothes. Stripping a parenthesised unit so
/// that `Length (ft)` reaches `lengthft` is not a fifth transform of the
/// same kind: it is a guess that `(ft)` is decoration rather than part of
/// the name, and the next request is `Length [m]`, and the one after that
/// is `Length - metres`.
///
/// **THE CONSEQUENCE, NAMED BEFORE IT SURPRISES SOMEBODY.** docs/07
/// §5.2's own example carries `Length (ft)`, which therefore does NOT
/// match and falls through to the manual assign step (M3-F/2). That is
/// the designed outcome rather than a miss: an unmapped column is a
/// question put to the operator once, it is answered in one click, and
/// the answer is not silently discarded (G4, docs/04 §3.4). Widening the
/// table or the normaliser to swallow it is exactly the tail RJ-004
/// capped.
String normaliseCsvHeader(String header) => header
    .toLowerCase()
    .replaceAll(' ', '')
    .replaceAll('_', '')
    .replaceAll('-', '');

/// The canonical target for [header], or **null when the table does not
/// contain it**.
///
/// NULL IS AN ANSWER AND NOT A FAILURE. It routes the column to the
/// manual assign step, which is the other half of the cap and the thing
/// that makes the cap survivable.
CsvColumnTarget? matchCsvHeader(String header) =>
    kCsvHeaderSynonyms[normaliseCsvHeader(header)];

/// The targets a long-shape import cannot proceed without (§5.1's
/// `Req.` column).
///
/// `media` is required **in the long shape only**: the wide shape carries
/// media in its headers rather than in a column, which is what makes it a
/// different shape rather than a different parser.
const Set<CsvColumnTarget> kRequiredLongShapeTargets = {
  CsvColumnTarget.location,
  CsvColumnTarget.media,
};
