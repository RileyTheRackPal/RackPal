// The Device Builder's command set over the PORTS of a `TemplateBody`
// (M4-E, #176), sitting beside `template_commands.dart`'s metadata
// fields on the same `TemplateEditSession` stack (CR-106).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS A SECOND FILE AND NOT MORE ROWS IN `TemplateBodyField`
// ═══════════════════════════════════════════════════════════════════════
// A `TemplateField` reads and writes the body. A port lives in a LIST on
// the body and is found by `PortKey`, so every command here carries a key
// and can fail to find its subject. That is a different shape, and
// folding it into `TemplateField` would mean either a nullable body
// accessor or a field table whose entries only work for one port.
//
// ═══════════════════════════════════════════════════════════════════════
// NO COALESCING, ON PURPOSE, AND IT IS NOT AN OVERSIGHT
// ═══════════════════════════════════════════════════════════════════════
// `SetTemplateFieldCommand` merges per field, because M4-D's form writes
// on every keystroke and a typed manufacturer must be one undo entry.
// A grid cell does not write on every keystroke: docs/06 §4.6 rules that
// `Enter` commits and moves down, `Tab` commits and moves right, `Esc`
// reverts. One committed value is one edit, so `mergeKey` stays null and
// two deliberate changes to the same cell stay two undo entries.
//
// It also removes a trap. `renamedFrom` accumulates on a key rename, so a
// merged rename would have to reconstruct an alias list its own `apply`
// never produced, and redo would land on a state that undo did not come
// from. Not merging makes the question disappear rather than answering it.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// A port with no panel geometry yet. Panel layout is M4-K (`#182`), and
/// until it runs every authored port sits at the origin; the catalog's own
/// `PortBuilder` uses exactly this value for the same reason.
const kUnplacedPanelPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len(0),
  yFineNm: Len(0),
);

/// A typed accessor for one editable property of a [PortDef].
///
/// `TemplateField`'s sibling, and deliberately the same shape so the grid
/// and the form are one mechanism seen twice. The difference is what the
/// accessors take: a [PortDef] rather than the whole body, because the
/// command has already resolved the key by the time these run.
final class PortField<T> {
  const PortField({required this.key, required this.get, required this.set});

  /// Stable, unique within [PortDefField.all] (asserted by test). It is
  /// the column's identity in an undo entry and in a test's expectations.
  final String key;

  final T Function(PortDef port) get;
  final void Function(PortDef port, T value) set;

  @override
  String toString() => 'PortField($key)';
}

/// The [PortDef] properties the grid's CORE columns edit (docs/06 §4.5).
///
/// **Nine of the port's ~35 fields, and the same restraint
/// `TemplateBodyField` opened with.** The seven column packs are M4-E3 and
/// bring their own entries; adding them now would be twenty-six accessors
/// with no cell in front of them, which is the state this package already
/// found `NetworkConfig` in.
///
/// `key` is NOT here, and cannot be: `PortDef.key` is `final`, so renaming
/// one is a replacement rather than a write. See [RenamePortKeyCommand].
abstract final class PortDefField {
  /// The silkscreen text. `HDMI IN 1`.
  static const label = PortField<String>(
    key: 'label',
    get: _getLabel,
    set: _setLabel,
  );

  /// The template's SEED for a designator, never the designator itself.
  ///
  /// CR-042 rules that the template supplies a hint and the PROJECT
  /// allocates: `Port.designator` is rendered at instantiation from
  /// `ProjectSettings.portDesignatorFormat` (`J{PORT_SEQ:2}` by default),
  /// and is unique within the device. So the grid's `Designator` column
  /// shows the allocated value while this is absent, and this value once
  /// it is set. Absent is UNKNOWN in the ordinary G4 sense: nobody has
  /// pinned one, and the project is free to number it.
  static const designatorHint = PortField<String?>(
    key: 'designatorHint',
    get: _getDesignatorHint,
    set: _setDesignatorHint,
  );

  /// One of three orthogonal axes, and the reason the DSL can say `hdbt`
  /// and `rj45` in one breath: the same connector carries many families.
  static const connector = PortField<ConnectorTypeId>(
    key: 'connector',
    get: _getConnector,
    set: _setConnector,
  );

  static const signalFamily = PortField<SignalFamilyId>(
    key: 'signalFamily',
    get: _getSignalFamily,
    set: _setSignalFamily,
  );

  /// FIVE values (CR-060). The catalog's old four-letter notation
  /// collapsed `busNode` and `passive` into one letter and silently broke
  /// `DIR-002`, `BUS-001` and `BUS-002`, which is why the grid cell spells
  /// each one out rather than abbreviating it back.
  static const direction = PortField<PortDirection>(
    key: 'direction',
    get: _getDirection,
    set: _setDirection,
  );

  static const face = PortField<Face>(
    key: 'face',
    get: _getFace,
    set: _setFace,
  );

  /// PRESENTATION grouping (CR-055), and the grid's own row bands.
  static const bankKey = PortField<String?>(
    key: 'bankKey',
    get: _getBankKey,
    set: _setBankKey,
  );

  /// ELECTRICAL grouping (CR-055): Y/Pb/Pr, L/R, speaker +/-.
  static const setKey = PortField<String?>(
    key: 'setKey',
    get: _getSetKey,
    set: _setSetKey,
  );

  static const setRole = PortField<String?>(
    key: 'setRole',
    get: _getSetRole,
    set: _setSetRole,
  );

  static const notes = PortField<String?>(
    key: 'notes',
    get: _getNotes,
    set: _setNotes,
  );

  /// Every entry above. The unit test walks this to prove no two share a
  /// [PortField.key] and that no accessor pair is aliased onto another
  /// field, which is the census M4-A's field table needed three attempts
  /// to get right.
  static const all = <PortField<Object?>>[
    label,
    designatorHint,
    connector,
    signalFamily,
    direction,
    face,
    bankKey,
    setKey,
    setRole,
    notes,
  ];
}

String _getLabel(PortDef p) => p.label;
void _setLabel(PortDef p, String v) => p.label = v;

String? _getDesignatorHint(PortDef p) => p.designatorHint;
void _setDesignatorHint(PortDef p, String? v) => p.designatorHint = v;

ConnectorTypeId _getConnector(PortDef p) => p.connector;
void _setConnector(PortDef p, ConnectorTypeId v) => p.connector = v;

SignalFamilyId _getSignalFamily(PortDef p) => p.signalFamily;
void _setSignalFamily(PortDef p, SignalFamilyId v) => p.signalFamily = v;

PortDirection _getDirection(PortDef p) => p.direction;
void _setDirection(PortDef p, PortDirection v) => p.direction = v;

Face _getFace(PortDef p) => p.face;
void _setFace(PortDef p, Face v) => p.face = v;

String? _getBankKey(PortDef p) => p.bankKey;
void _setBankKey(PortDef p, String? v) => p.bankKey = v;

String? _getSetKey(PortDef p) => p.setKey;
void _setSetKey(PortDef p, String? v) => p.setKey = v;

String? _getSetRole(PortDef p) => p.setRole;
void _setSetRole(PortDef p, String? v) => p.setRole = v;

String? _getNotes(PortDef p) => p.notes;
void _setNotes(PortDef p, String? v) => p.notes = v;

/// The port [key] names, or a [StateError] naming what went wrong.
///
/// THROWS RATHER THAN RETURNING NULL. A command that cannot find its
/// subject is being applied to an aggregate it was not built against, and
/// the undo stack's contract is that `apply` and `revert` are exact. A
/// silent no-op here would leave the stack believing a write happened.
PortDef portByKey(TemplateBody body, PortKey key) {
  for (final port in body.ports) {
    if (port.key.v == key.v) return port;
  }
  throw StateError('no port ${key.v} on this template');
}

/// Sets one [PortField] on one port of the [TemplateBody] a
/// `TemplateEditSession` is editing.
final class SetPortFieldCommand<T> extends Command<TemplateBody> {
  const SetPortFieldCommand({
    required this.port,
    required this.field,
    required this.from,
    required this.to,
  });

  final PortKey port;
  final PortField<T> field;
  final T from;
  final T to;

  @override
  LabelKey get label => LabelKey.setPortProperty;

  /// Null for `SetTemplateFieldCommand`'s reason: a `TemplateBody` has no
  /// epoch model at all, and saying `EpochMask.none` would claim it has
  /// one that this command happens not to dirty.
  @override
  EpochMask? get touches => null;

  /// Empty, and honestly so: the derived layer is keyed on document
  /// entities, and a port inside a template body is keyed by `PortKey`.
  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) =>
      field.set(portByKey(aggregate, port), to);

  @override
  void revert(TemplateBody aggregate) =>
      field.set(portByKey(aggregate, port), from);
}

/// Appends one port to the end of the template.
///
/// ═══════════════════════════════════════════════════════════════════════
/// APPEND, AND ONLY APPEND, BECAUSE TWO ORDERS MUST NOT DISAGREE
/// ═══════════════════════════════════════════════════════════════════════
/// `PortDef.order` is a `FracIndex` compared as a raw string, and nothing
/// in this package mints one BETWEEN two others: `nextOrder`'s own comment
/// says the general form would be untested generality, and it still would
/// be. So a new port takes the largest order plus one and lands last.
///
/// The grid bands rows by bank in first-appearance order, so a port that
/// inherits the bank of the row above it appears at the bottom of that
/// band AND at the end of the declared order, and the two readings agree.
/// Inserting into the middle of an earlier bank would break that tie, and
/// that is a reorder: M4-F4 (`#211`), which is where the midpoint
/// generator belongs if it is ever built.
///
/// HOLDS THE PORT IT ADDED rather than a copy. `revert` takes the object
/// out of the list and `apply` puts the same one back, which is what makes
/// redo restore the identical port; between the two nothing can reach it
/// to mutate it, because it is in no list.
final class AddPortCommand extends Command<TemplateBody> {
  const AddPortCommand(this.port);

  final PortDef port;

  @override
  LabelKey get label => LabelKey.addPort;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) => aggregate.ports.add(port);

  @override
  void revert(TemplateBody aggregate) {
    final at = aggregate.ports.indexWhere((p) => p.key.v == port.key.v);
    if (at < 0) throw StateError('no port ${port.key.v} to remove');
    aggregate.ports.removeAt(at);
  }
}

/// Removes one port, and every passthrough pair that named it.
///
/// **THE PAIRS GO WITH IT, AND COME BACK WITH IT.** A `PassthroughPairDef`
/// holds two `PortKey`s and nothing enforces that either resolves, so
/// deleting one half of a pair without deleting the pair leaves a dangling
/// reference in the file that reads as a pairing the user can no longer
/// see. docs/06 §4.6 asks the UI to WARN before this happens; the warning
/// is a dialog and this is the correctness half underneath it.
final class RemovePortCommand extends Command<TemplateBody> {
  RemovePortCommand(this.port);

  final PortKey port;

  /// Captured by [apply] so [revert] can put the port back where it was
  /// rather than at the end. Index matters: `ports` is read in list order
  /// by the codec, and a byte round-trip (CR-117) that reorders the list
  /// is a diff nobody asked for.
  int? _at;
  PortDef? _removed;
  List<PassthroughPairDef>? _pairs;

  @override
  LabelKey get label => LabelKey.removePort;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) {
    final at = aggregate.ports.indexWhere((p) => p.key.v == port.v);
    if (at < 0) throw StateError('no port ${port.v} to remove');
    _at = at;
    _removed = aggregate.ports.removeAt(at);
    _pairs = List<PassthroughPairDef>.from(aggregate.passthroughPairs);
    aggregate.passthroughPairs.removeWhere(
      (pair) => pair.frontKey.v == port.v || pair.rearKey.v == port.v,
    );
  }

  @override
  void revert(TemplateBody aggregate) {
    final at = _at;
    final removed = _removed;
    final pairs = _pairs;
    if (at == null || removed == null || pairs == null) {
      throw StateError('revert before apply');
    }
    aggregate.ports.insert(at, removed);
    aggregate.passthroughPairs
      ..clear()
      ..addAll(pairs);
  }
}

/// Renames a port's [PortKey], which is a REPLACEMENT rather than a write.
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY THIS IS NOT A `PortField`
/// ═══════════════════════════════════════════════════════════════════════
/// `PortDef.key` is `final`, and deliberately: it is the template
/// migration join (CR-051), the one thing that makes an existing project's
/// cables survive a template revision. A rename therefore builds a new
/// `PortDef` carrying every other value across, and rewrites the two
/// places inside a body that name a port by key: `passthroughPairs`, and
/// the port's own `renamedFrom`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// [recordAlias] IS THE CALLER'S CALL, AND HERE IS THE RULE
/// ═══════════════════════════════════════════════════════════════════════
/// `renamedFrom` exists so a migration can join `hdmi.in.1` to the port
/// that used to be called `hdmi1`. That is only a fact worth keeping when
/// the OLD key was published: a port invented ten seconds ago in this
/// editing session has never been in any project, so recording its
/// working-title key would put permanent noise in the file and in every
/// future diff. So the grid passes `false` for ports it created this
/// session and `true` for ports that were in the template when it opened.
final class RenamePortKeyCommand extends Command<TemplateBody> {
  const RenamePortKeyCommand({
    required this.from,
    required this.to,
    required this.recordAlias,
  });

  final PortKey from;
  final PortKey to;
  final bool recordAlias;

  @override
  LabelKey get label => LabelKey.renamePortKey;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) => _rename(
    aggregate,
    was: from,
    now: to,
    aliases: (existing) => [
      ...existing,
      if (recordAlias && !existing.any((k) => k.v == from.v)) from,
    ],
  );

  @override
  void revert(TemplateBody aggregate) => _rename(
    aggregate,
    was: to,
    now: from,
    // Drop exactly what `apply` added, and nothing else: an alias that was
    // already on the port before this command must survive its undo.
    aliases: (existing) => recordAlias
        ? [
            for (final k in existing)
              if (k.v != from.v) k,
          ]
        : existing,
  );

  void _rename(
    TemplateBody body, {
    required PortKey was,
    required PortKey now,
    required List<PortKey> Function(List<PortKey>) aliases,
  }) {
    final at = body.ports.indexWhere((p) => p.key.v == was.v);
    if (at < 0) throw StateError('no port ${was.v} to rename');
    if (body.ports.any((p) => p.key.v == now.v)) {
      throw StateError('port ${now.v} already exists');
    }
    body.ports[at] = _withKey(
      body.ports[at],
      now,
      aliases(body.ports[at].renamedFrom),
    );

    for (var i = 0; i < body.passthroughPairs.length; i++) {
      final pair = body.passthroughPairs[i];
      if (pair.frontKey.v != was.v && pair.rearKey.v != was.v) continue;
      body.passthroughPairs[i] = PassthroughPairDef(
        frontKey: pair.frontKey.v == was.v ? now : pair.frontKey,
        rearKey: pair.rearKey.v == was.v ? now : pair.rearKey,
        sameNet: pair.sameNet,
      );
    }
  }
}

/// [port] with a different [key] and [renamedFrom], and every other field
/// carried across.
///
/// EVERY FIELD, WHICH IS WHY IT IS EXHAUSTIVE AND UGLY. A rename that
/// silently dropped `poe` or `serial` would be a data loss with no error
/// and no visible symptom until an export. `port_commands_test.dart`
/// mutates every field of a port, renames it, and asserts the encoded JSON
/// differs only in `key`, which is a check that survives a new field being
/// added to `PortDef` because the codec is what it reads.
PortDef _withKey(PortDef port, PortKey key, List<PortKey> renamedFrom) =>
    PortDef(
      key: key,
      label: port.label,
      connector: port.connector,
      signalFamily: port.signalFamily,
      face: port.face,
      position: port.position,
      order: port.order,
      renamedFrom: renamedFrom,
      designatorHint: port.designatorHint,
      carriedProtocols: List<SignalFamilyId>.from(port.carriedProtocols),
      acceptedFamilies: List<SignalFamilyId>.from(port.acceptedFamilies),
      direction: port.direction,
      returnChannel: port.returnChannel,
      topology: port.topology,
      maxConnections: port.maxConnections,
      gender: port.gender,
      pinoutVariant: port.pinoutVariant,
      conductorCount: port.conductorCount,
      impedanceOhms: port.impedanceOhms,
      level: port.level,
      balanced: port.balanced,
      phantomPowerCapable: port.phantomPowerCapable,
      polarity: port.polarity,
      nominalVoltage: port.nominalVoltage,
      maxCurrentMa: port.maxCurrentMa,
      bankKey: port.bankKey,
      setKey: port.setKey,
      setRole: port.setRole,
      channelIndex: port.channelIndex,
      poe: port.poe,
      linkSpeedMbps: port.linkSpeedMbps,
      sfp: port.sfp,
      fiberMode: port.fiberMode,
      wavelengthNm: port.wavelengthNm,
      bus: port.bus,
      serial: port.serial,
      power: port.power,
      notes: port.notes,
    );

/// A key derived from [label], in the catalog's own dotted-lowercase
/// spelling (`HDMI IN 1` becomes `hdmi.in.1`), made unique against [taken].
///
/// **A DOT AND NOT A HYPHEN.** `export_controller.dart`'s `slugify` builds
/// FILE names and hyphenates for the filesystem's sake; every port key in
/// the seeded catalog is dotted (`hdmi.in.1`, `hdbt.out.8`, `spk.a.plus`),
/// and a builder that minted a second convention would make the catalog
/// and the user's own templates read as two products.
///
/// [ordinal] names the fallback for a label that slugs to nothing, which
/// is every brand-new row: a port must have a key from the moment it
/// exists, because the key is what every command here addresses it by.
PortKey autoPortKey(
  String label, {
  required Set<String> taken,
  required int ordinal,
}) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  final base = slug.isEmpty ? 'port.$ordinal' : slug;
  if (!taken.contains(base)) return PortKey(base);
  for (var n = 2; ; n++) {
    final candidate = '$base.$n';
    if (!taken.contains(candidate)) return PortKey(candidate);
  }
}

/// A blank port appended to [body], carrying the bank of the last port so
/// that clicking `+ Add port` twice inside a bank adds twice to that bank.
///
/// EMPTY LABEL, AND NOT `Port 4`. A placeholder label would be written to
/// the file the moment the user saved without touching it, and a template
/// full of `Port 4` is worse than one full of blanks: the blank is visibly
/// unfinished and the placeholder is not. The key cannot be blank for the
/// same reason it cannot be a UUID, so it falls back to `port.<n>` and
/// follows the label as soon as there is one (M4-E2).
PortDef blankPort(TemplateBody body, {String? bankKey}) {
  final taken = {for (final p in body.ports) p.key.v};
  return PortDef(
    key: autoPortKey('', taken: taken, ordinal: body.ports.length + 1),
    label: '',
    connector: const ConnectorTypeId(''),
    signalFamily: const SignalFamilyId(''),
    face: Face.rear,
    position: kUnplacedPanelPosition,
    order: nextOrder(body.ports.map((p) => p.order)),
    bankKey: bankKey ?? (body.ports.isEmpty ? null : body.ports.last.bankKey),
  );
}
