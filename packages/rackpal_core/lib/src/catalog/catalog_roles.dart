// P4's `role` parameter — the one variant axis that changes a template's
// PORTS, and therefore the one that could not be left to a picker.
//
// ═════════════════════════════════════════════════════════════════════
// A VARIANT IS NOT A TEMPLATE, AND THIS FILE EXISTS TO KEEP THAT TRUE
// ═════════════════════════════════════════════════════════════════════
// docs/catalog/seed-devices.md P4: *"A parametric template ships once and
// presents preset sizes in the picker"*, and its rejected alternative is
// named in as many words: *"four separate templates, which spends four of
// thirty rack-side slots on two products."* §540 repeats it for V06
// specifically: *"Rejected alternative: separate `TX` and `RX`
// templates."*
//
// So `buildSeedCatalog()` still returns **one body per template id**, and
// `seed_catalog_test.dart`'s count and category split are untouched by
// everything here. A role variant is DERIVED, on demand, under an id of
// its own, and never appears in the catalog map.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THE PARAMETER SHIPS NOW WHEN THE PICKER DOES NOT
// ═════════════════════════════════════════════════════════════════════
// `seed_catalog.dart` puts *"picking a size in the palette/Device Builder
// out of scope for this stage (M4)"*, and that stays true: nothing here
// is a picker. What forced the parameter itself is `SIG-001`'s remedy.
// CR-015 says `[ Insert HDBaseT receiver ]` inserts a **device**, and
// docs/05 §5 says it *"creates both links in one undo step"* — so it must
// MINT a receiver, and until this file there was none to mint.
//
// The two halves are not a mechanical direction flip and cannot be
// derived from their bases. §540's receiver drops `HDMI IN` outright and
// renames `HDMI LOOP OUT` to `HDMI OUT`: seven ports become six. P4's
// summary says the halves *"differ only in port direction"*, which is the
// general rule reading loosely; §540 is the specific spec and it governs,
// so these bodies are TRANSCRIBED from it rather than computed.
//
// ═════════════════════════════════════════════════════════════════════
// NO NEW BYTE SURFACE (CR-117), WHICH IS WHY THE ID CARRIES THE ROLE
// ═════════════════════════════════════════════════════════════════════
// A placed device snapshots its whole `TemplateBody` into the document
// (AC-041 copy-on-place), and `templateKey` is `'$templateId@$version'`.
// Two variants of `V06` under one id would collide on that key, so the
// variant gets its own id and the document needs no `role` field at all:
// the snapshot it already stores IS the resolved half. Nothing in the
// codec moves, and `write(read(bytes)) == bytes` is unaffected.

import 'package:rackpal_core/src/catalog/catalog_video.dart';
import 'package:rackpal_core/src/model/template.dart';

/// The endpoint roles P4 admits, and the only ones.
///
/// P4's table allows a role parameter on *"an extender kit sold as one
/// part number"* and names its two uses: **HDBaseT Extender TX/RX** and
/// **AVoIP Endpoint ENC/DEC**. The enum is closed for that reason rather
/// than for tidiness: a third role would be a third product shape, and
/// P4 says the parameter is used *"exactly twice"*.
enum TemplateRole {
  /// V06's shipped half.
  transmitter('TX'),

  /// V06's derived half — the one `SIG-001`'s remedy inserts.
  receiver('RX'),

  /// V07's shipped half.
  encoder('ENC'),

  /// V07's derived half.
  decoder('DEC');

  const TemplateRole(this.typePrefix);

  /// The designator prefix this half allocates under (§3.10's table gives
  /// `TX` / `RX` and `ENC` / `DEC` as a pair per template).
  final String typePrefix;
}

/// The template id [role] places under, for a base catalog id.
///
/// THE BASE ROLE KEEPS THE BARE ID. `V06` stays `V06`, because it is what
/// the catalog ships and what every existing document already references;
/// only the derived half takes a suffix. Renaming the shipped half would
/// break every `.rmpj` that holds one, to no purpose.
///
/// The separator is `:` and not `.` or `-`, because catalog ids are
/// `[A-Z]\d\d` and template ids from a Device Builder fork are free text:
/// a colon is the one punctuation neither produces, so a variant id can
/// never collide with either.
String roleVariantTemplateId(String catalogId, TemplateRole role) =>
    '$catalogId:${role.name}';

/// Every DERIVED role half the seed catalog defines, keyed by its variant
/// id — never the shipped halves, which are in `buildSeedCatalog()`.
///
/// Two entries, which is P4's *"exactly twice"* made countable.
Map<String, TemplateBody> buildSeedRoleVariants() => <String, TemplateBody>{
  ...buildVideoRoleVariants(),
};

/// The roles [catalogId] offers, shipped half first, or empty when it
/// carries no role parameter.
///
/// EMPTY IS THE ANSWER FOR 46 OF THE 48, and it is a fact rather than a
/// fallback: P4 lists the parameter's two uses exhaustively.
List<TemplateRole> rolesFor(String catalogId) => switch (catalogId) {
  'V06' => const [TemplateRole.transmitter, TemplateRole.receiver],
  'V07' => const [TemplateRole.encoder, TemplateRole.decoder],
  _ => const [],
};

/// The body for [catalogId] in [role], base or derived, or null when
/// [catalogId] does not offer that role.
///
/// Null is REACHABLE AND NORMAL rather than an error: a caller asking a
/// patch panel for its decoder half is asking a reasonable question and
/// getting a true answer.
TemplateBody? resolveTemplateRole(
  Map<String, TemplateBody> catalog,
  String catalogId,
  TemplateRole role,
) {
  final roles = rolesFor(catalogId);
  if (!roles.contains(role)) return null;
  // The FIRST role listed is the one the catalog ships; everything else
  // is derived. Reading the order rather than naming the shipped half a
  // second time here is what keeps [rolesFor] the single statement of
  // which half is which.
  if (roles.first == role) return catalog[catalogId];
  return buildSeedRoleVariants()[roleVariantTemplateId(catalogId, role)];
}
