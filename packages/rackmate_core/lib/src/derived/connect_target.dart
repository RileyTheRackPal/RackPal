// One device plus one port key, joined to everything a connect gesture
// needs before it can decide anything at all.
//
// ═════════════════════════════════════════════════════════════════════
// THIS JOIN DID NOT EXIST, AND EVERY CALLER DR-011 ADDS NEEDS IT
// ═════════════════════════════════════════════════════════════════════
// `resolvePortSet` (port_set_resolution.dart) answers "which ports are in
// this SET", which is the atomicConnect question. DR-011.2 rules that the
// gesture is PIN-TO-PIN — 223 of the catalog's 257 ports carry no
// `setKey` at all, so no HDMI, RJ45, IR or outlet port is reachable
// set-to-set — and nothing in the tree could answer "what IS this one
// pin": not its direction, not its signal family, not its
// `maxConnections`, not whether the document has materialised it yet.
//
// ═════════════════════════════════════════════════════════════════════
// [ConnectTarget.portId] IS ALWAYS PRESENT, AND THAT IS THE POINT
// ═════════════════════════════════════════════════════════════════════
// `derivePortId` is a pure UUIDv5 over `(deviceId, portKey)` (CR-116,
// AC-006), so the id a pin WILL have is knowable before the pin exists.
// DR-011.1 rules that ports are materialised inside the connect command's
// `apply()`, planned from `derivePortId` directly — because nothing in
// the app ever writes `doc.ports` today (the only `doc.ports[id] = Port`
// in the repository is in `apps/rackmate/tool/starters/authoring.dart`, a
// TOOL), so a document built by dropping devices out of the palette has
// no materialised ports and a plan that required them would be empty on
// every real document.
//
// So this type separates two questions that look like one:
//   * [portId]           — the id this pin HAS or WILL have. Always known.
//   * [materialisedPort] — whether the document holds one TODAY.
//
// A caller that conflates them either refuses every legal connect (if it
// demands materialisation) or writes a `PortEndpoint` at an id nothing
// resolves (if it ignores it). Both have shipped in other codebases; the
// pair below is what makes neither expressible.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// One end of a prospective connection: a pin on a device, resolved
/// against the document and its template snapshot.
///
/// A SNAPSHOT, not a live view. Every field is read once by
/// [resolveConnectTarget] and never re-derived, so a `ConnectTarget` held
/// across a document mutation describes the document as it was. That is
/// deliberate — `evaluateConnect` re-reads the document for the facts that
/// can move (the live conductor count, the device's continued existence)
/// and takes the rest from here.
@immutable
final class ConnectTarget {
  const ConnectTarget({
    required this.deviceId,
    required this.deviceDesignator,
    required this.def,
    required this.portId,
    required this.materialisedPort,
    this.plannedDesignator,
  });

  final Uuid deviceId;

  /// `DeviceInstance.designator` — "AVR-1". Captured here so a refusal
  /// sentence can name the device even after it has left the document.
  final String deviceDesignator;

  /// The template's declaration of this pin. The source of truth for
  /// everything physical about it.
  final PortDef def;

  /// `derivePortId(deviceId, def.key)` — the id this pin HAS if
  /// [materialisedPort] is non-null, and the id it WILL have if a connect
  /// command materialises it. Never null; see the file header.
  final Uuid portId;

  /// The `Port` the document holds for [portId], or NULL when the document
  /// has never materialised this pin.
  ///
  /// Null is the OVERWHELMINGLY NORMAL case on a real document (AC-006:
  /// ports exist only once they carry project state), not a defect.
  final Port? materialisedPort;

  /// The designator this pin WILL be given the moment a connect
  /// materialises it — `allocatePortDesignator`'s answer, computed at
  /// resolve time — or null when [materialisedPort] already has one, or
  /// when the project's `portDesignatorFormat` cannot render one at all.
  ///
  /// IT IS NOT A FABRICATION, WHICH IS WHY IT MAY BE NAMED IN A SENTENCE.
  /// `PORT_SEQ` is the pin's position in its template's declared order
  /// (`templatePortSeq`), not a running count, and the allocation is a
  /// pure function of the document — so the `J03` a refusal prints is the
  /// same `J03` the connect would have written had it been allowed. What
  /// G4 forbids is inventing an identifier; this one is derived and
  /// deterministic.
  final String? plannedDesignator;

  PortKey get portKey => def.key;

  /// `PortDef.setKey` — the `PortSetDef` this pin belongs to
  /// electrically, or null when it belongs to none. Null for 223 of the
  /// catalog's 257 ports, which is why DR-011.2 makes the gesture
  /// pin-to-pin and reserves the set-to-set gesture for
  /// `atomicConnect: true` sets.
  String? get setKey => def.setKey;

  PortDirection get direction => def.direction;
  SignalFamilyId get signalFamily => def.signalFamily;

  /// Whether this pin is a tap on a shared medium rather than one end of
  /// a point-to-point run.
  ///
  /// TWO WAYS A TEMPLATE CAN SAY IT, AND BOTH ARE READ. `PortDirection
  /// .busNode` is the catalog notation's `BUS` — docs/catalog/seed-devices
  /// .md §2.2: *"a node on a shared multi-drop medium (Cresnet, DMX thru,
  /// RS-485, CV speaker tap)"* — and it is the one the eight bus ports in
  /// the seed catalog actually carry. `PortTopology.multidrop` is the
  /// field design-data-model.md:462 defines for the same fact; no seed
  /// port sets it today (every one takes `PortDef`'s `p2p` default) but a
  /// template authored in M4 may, and a pin that says `multidrop` must
  /// not need `busNode` beside it to be believed.
  ///
  /// `PortTopology.star` is deliberately NOT here. A star is a hub-and-
  /// spoke fabric whose CENTRE is a device, not a jack; nothing in the
  /// corpus says a star port takes more than one cable, and TOP-003 has
  /// no override to walk back a bound relaxed on a guess.
  bool get isMultidrop =>
      def.direction == PortDirection.busNode ||
      def.topology == PortTopology.multidrop;

  /// `TOP-003`'s bound — the pin's EFFECTIVE `maxConnections`. **NULL
  /// MEANS UNBOUNDED**, which is a bus tap and not an error.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// "EFFECTIVE" IS NOT "DECLARED", AND THE SEED CATALOG IS THE PROOF
  /// ═══════════════════════════════════════════════════════════════════
  /// docs/02 §5.1 words `TOP-003` as *"a port's live conductor count may
  /// not exceed its effective `maxConnections`"*, and reading `effective`
  /// as `declared` is not a simplification — it is wrong on real data.
  /// **Not one of the seed catalog's ports declares `maxConnections`**:
  /// `PortBuilder.p` (catalog_ports.dart) never passes it, so all of them
  /// take `PortDef`'s default of `1`. Eight of them are declared
  /// `PortDirection.busNode`, and a Cresnet drop or a 70 V tap whose
  /// bound is one connection is not a bus at all — A05's own catalog note
  /// reads *"a constant-voltage BUS output, not OUT (a 70V run is a
  /// multi-tap bus)"*. Under a declared-is-effective reading, a
  /// two-keypad Cresnet bus and a two-pendant 70 V run are both
  /// model-ILLEGAL, and DR-011.5 gives T1 no `[ Connect anyway ]` to
  /// escape with. That is the product refusing to draw the system it
  /// ships a catalog for.
  ///
  /// WHY A DECLARED `> 1` STILL WINS ON A BUS PIN. `2` on an IR emitter
  /// output (docs/catalog/seed-devices.md's `ir.out.1`) is a real,
  /// authored bound and this must not widen it to infinity. Only the
  /// DEFAULT `1` — the value a template reaches by saying nothing —
  /// yields to the bus fact, because on a `busNode` pin that `1` is the
  /// absence of a statement rather than one.
  ///
  /// A declared `<= 0` is returned untouched, bus or not: `0` is the one
  /// value a template can only have meant on purpose, and `TOP-003` reads
  /// it as "not a socket".
  ///
  /// PER-INSTANCE OVERRIDES STILL DO NOT EXIST. `PortOverrides`
  /// (port.dart) carries label/connector/signalFamily and nothing else,
  /// so there is no instance-level number to prefer yet. When there is,
  /// it lands here and `TOP-003` follows without edit.
  int? get effectiveMaxConnections {
    final declared = def.maxConnections;
    if (declared != 1) return declared;
    return isMultidrop ? null : 1;
  }

  bool get isMaterialised => materialisedPort != null;

  /// What a sentence should CALL this pin.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE J-NUMBER IS COMPUTED, NOT WAITED FOR
  /// ═══════════════════════════════════════════════════════════════════
  /// DR-011.5 requires *"a user-facing sentence naming the real
  /// designators — 'AVR-1 J03 already carries 1 of 1 connections', not a
  /// generic string"*, and the pin a refusal is about is almost always
  /// UNMATERIALISED: ports exist only once they carry project state
  /// (AC-006), so every pin on a device dropped from the palette has no
  /// `Port.designator` yet. `TOP-001` — dropping the wire back on the pin
  /// you picked it up from — is the most reachable refusal in the
  /// product, and it fires on exactly those pins.
  ///
  /// So the fallback order is:
  ///
  ///   1. the materialised `Port.designator` — project state, and the
  ///      only value the user may have edited;
  ///   2. [plannedDesignator] — the designator this pin will be given the
  ///      instant it IS materialised, from the same allocator the connect
  ///      command uses. Deterministic, not invented;
  ///   3. `PortDef.designatorHint`. **ZERO of the 727 seed ports carry
  ///      one** — `PortBuilder.p` never passes it — so this branch is for
  ///      hand-authored and imported templates only, and it is reached
  ///      only when (2) could not render;
  ///   4. `PortDef.label` — "IR OUT 3", the silkscreen. A person can find
  ///      that on the back of the box;
  ///   5. the raw port key, which is a machine join and the last thing to
  ///      put in front of a user.
  String get portDesignator =>
      materialisedPort?.designator ??
      plannedDesignator ??
      def.designatorHint ??
      (def.label.trim().isEmpty ? def.key.v : def.label);

  /// "AVR-1 J03" — how canon cites a port (CR-042: "a port is always cited
  /// as `MTX-1:J09`", rendered with a space here because these strings are
  /// read in a sentence, not in a schedule cell).
  String get citation => '$deviceDesignator $portDesignator';
}

/// Joins [deviceId] and [portKey] against [doc], or `null` when the
/// device, its template snapshot, or the port key itself does not resolve.
///
/// `null` means "there is no such pin", which is a DIFFERENT answer from
/// "there is such a pin and the document has not materialised it" — the
/// latter returns a `ConnectTarget` with a null [ConnectTarget
/// .materialisedPort]. A caller that treats the two alike either invents a
/// port id or refuses every connect on a freshly-placed device.
ConnectTarget? resolveConnectTarget(
  RackDocument doc, {
  required Uuid deviceId,
  required String portKey,
}) {
  final device = doc.devices[deviceId];
  if (device == null) return null;

  // CR-054 says a TemplateRef always resolves; a hand-edited file says
  // otherwise, and `bodyFor` already treats that as an unknown rather
  // than an impossibility — the same reading `resolvePortSet` takes.
  final body = bodyFor(device, doc.templates);
  if (body == null) return null;

  PortDef? def;
  for (final p in body.ports) {
    if (p.key.v == portKey) {
      def = p;
      break;
    }
  }
  if (def == null) return null;

  final id = derivePortId(deviceId, def.key);
  final existing = doc.ports[id];
  return ConnectTarget(
    deviceId: deviceId,
    deviceDesignator: device.designator,
    def: def,
    portId: id,
    materialisedPort: existing,
    // Only when there is no designator already — an existing `Port`'s is
    // project state and nothing here may propose a replacement for it.
    plannedDesignator: existing != null
        ? null
        : _tryAllocatePortDesignator(
            doc,
            deviceId: deviceId,
            portSeq: _seqIn(body, def.key),
          ),
  );
}

/// [allocatePortDesignatorFor]'s answer, or NULL when the project's
/// pattern cannot render one.
///
/// A REFUSAL SENTENCE MAY NOT THROW. `portDesignatorFormat` is a
/// persisted, user-editable string, and three of its failure modes are
/// live: the commercial `{DEV_BLOCK}{PORT_SEQ:2}` preset canon names
/// throws `MissingTokenValueException` because reserve-block allocation
/// is not implemented (see `allocatePortDesignator`); a hand-edited file
/// can carry a syntactically broken pattern; and one with no sequence
/// token throws `DesignatorExhaustedException`. Every one of those is a
/// problem with the project's FORMAT SETTING, and none of them is a
/// reason the user should get a crash instead of "you cannot connect that
/// pin to itself". The command path deliberately does NOT swallow them —
/// see [allocatePortDesignatorFor].
String? _tryAllocatePortDesignator(
  RackDocument doc, {
  required Uuid deviceId,
  required int portSeq,
}) {
  try {
    return _allocatePortDesignator(
      doc,
      deviceId: deviceId,
      portSeq: portSeq,
      alsoUsed: const {},
    );
  } on Exception {
    return null;
  }
}

/// The designator [target]'s port should receive if it has to be
/// materialised — or the one it ALREADY carries, when the document holds
/// the port already.
///
/// Doc-aware companion to `allocatePortDesignator`: the pure function
/// stays in `idformat/` depending only on `ProjectSettings`, and the
/// document query lives here, beside [resolveConnectTarget] — which needs
/// the same answer for [ConnectTarget.plannedDesignator] and must get it
/// from the same code, or a refusal would name one `J`-number and the
/// connect would write another.
///
/// [alsoUsed] lets a caller reserve designators it is about to mint in the
/// same gesture but has not written to [doc] yet.
///
/// THROWS where [ConnectTarget.plannedDesignator] falls back to null. A
/// sentence with a weaker name in it is still a usable sentence; a `Port`
/// written with a fabricated or blank designator is a wrong identifier on
/// a termination schedule (G4), and there is no weaker answer that is
/// safe. CALL THIS BEFORE CONSTRUCTING THE COMMAND, never inside
/// `apply()`.
String allocatePortDesignatorFor(
  RackDocument doc,
  ConnectTarget target, {
  Set<String> alsoUsed = const {},
}) {
  final existing = target.materialisedPort;
  if (existing != null) return existing.designator;

  return _allocatePortDesignator(
    doc,
    deviceId: target.deviceId,
    portSeq: templatePortSeq(doc, target),
    alsoUsed: alsoUsed,
  );
}

String _allocatePortDesignator(
  RackDocument doc, {
  required Uuid deviceId,
  required int portSeq,
  required Set<String> alsoUsed,
}) => allocatePortDesignator(
  settings: doc.settings,
  portSeq: portSeq,
  // PER DEVICE, per CR-042's correction of I-12 from project-wide.
  usedDesignators: {
    for (final p in doc.ports.values)
      if (p.deviceId == deviceId) p.designator,
    ...alsoUsed,
  },
);

/// [target]'s 1-based position in its template's declared port order —
/// the `PORT_SEQ` `allocatePortDesignator` renders.
///
/// Falls back to 1 when the template does not resolve — which
/// [resolveConnectTarget] has already made impossible for any target that
/// exists, so this is a total-function guard rather than a case.
int templatePortSeq(RackDocument doc, ConnectTarget target) {
  final device = doc.devices[target.deviceId];
  final body = device == null ? null : bodyFor(device, doc.templates);
  if (body == null) return 1;
  return _seqIn(body, target.portKey);
}

/// [key]'s 1-based position in [body]'s declared port order.
///
/// The sort is `PortDef.order` with a `key` tiebreak, IDENTICAL to
/// `resolvePortSet`'s, because two orderings of the same list is how a pin
/// ends up with one number on the schedule and a different one in the set
/// that wires it.
int _seqIn(TemplateBody body, PortKey key) {
  final ordered = [...body.ports]..sort((a, b) {
    final byOrder = a.order.v.compareTo(b.order.v);
    return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
  });
  final at = ordered.indexWhere((p) => p.key.v == key.v);
  return at < 0 ? 1 : at + 1;
}
