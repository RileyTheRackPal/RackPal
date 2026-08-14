// The Device Builder's command set over a `TemplateBody` (CR-106,
// docs/03-architecture.md §5.6), and the first `Command` in this package
// whose aggregate is not a `RackDocument`.
//
// WHAT THIS FILE IS NOT. It is not the builder's form and it is not the
// port grid; those are M4-D (#175) and M4-E (#176) and they will add
// their own commands here. This file exists because M4-A/4 builds the
// builder's undo STACK, and a stack with no command type on it is a type
// parameter rather than a mechanism: nothing could be pushed, so nothing
// could be tested, and the first real command would be free to invent a
// second way of doing this. The `TemplateField` table below therefore
// starts at the metadata fields M4-D's form is about and stops there.
//
// NO CALLER YET, STATED RATHER THAN IMPLIED. Nothing in `rackmate_ui` or
// `apps/rackmate` reaches this today; M4-D is what puts a text box in
// front of it. That is the shape `a modelled field is not a reachable
// one` warns about, so it is named here instead of being discovered
// later: the reachability this file is waiting on is a whole editor
// window, not a missing wire.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// A typed accessor for one editable property of a [TemplateBody]: how to
/// read it and how to write it.
///
/// The document side's equivalent is `EntityField`, and this one is
/// deliberately smaller in two ways. It carries no `EntityAccess`,
/// because there is exactly one aggregate here and no map to find it in;
/// and it carries no `EpochMask`, because a `TemplateBody` has no epochs
/// at all (see [SetTemplateFieldCommand.touches]).
final class TemplateField<T> {
  const TemplateField({
    required this.key,
    required this.get,
    required this.set,
  });

  /// A stable identifier, unique within [TemplateBodyField.all] (asserted
  /// by the unit test), because it is half of
  /// [SetTemplateFieldCommand.mergeKey] and therefore what makes
  /// coalescing per-property: typing a manufacturer collapses into one
  /// undo entry, and then typing a model does not join it.
  final String key;

  final T Function(TemplateBody body) get;
  final void Function(TemplateBody body, T value) set;

  @override
  String toString() => 'TemplateField($key)';
}

/// The `TemplateBody` metadata fields the builder's form edits.
///
/// **Five of the body's ~50 fields, on purpose.** These are the ones
/// M4-D's metadata form is made of; the occupancy, power, thermal and
/// port fields arrive with the sections that edit them, each with the
/// validation that section owns. Adding all fifty now would be fifty
/// entries nothing reads, which is the state this package already found
/// `NetworkConfig` in.
abstract final class TemplateBodyField {
  /// "Extron". Free text, not a registry: the long tail is the whole
  /// reason the builder exists.
  static const manufacturer = TemplateField<String>(
    key: 'manufacturer',
    get: _getManufacturer,
    set: _setManufacturer,
  );

  /// "DTP CrossPoint 84".
  static const model = TemplateField<String>(
    key: 'model',
    get: _getModel,
    set: _setModel,
  );

  /// What the elevation and the equipment list print.
  static const displayName = TemplateField<String>(
    key: 'displayName',
    get: _getDisplayName,
    set: _setDisplayName,
  );

  /// "MTX" — seeds the designator format, and one of the three fields
  /// M4-D's form requires.
  static const typePrefix = TemplateField<String?>(
    key: 'typePrefix',
    get: _getTypePrefix,
    set: _setTypePrefix,
  );

  /// Rack units on the front face. The second of M4-D's three required
  /// fields, and the one a user gets wrong most cheaply: `0` is a
  /// MEASURED zero here (a zero-U device), never an unknown, so this
  /// field is an `int` and not an `int?` (G4 cuts the other way for
  /// occupancy than it does for weight).
  static const frontU = TemplateField<int>(
    key: 'frontU',
    get: _getFrontU,
    set: _setFrontU,
  );

  /// Every field above, for the uniqueness test and for a future batch
  /// inspector. Order is presentation order, not significance.
  static const all = <TemplateField<Object?>>[
    manufacturer,
    model,
    displayName,
    typePrefix,
    frontU,
  ];
}

String _getManufacturer(TemplateBody b) => b.manufacturer;
void _setManufacturer(TemplateBody b, String v) => b.manufacturer = v;

String _getModel(TemplateBody b) => b.model;
void _setModel(TemplateBody b, String v) => b.model = v;

String _getDisplayName(TemplateBody b) => b.displayName;
void _setDisplayName(TemplateBody b, String v) => b.displayName = v;

String? _getTypePrefix(TemplateBody b) => b.typePrefix;
void _setTypePrefix(TemplateBody b, String? v) => b.typePrefix = v;

int _getFrontU(TemplateBody b) => b.frontU;
void _setFrontU(TemplateBody b, int v) => b.frontU = v;

/// Sets one [TemplateField] on the [TemplateBody] a
/// `TemplateEditSession` is editing.
///
/// Simpler than its document sibling by exactly what a `TemplateBody`
/// lacks: no `EntityMeta` to touch and restore, so `revert` is the
/// `from` value written back and nothing else. `MoveDeviceCommand`'s
/// warning about a revision left one higher than it started has no
/// analogue here, because a template body carries no revision.
final class SetTemplateFieldCommand<T> extends Command<TemplateBody> {
  const SetTemplateFieldCommand({
    required this.field,
    required this.from,
    required this.to,
  });

  final TemplateField<T> field;
  final T from;
  final T to;

  @override
  LabelKey get label => LabelKey.setTemplateProperty;

  /// NULL, and not [EpochMask.none]. `none` would assert that this
  /// command dirties no document epoch, which is true but useless; null
  /// says a `TemplateBody` has no epoch model to dirty, which is the
  /// actual fact and the one that stops somebody wiring the builder into
  /// `DocEpochs` (command.dart, `DocEpochs.bump`).
  @override
  EpochMask? get touches => null;

  /// Empty, and honestly so: `affects` hands the DERIVED layer its
  /// invalidation set, the derived layer is keyed on document entities,
  /// and this command touches none of them. A `TemplateBody`'s parts are
  /// keyed by `PortKey` and `BankKey`, which are not `Uuid`s.
  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  /// Per field, so a run of keystrokes in one box is one undo entry and
  /// moving to the next box starts another. No entity id in the key,
  /// unlike `SetEntityPropertyCommand`: there is one body per session.
  @override
  Object? get mergeKey => (SetTemplateFieldCommand, field.key);

  @override
  void apply(TemplateBody aggregate) => field.set(aggregate, to);

  @override
  void revert(TemplateBody aggregate) => field.set(aggregate, from);

  @override
  Command<TemplateBody>? mergeWith(Command<TemplateBody> next) {
    if (next is! SetTemplateFieldCommand<T>) return null;
    if (next.field.key != field.key) return null;
    // Spans from where THIS command started to where the next one ended,
    // which is what makes the merged pair one undo step.
    return SetTemplateFieldCommand<T>(field: field, from: from, to: next.to);
  }
}
