// AC-016/#24, CR-117 — THE MANDATED PROPERTY TEST. docs/03-architecture.md
// §5.1: "A command must be idempotent under alternation: apply; revert;
// apply lands in the identical state as a single apply." This generates
// 1,000 random-but-valid command sequences from a fresh `RackDocument`
// with one `Rack`, and for every command in every sequence, asserts that
// applying it and then immediately reverting it restores the document's
// JSON-serialized bytes (via the real `JsonDocumentCodec`) to BYTE
// IDENTITY with what they were immediately before — not a semantic
// comparison, the literal byte property CR-117 exists for. After each
// check, the command is re-applied for real (this is the trailing
// `apply` half of the same `apply; revert; apply` law), so the sequence
// accumulates realistic document state for later commands to reference —
// "always AddDevice before any command referencing that device's id" is
// enforced by construction: this generator only ever picks a
// device/link-referencing command when its tracked alive-id set is
// non-empty.
//
// ═════════════════════════════════════════════════════════════════════
// THE M3-A FAMILY WAS OUTSIDE THIS HARNESS ENTIRELY (board #579)
// ═════════════════════════════════════════════════════════════════════
// Until that item the generator built devices, racks and links, and had
// NEVER built an `Outlet`. Every command M3-A shipped — the Structure and
// Outlet create/remove pairs, the home run, the property tables and the
// origin edit — sat outside the only thing in this repository that
// carries CR-117 across interleavings rather than one fixed pair.
//
// Adding the arms found a defect in the harness itself, which is recorded
// on `_SequenceState.pruneDeadLinks`: `RemoveDeviceCommand` cascades to
// the links on that device's ports, the alive-id bookkeeping never
// noticed, and every link arm drawn on a cascaded id had been building a
// command that did nothing. The byte property held over a no-op. It took
// the first arm that READS a link before building it to turn that silent
// pass into a crash.
//
// `doc.templates` is never touched by any M0 command (AC-015 template-
// snapshot refcounting is explicitly deferred — see device_commands.dart)
// so there is nothing to assert about `templates.keys` here; noted rather
// than silently skipped. The document does now CARRY one snapshot, because
// `connectPorts` names pins off a real `TemplateBody` — see `_portKeys` —
// but no generated command reads or writes the map.
//
// ═════════════════════════════════════════════════════════════════════
// `connectPorts` IS THE STEP THIS HARNESS EXISTS FOR
// ═════════════════════════════════════════════════════════════════════
// Every other command in this repository reverts by pure inverse: it
// restores what it captured, or removes exactly what it created, and the
// answer does not depend on the document. `ConnectPortsCommand` is the
// one exception (DR-011.1) — it materialises a `Port` only if the
// document did not already hold one, and `revert()` removes only the ones
// THAT apply() minted. So the same command value has two different
// correct undos depending on state it found, which is precisely the shape
// a fixed unit test can pin one arm of and a random walk can catch both.
// `_portKeys` argues how the interleaving reaches the asymmetric arm, and
// the deterministic test at the bottom of this file pins it outright
// rather than trusting a seed to.
//
// Seeded with `dart:math`'s `Random(seed)`: `_baseSeed + i` for sequence
// `i` of 1000. A failure's `reason` names the exact seed AND the step
// index/command within that sequence, so `Random(_baseSeed + i)` alone
// reproduces it.
import 'dart:convert';
import 'dart:math';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
const _baseSeed = 20260718;
const _sequenceCount = 1000;

const _rackId = Uuid('property-test-rack');
const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.property-test'),
  version: 1,
  contentHash: 'sha256:property-test',
);

EntityMeta _meta(DateTime at) =>
    EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'seed');

/// The pins the fixture template declares, and the only ones a
/// `connectPorts` step ever names.
///
/// ═════════════════════════════════════════════════════════════════════
/// `cresnet.1` IS A BUS TAP ON PURPOSE — IT IS WHAT MAKES THE
/// DATA-DEPENDENT HALF OF `revert()` REACHABLE FROM A RANDOM WALK
/// ═════════════════════════════════════════════════════════════════════
/// The case that can break is a connect onto a pin an EARLIER connect
/// already materialised: `revert()` must leave that pin alone and remove
/// only the far end. On a `p2p` pin (`maxConnections` 1, the default every
/// seed port takes) the second connect never gets built — `TOP-003`
/// refuses it while the first cable is still on the jack — so a fixture of
/// nothing but point-to-point pins reaches only the symmetric
/// both-ends-new case, where a `revert()` that removed both ports
/// unconditionally would look perfectly correct.
///
/// A `PortDirection.busNode` tap's EFFECTIVE `maxConnections` is unbounded
/// (`ConnectTarget.effectiveMaxConnections`: a Cresnet drop whose bound is
/// one connection is not a bus at all), so the same pin takes a second
/// cable and the asymmetric case is one generated step away.
///
/// It is not the only route — `removeLink` frees a `p2p` pin's conductor
/// count while leaving the `Port` materialised, so a connect / removeLink
/// / connect interleaving reaches the same shape — but it is the one that
/// needs no other command to cooperate.
const _portKeys = <PortKey>[
  PortKey('hdmi.out.1'),
  PortKey('hdmi.in.1'),
  PortKey('cresnet.1'),
];

const _panelPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _portDef(int seq, PortDirection direction) => PortDef(
  key: _portKeys[seq],
  label: _portKeys[seq].v,
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('data.ethernet'),
  direction: direction,
  face: Face.rear,
  position: _panelPosition,
  order: FracIndex('a$seq'),
);

/// The one snapshot every generated `AddDeviceCommand` resolves through.
///
/// `resolveConnectTarget` joins a device to a `PortDef` off its template
/// body and returns null when it cannot, so without this the connect step
/// would be permanently unreachable rather than merely rare — which is the
/// state this file was in, and the reason `connect_commands_test.dart`
/// carried the byte property for this command alone.
TemplateSnapshot _fixtureTemplate(DateTime at) => TemplateSnapshot(
  templateId: _templateRef.templateId,
  version: _templateRef.version,
  contentHash: _templateRef.contentHash,
  capturedAt: at,
  body: TemplateBody(
    manufacturer: 'Property Test',
    model: 'PT-1',
    displayName: 'Property Test Device',
    ports: [
      _portDef(0, PortDirection.source),
      _portDef(1, PortDirection.sink),
      _portDef(2, PortDirection.busNode),
    ],
  ),
);

RackDocument _freshDocumentWithOneRack(DateTime at) {
  final doc = RackDocument(
    id: const Uuid('property-test-doc'),
    appVersion: '0.1.0',
    createdAt: at,
    modifiedAt: at,
    meta: _meta(at),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Property Test Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(at),
  );
  doc.templates[templateKeyFor(_templateRef)] = _fixtureTemplate(at);

  // ONE STRUCTURE BODY AND ONE OUTLET, SEEDED.
  //
  // Not decoration: without them a home run needs `addStructure` then
  // `addOutlet` then `addHomeRun`, three specific kinds in order, drawn
  // uniformly from a menu of twenty-odd over a 5..15 step sequence. Left
  // to chance that put `setOriginProperty` at eleven firings across all
  // thousand sequences, six of which were legitimate refusals — five real
  // edits, which is the same "fact about a seed rather than a property of
  // the harness" this file already warns about for `connectPorts`.
  //
  // Both are removable by later steps, deliberately, so the sequences
  // that DO exercise a missing body still happen.
  AddStructureCommand(
    title: 'Seed Rough-In',
    designator: 'STR-1',
    now: at,
    actor: 'seed',
    bodyId: _seedBodyId,
    deviceId: _seedStructureDeviceId,
  ).apply(doc);
  AddOutletCommand(
    structureBodyId: _seedBodyId,
    designation: 'GR-TV-0',
    order: nextOutletOrder(doc),
    now: at,
    actor: 'seed',
    id: _seedOutletId,
  ).apply(doc);

  return doc;
}

const _seedBodyId = Uuid('seed-structure-body');
const _seedStructureDeviceId = Uuid('seed-structure-device');
const _seedOutletId = Uuid('seed-outlet');

enum _StepKind {
  addDevice,
  removeDevice,
  moveDevice,
  renameDevice,
  renameRack,
  setRackHeight,
  setRackProperty,
  addLink,
  removeLink,
  setLinkJacketColor,
  setLinkPulledJacketColor,
  setLinkClass,
  clearLinkClassOverride,
  connectPorts,

  // M3-A's Structure family (board #579). Every one of these commands
  // shipped without a generator arm, so the whole family sat outside the
  // harness that carries CR-117 for everything else.
  addStructure,
  removeStructure,
  addOutlet,
  removeOutlet,
  setOutletProperty,
  setStructureBodyProperty,
  addHomeRun,
  setOriginProperty,
  setLifecycleStatus,
}

/// The convention ids the generator draws from, plus `null` (clear) and
/// one id naming NO convention entry — a dangling id must round-trip as
/// faithfully as a resolvable one, because it is the one record that a
/// wrong colour went in the wall.
const _jacketColorIds = <JacketColorId?>[
  null,
  JacketColorId('jc.blue'),
  JacketColorId('jc.yellow'),
  JacketColorId('jc.deleted_last_year'),
];

/// Builds a `SetEntityPropertyCommand` for a randomly chosen field, with a
/// randomly chosen NEW value of that field's own type.
///
/// Deliberately covers all five value shapes the table carries — String,
/// bool, enum, `Len?` and `Mass?` — because the byte property is most
/// fragile exactly where nullability meets CR-117's absent-key-not-null
/// rule: `usableDepth`/`weightCapacity` encode as an ABSENT key when null,
/// so a revert that restored `Len(0)` instead of `null` would produce a
/// semantically-equal document with different bytes, and only this test
/// would catch it.
Command _buildSetEntityProperty(_SequenceState s, Random rnd) {
  final rack = s.doc.racks[_rackId]!;
  final now = s.nextNow();
  const actor = 'gen';

  T pick<T>(List<T> options, T current) {
    final others = options.where((o) => o != current).toList();
    return others.isEmpty ? current : others[rnd.nextInt(others.length)];
  }

  SetEntityPropertyCommand<Rack, T> make<T>(EntityField<Rack, T> field, T to) =>
      SetEntityPropertyCommand<Rack, T>(
        id: _rackId,
        field: field,
        from: field.get(rack),
        to: to,
        now: now,
        actor: actor,
      );

  switch (rnd.nextInt(8)) {
    case 0:
      return make(
        RackField.designator,
        'RK-${rnd.nextInt(1000)}',
      );
    case 1:
      return make(
        RackField.locationId,
        rnd.nextBool() ? Uuid('loc-${rnd.nextInt(5)}') : null,
      );
    case 2:
      return make(
        RackField.ruNumbering,
        pick(RuNumbering.values, rack.ruNumbering),
      );
    case 3:
      return make(RackField.mirrorRearElevation, !rack.mirrorRearElevation);
    case 4:
      return make(
        RackField.widthClass,
        pick(RackWidthClass.values, rack.widthClass),
      );
    case 5:
      // Nullable Len — the absent-key case.
      return make(
        RackField.usableDepth,
        rnd.nextBool() ? Len(1000000 * (1 + rnd.nextInt(900))) : null,
      );
    case 6:
      // Nullable Mass — the other absent-key case.
      return make(
        RackField.weightCapacity,
        rnd.nextBool() ? Mass(1000000000 * (1 + rnd.nextInt(900))) : null,
      );
    default:
      // The conditional-key case: `hingeSide` is written with a bare
      // `if (r.hingeSide != null)` rather than `putIfNotNull`.
      return make(
        RackField.hingeSide,
        rnd.nextBool() ? pick(HingeSide.values, rack.hingeSide) : null,
      );
  }
}

/// One `SetEntityPropertyCommand` over a random `OutletField`.
///
/// SPELLED OUT PER FIELD rather than picked off `OutletField.all`, for
/// `_buildSetRackProperty`'s reason: driving `set` through the erased
/// element type would discard the static typing the table exists for, and
/// the nullable arms below are exactly where an absent-key bug hides.
Command _buildSetOutletProperty(_SequenceState s, Random rnd, int step) {
  final id = s.aliveOutletIds[rnd.nextInt(s.aliveOutletIds.length)];
  final outlet = s.doc.outlets[id]!;
  final now = s.nextNow();

  SetEntityPropertyCommand<Outlet, T> make<T>(
    EntityField<Outlet, T> field,
    T to,
  ) => SetEntityPropertyCommand<Outlet, T>(
    id: id,
    field: field,
    from: field.get(outlet),
    to: to,
    now: now,
    actor: 'gen',
  );

  return switch (rnd.nextInt(5)) {
    0 => make(OutletField.designation, 'GR-TV-$step'),
    // Nullable String — `putIfNotNull`, so null is an ABSENT key.
    1 => make(OutletField.notes, rnd.nextBool() ? 'note $step' : null),
    // Nullable enum — written with a bare `if (o.wall != null)`.
    2 => make(
      OutletField.wall,
      rnd.nextBool() ? Wall.values[rnd.nextInt(Wall.values.length)] : null,
    ),
    // Nullable Len, the case CR-114 is about: a revert restoring `Len(0)`
    // instead of null is semantically equal and byte-different.
    3 => make(
      OutletField.mountHeightAff,
      rnd.nextBool() ? Len(1000000 * (1 + rnd.nextInt(2500))) : null,
    ),
    _ => make(
      OutletField.nominalRunLength,
      rnd.nextBool() ? Len(1000000 * (1 + rnd.nextInt(50000))) : null,
    ),
  };
}

/// One `SetEntityPropertyCommand` over a random `StructureBodyField`.
Command _buildSetStructureBodyProperty(
  _SequenceState s,
  Random rnd,
  int step,
) {
  final id =
      s.aliveStructureBodyIds[rnd.nextInt(
        s.aliveStructureBodyIds.length,
      )];
  final body = s.doc.structures[id]!;
  final now = s.nextNow();

  SetEntityPropertyCommand<StructureBody, T> make<T>(
    EntityField<StructureBody, T> field,
    T to,
  ) => SetEntityPropertyCommand<StructureBody, T>(
    id: id,
    field: field,
    from: field.get(body),
    to: to,
    now: now,
    actor: 'gen',
  );

  return switch (rnd.nextInt(4)) {
    0 => make(StructureBodyField.title, 'Rough-In $step'),
    1 => make(
      StructureBodyField.enclosureModel,
      rnd.nextBool() ? 'Generic $step in' : null,
    ),
    // Both of these are ALWAYS-PRESENT keys, unlike the two above — a
    // mixed table is what makes the absent-key arms meaningful.
    2 => make(
      StructureBodyField.role,
      StructureRole.values[rnd.nextInt(StructureRole.values.length)],
    ),
    _ => make(
      StructureBodyField.sheetEdge,
      SheetEdge.values[rnd.nextInt(SheetEdge.values.length)],
    ),
  };
}

/// One `StructureOriginField` edit, through the builder that guards
/// CR-113 — never by constructing the command directly, because a
/// generated rename onto a label another drop already holds is a state
/// this walk reaches routinely and the builder is the thing that decides
/// what happens then.
Command? _buildSetOriginProperty(_SequenceState s, Random rnd, int step) {
  final linkId =
      s.aliveHomeRunLinkIds[rnd.nextInt(s.aliveHomeRunLinkIds.length)];
  final now = s.nextNow();

  SetStructureOriginResult run<T>(EntityField<Link, T> field, T to) =>
      buildSetStructureOriginProperty<T>(
        doc: s.doc,
        linkId: linkId,
        field: field,
        to: to,
        now: now,
        actor: 'gen',
      );

  final result = switch (rnd.nextInt(4)) {
    // Deliberately a SMALL label space: `GR-DATA-0`..`GR-DATA-4` over a
    // sequence that makes several drops means collisions are common
    // rather than rare, so the refusal path is walked instead of
    // theorised about.
    0 => run(StructureOriginField.fieldLabel, 'GR-DATA-${rnd.nextInt(5)}'),
    1 => run(
      StructureOriginField.rackLabel,
      rnd.nextBool() ? 'PP1-0${rnd.nextInt(5)}' : null,
    ),
    2 => run(
      StructureOriginField.mountHeightAff,
      rnd.nextBool() ? Len(1000000 * (1 + rnd.nextInt(2500))) : null,
    ),
    _ => run(
      StructureOriginField.terminationField,
      TerminationType.values[rnd.nextInt(TerminationType.values.length)],
    ),
  };

  return switch (result) {
    SetStructureOriginReady<String>(:final command) => command,
    SetStructureOriginReady<String?>(:final command) => command,
    SetStructureOriginReady<Len?>(:final command) => command,
    SetStructureOriginReady<TerminationType>(:final command) => command,
    // Both are legitimate outcomes with no command behind them, exactly
    // like `ConnectPortsRefused`: a duplicate label is refused (CR-113)
    // and a value the field already holds is nothing to do.
    SetStructureOriginReady() => null,
    SetStructureOriginUnchanged() => null,
    SetStructureOriginRefused() => null,
  };
}

/// One lifecycle edit, on a device or a cable — M3-A/7's two table rows.
Command _buildSetLifecycle(_SequenceState s, Random rnd) {
  final now = s.nextNow();
  final status =
      LifecycleStatus.values[rnd.nextInt(LifecycleStatus.values.length)];

  if (s.aliveDeviceIds.isNotEmpty &&
      (rnd.nextBool() || s.aliveLinkIds.isEmpty)) {
    final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
    return SetEntityPropertyCommand<DeviceInstance, LifecycleStatus>(
      id: id,
      field: DeviceField.lifecycleStatus,
      from: s.doc.devices[id]!.lifecycleStatus,
      to: status,
      now: now,
      actor: 'gen',
    );
  }
  final id = s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)];
  return SetEntityPropertyCommand<Link, LifecycleStatus>(
    id: id,
    field: LinkField.lifecycleStatus,
    from: s.doc.links[id]!.lifecycleStatus,
    to: status,
    now: now,
    actor: 'gen',
  );
}

/// One generated sequence's mutable bookkeeping: which ids currently
/// exist in [doc], so the generator only ever builds a command that
/// references an id known to be alive right now.
final class _SequenceState {
  _SequenceState(this.doc) {
    // The fixture ships one of each — see `_freshDocumentWithOneRack`.
    aliveStructureBodyIds.add(_seedBodyId);
    aliveOutletIds.add(_seedOutletId);
  }

  final RackDocument doc;

  /// RAIL-PLACED devices carrying `_templateRef`, and nothing else.
  ///
  /// The Structure device `AddStructureCommand` creates is deliberately
  /// NOT in here, and the omission is load-bearing rather than tidy:
  /// `moveDevice` casts a placement to `RailPlacement` (a Structure body
  /// is `OffRack`) and `connectPorts` resolves a pin off the template (a
  /// Structure device names a ref that resolves to nothing, by spec —
  /// docs/07 §2). Either arm would crash on it, and neither crash would
  /// be about the property this file tests.
  final List<Uuid> aliveDeviceIds = [];

  final List<Uuid> aliveLinkIds = [];
  final Map<Uuid, Uuid> linkNetIds = {};

  final List<Uuid> aliveStructureBodyIds = [];
  final List<Uuid> aliveOutletIds = [];

  /// The subset of [aliveLinkIds] that carry a `structureOrigin`. A
  /// separate list because `setOriginProperty` is only legal on those,
  /// and an ordinary `AddLinkCommand` link would refuse it.
  final List<Uuid> aliveHomeRunLinkIds = [];

  var _tick = 0;

  /// Drops link ids the document no longer holds.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS EXISTS BECAUSE THE BOOKKEEPING WAS SILENTLY GOING STALE
  /// ═══════════════════════════════════════════════════════════════════
  /// `RemoveDeviceCommand` CASCADES to the links landing on that device's
  /// ports (device_commands.dart) and this file never noticed, because
  /// every link arm it had passed an id into a command WITHOUT
  /// dereferencing it, and `SetLinkJacketColorCommand` and its siblings
  /// begin `if (link == null) return;`. So a jacket/class/remove step
  /// drawn on a cascaded id built a command that did nothing, and the
  /// byte property held over a no-op: green, and testing nothing.
  ///
  /// Found by the first arm that reads the link before building —
  /// `setLifecycleStatus` needs the `from` value — which turned a silent
  /// no-op into a null dereference at seed 20260952 step 6.
  void pruneDeadLinks() {
    aliveLinkIds.removeWhere((id) => !doc.links.containsKey(id));
    aliveHomeRunLinkIds.removeWhere((id) => !doc.links.containsKey(id));
    linkNetIds.removeWhere((id, _) => !doc.links.containsKey(id));
  }

  /// A fresh, strictly-advancing instant each call — never
  /// `DateTime.now()` (this package's injectable-clock policy), and
  /// distinct per command so redo-vs-original-apply timestamp bugs
  /// would actually show up if introduced.
  DateTime nextNow() => DateTime.utc(2026).add(Duration(seconds: _tick++));

  List<_StepKind> availableKinds() => [
    _StepKind.addDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.removeDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.moveDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.renameDevice,
    _StepKind.renameRack,
    _StepKind.setRackHeight,
    _StepKind.setRackProperty,
    _StepKind.addLink,
    if (aliveLinkIds.isNotEmpty) _StepKind.removeLink,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkJacketColor,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkPulledJacketColor,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkClass,
    if (aliveLinkIds.isNotEmpty) _StepKind.clearLinkClassOverride,
    // TWO devices, not one: the two ends must sit on different devices so
    // the pair is never a pin to itself, which `TOP-001` refuses and the
    // command's own constructor throws on.
    if (aliveDeviceIds.length >= 2) _StepKind.connectPorts,

    _StepKind.addStructure,
    if (aliveStructureBodyIds.isNotEmpty) _StepKind.removeStructure,
    if (aliveStructureBodyIds.isNotEmpty) _StepKind.addOutlet,
    if (aliveStructureBodyIds.isNotEmpty) _StepKind.setStructureBodyProperty,
    if (aliveOutletIds.isNotEmpty) _StepKind.removeOutlet,
    if (aliveOutletIds.isNotEmpty) _StepKind.setOutletProperty,
    // NOT gated on the outlet's body still existing. That is the point:
    // neither remove cascades, so an outlet whose body is gone is a
    // REACHABLE state, and the builder refuses the home run with a
    // sentence rather than throwing. The arm returning null there is the
    // harness observing a legitimate refusal, exactly as `connectPorts`
    // does for a full jack.
    if (aliveOutletIds.isNotEmpty) _StepKind.addHomeRun,
    if (aliveHomeRunLinkIds.isNotEmpty) _StepKind.setOriginProperty,
    if (aliveDeviceIds.isNotEmpty || aliveLinkIds.isNotEmpty)
      _StepKind.setLifecycleStatus,
  ];
}

/// The command this step runs, or NULL when the step is a legitimate
/// no-op.
///
/// Only `connectPorts` ever answers null, and only because a tier-1
/// refusal is an OUTCOME rather than a defect: `buildConnectPortsCommand`
/// returns `ConnectPortsRefused` when `TOP-003` says the jack is full, and
/// DR-011.5 gives that refusal no `[ Connect anyway ]` — so there is no
/// command, no document change and nothing to assert a byte property
/// about. Failing the test there would make the harness red on a document
/// state it is supposed to be generating.
Command? _buildCommand(_StepKind kind, _SequenceState s, Random rnd, int step) {
  switch (kind) {
    case _StepKind.addDevice:
      return AddDeviceCommand(
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-$step',
        name: 'Device $step',
        placement: RailPlacement(
          rackId: _rackId,
          ruIndex: 1 + rnd.nextInt(40),
          face: Face.values[rnd.nextInt(Face.values.length)],
        ),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      return RemoveDeviceCommand(id: id);

    case _StepKind.moveDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      final current = s.doc.devices[id]!.placement as RailPlacement;
      return MoveDeviceCommand(
        id: id,
        fromRuIndex: current.ruIndex,
        toRuIndex: 1 + rnd.nextInt(40),
        fromFace: current.face,
        toFace: Face.values[rnd.nextInt(Face.values.length)],
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.renameDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      return RenameEntityCommand(
        targetKind: RenameTargetKind.device,
        id: id,
        from: s.doc.devices[id]!.name,
        to: 'Renamed Device $step',
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.renameRack:
      return RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: _rackId,
        from: s.doc.racks[_rackId]!.name,
        to: 'Renamed Rack $step',
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.setRackHeight:
      return SetRackHeightCommand(
        id: _rackId,
        fromHeightU: s.doc.racks[_rackId]!.heightU,
        toHeightU: 1 + rnd.nextInt(60),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.setRackProperty:
      return _buildSetEntityProperty(s, rnd);

    case _StepKind.addLink:
      return AddLinkCommand(
        designator: 'W${step.toString().padLeft(3, '0')}',
        // Real allocation, not a literal — so the byte property is checked
        // against a name derived from the document's CURRENT nets. Removing
        // a link frees its name, and the next add reuses it; a sequence
        // that interleaves the two exercises the collision search rather
        // than a constant.
        netName: allocateNetNameFor(s.doc),
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeLink:
      final id = s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)];
      // NO `!` SINCE #96 — `netId` is nullable now, so a link the generator
      // has no net for passes null and the command removes the link alone.
      // That is the right shape here rather than a lucky one: the map is
      // this generator's own bookkeeping, and a bang on it would assert
      // that bookkeeping is complete, which is not what this suite is for.
      return RemoveLinkCommand(id: id, netId: s.linkNetIds[id]);

    case _StepKind.setLinkJacketColor:
      return SetLinkJacketColorCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        conventionId: _jacketColorIds[rnd.nextInt(_jacketColorIds.length)],
      );

    case _StepKind.setLinkPulledJacketColor:
      // Interleaving this with `setLinkJacketColor` above is the point:
      // the command NORMALISES an override equal to the run's current
      // convention away, so a sequence that changes the convention
      // between two identical override writes exercises a path where the
      // same command value produces different stored state. `revert()`
      // must still restore byte-exactly through all of it.
      return SetLinkPulledJacketColorCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        pulledId: _jacketColorIds[rnd.nextInt(_jacketColorIds.length)],
      );

    case _StepKind.setLinkClass:
      return SetLinkClassCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        linkClass: LinkClass.values[rnd.nextInt(LinkClass.values.length)],
      );

    case _StepKind.clearLinkClassOverride:
      // INTERLEAVED WITH `setLinkClass` ON PURPOSE. `linkClassLocked` is
      // an ABSENT-WHEN-FALSE key (DR-008 §11.8.2), which is the whole
      // reason the field could be added without moving `kSchemaVersion`.
      // A set/clear pair must therefore leave the document byte-identical
      // to one that never carried the key at all — and two different bugs
      // show up here as a byte diff rather than as a passing unit test:
      // an encoder that starts writing `false`, and a `revert()` that
      // restores the class but not the lock.
      return ClearLinkClassOverrideCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
      );

    case _StepKind.connectPorts:
      // Two DIFFERENT alive devices, drawn as an ordered pair without
      // replacement — the same walk `_buildSetRackProperty`'s `pick` does
      // for a new enum value, spelled inline because the second index
      // must skip the first rather than merely differ in value.
      final fromAt = rnd.nextInt(s.aliveDeviceIds.length);
      var toAt = rnd.nextInt(s.aliveDeviceIds.length - 1);
      if (toAt >= fromAt) toAt++;

      // Non-null by construction: both devices are alive (this kind is
      // only offered when two are) and every one of them carries
      // `_templateRef`, whose snapshot declares every key in `_portKeys`.
      final from = resolveConnectTarget(
        s.doc,
        deviceId: s.aliveDeviceIds[fromAt],
        portKey: _portKeys[rnd.nextInt(_portKeys.length)].v,
      )!;
      final to = resolveConnectTarget(
        s.doc,
        deviceId: s.aliveDeviceIds[toAt],
        portKey: _portKeys[rnd.nextInt(_portKeys.length)].v,
      )!;

      // EVERY allocation — both port designators, the link designator,
      // the net name and the sort order — happens in here, caller-side,
      // exactly as `AddLinkCommand.netName` above is allocated against the
      // document's CURRENT state rather than written as a literal.
      final result = buildConnectPortsCommand(
        doc: s.doc,
        from: from,
        to: to,
        media: const MediaTypeId('media.cat6a_futp'),
        now: s.nextNow(),
        actor: 'gen',
      );
      return switch (result) {
        ConnectPortsReady(:final command) => command,
        // The jack is full. See this function's own doc comment.
        ConnectPortsRefused() => null,
      };

    case _StepKind.addStructure:
      return AddStructureCommand(
        title: 'Rough-In $step',
        designator: allocateStructureDesignator(doc: s.doc),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeStructure:
      return RemoveStructureCommand(
        bodyId:
            s.aliveStructureBodyIds[rnd.nextInt(
              s.aliveStructureBodyIds.length,
            )],
      );

    case _StepKind.addOutlet:
      return AddOutletCommand(
        structureBodyId:
            s.aliveStructureBodyIds[rnd.nextInt(
              s.aliveStructureBodyIds.length,
            )],
        designation: 'GR-TV-$step',
        order: nextOutletOrder(s.doc),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeOutlet:
      return RemoveOutletCommand(
        id: s.aliveOutletIds[rnd.nextInt(s.aliveOutletIds.length)],
      );

    case _StepKind.setOutletProperty:
      return _buildSetOutletProperty(s, rnd, step);

    case _StepKind.setStructureBodyProperty:
      return _buildSetStructureBodyProperty(s, rnd, step);

    case _StepKind.addHomeRun:
      final result = buildAddHomeRunCommand(
        doc: s.doc,
        outletId: s.aliveOutletIds[rnd.nextInt(s.aliveOutletIds.length)],
        fieldLabel: 'GR-DATA-$step',
        // Real allocators, like `AddLinkCommand`'s above: a removed link
        // frees its number and the next add reuses it, so an interleaved
        // sequence exercises the collision search rather than a literal.
        designator: allocateLinkDesignatorFor(s.doc),
        netName: allocateNetNameFor(s.doc),
        media: const MediaTypeId('media.cat6_utp'),
        fieldEnd: rnd.nextBool()
            ? PlaceEndpoint(description: 'Room $step')
            : const OpenEndpoint('not yet pulled'),
        terminationField: TerminationType.keystone,
        // Half the runs land nowhere, which is AC-018's own shape and the
        // one an `OpenEndpoint` far end has to survive a round trip in.
        rackEnd: rnd.nextBool() ? null : const OpenEndpoint('coiled'),
        rackLabel: rnd.nextBool() ? 'PP1-1$step' : null,
        now: s.nextNow(),
        actor: 'gen',
      );
      return switch (result) {
        AddHomeRunReady(:final command) => command,
        // The outlet's Structure body was removed by an earlier step and
        // nothing cascaded, so the outlet outlived its body. A legitimate
        // refusal, not a defect — see `availableKinds`.
        AddHomeRunRefused() => null,
      };

    case _StepKind.setOriginProperty:
      return _buildSetOriginProperty(s, rnd, step);

    case _StepKind.setLifecycleStatus:
      return _buildSetLifecycle(s, rnd);
  }
}

void _reconcileTrackingAfterCommit(
  _StepKind kind,
  Command cmd,
  _SequenceState s,
) {
  switch (kind) {
    case _StepKind.addDevice:
      s.aliveDeviceIds.add((cmd as AddDeviceCommand).id);
    case _StepKind.removeDevice:
      s.aliveDeviceIds.remove((cmd as RemoveDeviceCommand).id);
    case _StepKind.addLink:
      final add = cmd as AddLinkCommand;
      s.aliveLinkIds.add(add.id);
      s.linkNetIds[add.id] = add.netId;
    case _StepKind.removeLink:
      final remove = cmd as RemoveLinkCommand;
      s.aliveLinkIds.remove(remove.id);
      s.linkNetIds.remove(remove.id);
      s.aliveHomeRunLinkIds.remove(remove.id);
    case _StepKind.connectPorts:
      // Tracked as a link like any other, DELIBERATELY. A later
      // `removeLink` step then takes this link away while leaving both
      // `Port` rows materialised — `RemoveLinkCommand` cleans up neither
      // — which drops the pins' live conductor count back to zero and
      // reopens a `p2p` jack that `TOP-003` had closed. That is the
      // second route to a connect whose apply() finds one end ALREADY
      // there, and it needs no bus pin to reach it.
      final connect = cmd as ConnectPortsCommand;
      s.aliveLinkIds.add(connect.id);
      s.linkNetIds[connect.id] = connect.netId;
    case _StepKind.addStructure:
      // The DEVICE half is not added to `aliveDeviceIds` — see the field's
      // own comment on `_SequenceState`.
      s.aliveStructureBodyIds.add((cmd as AddStructureCommand).bodyId);
    case _StepKind.removeStructure:
      s.aliveStructureBodyIds.remove((cmd as RemoveStructureCommand).bodyId);
    // ITS OUTLETS ARE LEFT IN `aliveOutletIds` ON PURPOSE. Nothing
    // cascades (an Outlet is a fact about the BUILDING and survives the
    // panel it feeds), so an outlet whose body is gone is a real document
    // state and later steps must keep reaching it.
    case _StepKind.addOutlet:
      s.aliveOutletIds.add((cmd as AddOutletCommand).id);
    case _StepKind.removeOutlet:
      // Home runs keyed to it are likewise left alive: a `structureOrigin`
      // whose `outletId` resolves to nothing is exactly the dangling
      // reference the codec has to keep writing faithfully.
      s.aliveOutletIds.remove((cmd as RemoveOutletCommand).id);
    case _StepKind.addHomeRun:
      final run = cmd as AddHomeRunCommand;
      s.aliveLinkIds.add(run.id);
      s.linkNetIds[run.id] = run.netId;
      s.aliveHomeRunLinkIds.add(run.id);
    case _StepKind.moveDevice:
    case _StepKind.renameDevice:
    case _StepKind.renameRack:
    case _StepKind.setRackHeight:
    case _StepKind.setRackProperty:
    case _StepKind.setLinkJacketColor:
    case _StepKind.setLinkPulledJacketColor:
    case _StepKind.setLinkClass:
    case _StepKind.clearLinkClassOverride:
    case _StepKind.setOutletProperty:
    case _StepKind.setStructureBodyProperty:
    case _StepKind.setOriginProperty:
    case _StepKind.setLifecycleStatus:
    // Mutate entities already tracked; no alive-id bookkeeping needed.
  }

  // AFTER the per-kind bookkeeping, not instead of it: the switch records
  // what the command itself did, and this catches what it did to
  // SOMETHING ELSE. See `pruneDeadLinks`.
  s.pruneDeadLinks();
}

// ═════════════════════════════════════════════════════════════════════
// THE DETERMINISTIC PIN FOR THE ONE REVERT THAT IS NOT A PURE INVERSE
// ═════════════════════════════════════════════════════════════════════
// The walk above DOES reach the shape below — `_portKeys` argues both
// routes to it — but only barely, and it warned that "add a step kind"
// would erode that. THAT HAS NOW HAPPENED. When this paragraph was
// written the 1,000 sequences built 90 connects, four of which found one
// end already materialised. Board #579 added nine Structure arms to the
// menu, and the same 1,000 sequences now build 18 connects. The old
// paragraph named the four seeds; they are not reproduced, because a
// seed list is the part that rots first and re-deriving it teaches
// nothing the sentence above does not.
//
// Nothing went red, which is the whole point: random coverage of the one
// `revert()` in this repository that reads the document rather than
// inverting itself is a fact about a seed, never a property of the
// harness. The pin below is the coverage that actually holds it, stated
// outright in the order a user meets it: two connects sharing one pin,
// then two undos in the reverse order.

const _busPin = PortKey('cresnet.1');
const _devA = Uuid('dev-a');
const _devB = Uuid('dev-b');
const _devC = Uuid('dev-c');

/// Three rail-placed devices on the fixture template, NOTHING
/// materialised — the state of every document built by dropping devices
/// out of the palette (AC-006), and the state the connect gesture is
/// actually used from.
RackDocument _threeDevices(DateTime at) {
  final doc = _freshDocumentWithOneRack(at);
  var ru = 1;
  for (final id in [_devA, _devB, _devC]) {
    AddDeviceCommand(
      kind: DeviceKind.rackDevice,
      templateRef: _templateRef,
      designator: 'DEV-${id.v}',
      name: 'Device ${id.v}',
      placement: RailPlacement(
        rackId: _rackId,
        ruIndex: ru++,
        face: Face.front,
      ),
      now: at,
      actor: 'gen',
      id: id,
    ).apply(doc);
  }
  return doc;
}

/// The real builder's command for [a]'s bus tap to [b]'s, asserting it was
/// not refused — every one of these pairs is legal, and a refusal here
/// would mean the fixture, not the command, is what this file is testing.
ConnectPortsCommand _connect(RackDocument doc, Uuid a, Uuid b, DateTime at) {
  final result = buildConnectPortsCommand(
    doc: doc,
    from: resolveConnectTarget(doc, deviceId: a, portKey: _busPin.v)!,
    to: resolveConnectTarget(doc, deviceId: b, portKey: _busPin.v)!,
    media: const MediaTypeId('media.cat6a_futp'),
    now: at,
    actor: 'gen',
  );
  return (result as ConnectPortsReady).command;
}

// ═════════════════════════════════════════════════════════════════════
// THE DANGLING ORIGIN, PINNED FOR THE SAME REASON THE CONNECT IS
// ═════════════════════════════════════════════════════════════════════
// Neither `RemoveOutletCommand` nor `RemoveStructureCommand` cascades,
// and that is a decision rather than an omission: an `Outlet` is a fact
// about the BUILDING (a plate on a wall) and survives the panel it
// currently feeds. The consequence is that a `Link.structureOrigin` whose
// `outletId` resolves to NOTHING is a reachable, legal document state —
// and the codec has to keep writing it faithfully, because the alternative
// is a save that quietly drops a cable somebody already pulled.
//
// The walk above reaches this now. It is pinned anyway, for the reason the
// connect pin gives directly above: what a random menu reaches is a fact
// about a seed.

RackDocument _oneDrop(DateTime at) {
  final doc = _freshDocumentWithOneRack(at);
  final result = buildAddHomeRunCommand(
    doc: doc,
    outletId: _seedOutletId,
    fieldLabel: 'GR-DATA-1',
    designator: 'W001',
    netName: 'N001',
    media: const MediaTypeId('media.cat6_utp'),
    fieldEnd: const PlaceEndpoint(description: 'Great Room'),
    terminationField: TerminationType.keystone,
    now: at,
    actor: 'gen',
  );
  (result as AddHomeRunReady).command.apply(doc);
  return doc;
}

void _pinDanglingOrigin() {
  group('a home run whose outlet is removed under it', () {
    test('still writes, and the removal round-trips byte-exactly', () {
      final at = DateTime.utc(2026);
      final doc = _oneDrop(at);
      final before = _codec.write(doc);

      final remove = RemoveOutletCommand(id: _seedOutletId)..apply(doc);
      expect(doc.outlets, isEmpty);
      expect(
        doc.links.values.single.structureOrigin!.outletId,
        _seedOutletId,
        reason:
            'the origin must keep naming the outlet it was pulled from; '
            'clearing it would erase which plate the cable serves',
      );

      // The state this pin exists for: the document has to SERIALISE with
      // the reference dangling.
      final withDangling = _codec.write(doc);
      expect(withDangling, isNot(equals(before)));

      remove.revert(doc);
      expect(_codec.write(doc), equals(before));
    });

    test('the schedule still carries the row, with its W number', () {
      // A cable that vanished from the schedule because someone deleted a
      // wall plate is the failure this whole no-cascade rule prevents.
      final at = DateTime.utc(2026);
      final doc = _oneDrop(at);
      RemoveOutletCommand(id: _seedOutletId).apply(doc);

      final row = buildSchedule(doc).rows.single;
      expect(row.designator, 'W001');
      expect(row.fieldLabel, 'GR-DATA-1');
    });

    test('removing the whole Structure body leaves both the outlet and '
        'the drop', () {
      final at = DateTime.utc(2026);
      final doc = _oneDrop(at);
      final before = _codec.write(doc);

      final remove = RemoveStructureCommand(bodyId: _seedBodyId)..apply(doc);
      expect(doc.structures, isEmpty);
      expect(doc.outlets, hasLength(1));
      expect(doc.links, hasLength(1));

      remove.revert(doc);
      expect(_codec.write(doc), equals(before));
    });
  });
}

void main() {
  test(
    '$_sequenceCount random command sequences: apply; revert restores '
    'byte-identical JSON (CR-117)',
    () {
      for (var i = 0; i < _sequenceCount; i++) {
        final seed = _baseSeed + i;
        final rnd = Random(seed);
        final startAt = DateTime.utc(2026);
        final doc = _freshDocumentWithOneRack(startAt);
        final state = _SequenceState(doc);

        final stepCount = 5 + rnd.nextInt(11); // 5..15 commands
        for (var step = 0; step < stepCount; step++) {
          final kinds = state.availableKinds();
          final kind = kinds[rnd.nextInt(kinds.length)];
          final cmd = _buildCommand(kind, state, rnd, step);
          // A refused connect wrote nothing and produced no command, so
          // there is no apply/revert pair to hold the byte property
          // against — see `_buildCommand`. Every other kind is total.
          if (cmd == null) continue;

          final before = _codec.write(doc);
          cmd
            ..apply(doc)
            ..revert(doc);
          final afterRevert = _codec.write(doc);

          final reason =
              'seed=$seed step=$step kind=$kind '
              'command=${cmd.runtimeType} — apply;revert did not restore '
              'a byte-identical document (CR-117). Reproduce with '
              'Random($seed).';
          expect(
            utf8.decode(afterRevert),
            equals(utf8.decode(before)),
            reason: reason,
          );
          expect(afterRevert, equals(before), reason: reason);

          // Commit for real (the trailing `apply` of `apply; revert;
          // apply`), so later steps in this sequence can reference
          // whatever this command just did.
          cmd.apply(doc);
          _reconcileTrackingAfterCommit(kind, cmd, state);
        }
      }
    },
  );

  _pinDanglingOrigin();

  group('ConnectPortsCommand — the data-dependent revert, pinned', () {
    test('BOTH pins new: undo removes both, redo mints the same two', () {
      final at = DateTime.utc(2026);
      final doc = _threeDevices(at);
      final before = _codec.write(doc);
      expect(doc.ports, isEmpty, reason: 'nothing is materialised yet');

      final cmd = _connect(doc, _devA, _devB, at)..apply(doc);
      final applied = _codec.write(doc);
      expect(doc.ports.keys.toSet(), {
        derivePortId(_devA, _busPin),
        derivePortId(_devB, _busPin),
      });
      expect(
        applied,
        isNot(before),
        reason: 'guards the assertions below against passing vacuously',
      );

      cmd.revert(doc);
      expect(
        doc.ports,
        isEmpty,
        reason:
            'both pins were this apply()s to mint, so both are its to '
            'remove',
      );
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
      expect(_codec.write(doc), before);

      cmd.apply(doc);
      expect(
        _codec.write(doc),
        applied,
        reason: 'redo recreates identical entities, ports included',
      );
    });

    test('ONE pin already there: undo removes ONLY the pin it minted', () {
      // A-B, then A-C. A's pin is a bus tap, so the second connect is
      // legal and finds it ALREADY MATERIALISED — the one state in which
      // this revert has to read the document to know what it owns.
      final at = DateTime.utc(2026);
      final doc = _threeDevices(at);
      final aPin = derivePortId(_devA, _busPin);
      final bPin = derivePortId(_devB, _busPin);
      final cPin = derivePortId(_devC, _busPin);
      final empty = _codec.write(doc);

      final first = _connect(doc, _devA, _devB, at)..apply(doc);
      final afterFirst = _codec.write(doc);
      expect(doc.ports.keys.toSet(), {aPin, bPin});

      final second = _connect(
        doc,
        _devA,
        _devC,
        at.add(const Duration(seconds: 1)),
      )..apply(doc);
      expect(
        doc.ports.keys.toSet(),
        {aPin, bPin, cPin},
        reason:
            'the second connect mints C and leaves A exactly as it '
            'found it (materialisation is idempotent)',
      );

      second.revert(doc);
      expect(
        doc.ports.keys.toSet(),
        {aPin, bPin},
        reason:
            "A's pin was in the document before this command ran, so it is "
            'not this command to remove: taking it would discard the '
            'designator, notes and network config the port carries AND '
            "dangle the FIRST link's conductor endpoint, with nothing on "
            'any sheet saying so',
      );
      expect(
        _codec.write(doc),
        afterFirst,
        reason: 'CR-117 — byte identity, not a semantic near-miss',
      );

      first.revert(doc);
      expect(
        doc.ports,
        isEmpty,
        reason:
            'and undoing the first one does take A and B, because that '
            'is the apply() that put them there',
      );
      expect(_codec.write(doc), empty);
    });
  });
}
