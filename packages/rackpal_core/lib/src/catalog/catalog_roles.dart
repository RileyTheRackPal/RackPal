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

import 'package:rackpal_core/src/catalog/catalog_field.dart';
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
/// break every `.rppj` that holds one, to no purpose.
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

/// Every DERIVED bus body, keyed by its variant id (DR-121).
///
/// Never the shipped bus, which is in `buildSeedCatalog()` under the bare
/// id, exactly as [buildSeedRoleVariants] treats the shipped half.
Map<String, TemplateBody> buildSeedBusVariants() => <String, TemplateBody>{
  ...buildFieldBusVariants(),
};

/// The roles [catalogId] offers, shipped half first, or empty when it
/// carries no role parameter.
///
/// EMPTY IS THE ANSWER FOR 48 OF THE 50, and it is a fact rather than a
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

// ═════════════════════════════════════════════════════════════════════
// THE SECOND AXIS: WHICH CONTROL BUS (DR-121)
// ═════════════════════════════════════════════════════════════════════
// P4's table forbids a variant changing *"signal family of any port"* or
// *"connector type"*, and a keypad's bus changes both. DR-121 amends that
// row rather than working around it, on the argument P4 could not have
// made: the seeded catalog is GENERIC. `F13` is not a part number, it is
// "a keypad", and which bus it speaks is a wiring choice on one archetype
// rather than a different product.
//
// WHY NOT `TemplateRole`. That enum is closed and says so: P4 uses the
// role parameter *"exactly twice"*, and both uses are extender halves.
// Adding `cresnet` to it would make that sentence false and would put a
// keypad's bus and an extender's direction on one axis, which are not the
// same kind of fact.
//
// THE COST THIS REMOVES. Before this, a keypad carried every bus it might
// speak as a separate port, so every instance drew three pins for one
// cable. DR-120 §11.119.8 measured it at 32 symbol ops per alternate on
// the 300-link fixture, and the model was worse than the drawing: a real
// keypad has ONE bus.
enum ControlBus {
  /// The shipped half for both keypads, and therefore the one that keeps
  /// the bare catalog id.
  cresnet('cresnet', 'CRESNET', 'ctl.cresnet', 'conn.phoenix_4'),

  lutronQs('qs.link', 'QS LINK', 'ctl.lutron_qs', 'conn.rj45'),

  /// Wago or wire nut onto the bus, so no connector (DR-120 §11.119.4).
  vantage(
    'vantage.link',
    'VANTAGE STATION BUS',
    'ctl.vantage',
    'conn.hardwired',
  );

  const ControlBus(this.portKey, this.label, this.family, this.connector);

  /// THE PORT KEY IS THE BUS'S, NOT A SHARED `bus.link`. `F13` already
  /// shipped `cresnet` and `qs.link` as keys and a document may hold
  /// either, so a rename would move bytes for nothing (CR-117) and would
  /// break `connect_rules_test.dart`'s real-catalog case, which resolves
  /// `portKey: 'cresnet'` on a seeded keypad.
  final String portKey;

  final String label;
  final String family;
  final String connector;
}

/// The template id [bus] places under, for a base catalog id.
///
/// Same shape and same separator as [roleVariantTemplateId], and for the
/// same reasons: the shipped bus keeps the bare id, and `:` is the one
/// punctuation neither a catalog id nor a Device Builder fork produces.
///
/// The two axes cannot collide today because no template carries both.
/// If one ever does, this is where that has to be decided rather than
/// discovered.
String busVariantTemplateId(String catalogId, ControlBus bus) =>
    '$catalogId:${bus.name}';

/// The buses [catalogId] offers, shipped bus first, or empty when it
/// carries no bus parameter.
///
/// TWO ENTRIES, and DR-121 scopes it there: the keypads are the case the
/// cost was measured on. A control device that grows a second bus later
/// registers here rather than accumulating ports.
List<ControlBus> busesFor(String catalogId) => switch (catalogId) {
  'F13' || 'F19' => const [
    ControlBus.cresnet,
    ControlBus.lutronQs,
    ControlBus.vantage,
  ],
  _ => const [],
};

/// The body for [catalogId] on [bus], base or derived, or null when
/// [catalogId] does not offer that bus.
///
/// Null is REACHABLE AND NORMAL, on [resolveTemplateRole]'s reasoning: a
/// caller asking a patch panel for its Vantage half is asking a
/// reasonable question and getting a true answer.
TemplateBody? resolveTemplateBus(
  Map<String, TemplateBody> catalog,
  String catalogId,
  ControlBus bus,
) {
  final buses = busesFor(catalogId);
  if (!buses.contains(bus)) return null;
  if (buses.first == bus) return catalog[catalogId];
  return buildSeedBusVariants()[busVariantTemplateId(catalogId, bus)];
}
