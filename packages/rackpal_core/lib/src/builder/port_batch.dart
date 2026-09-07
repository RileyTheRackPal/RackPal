// MULTI-ROW EDIT AND THE BATCH INSPECTOR (DR-063, M4-F2 `#209`,
// docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// MIXED AND UNKNOWN ARE TWO ANSWERS, AND docs/06 SPELLS THEM THE SAME WAY
// ═══════════════════════════════════════════════════════════════════════
// §4.6's multi-row row says mixed values "render `—` and are left
// untouched unless explicitly set". The second half is right and is
// enforced below. The first half collides with G4: `—` is `kUnknownCell`,
// and it means NOBODY HAS MEASURED THIS everywhere else in the product.
//
// Eight ports nobody has measured and eight ports carrying 75 Ω and 110 Ω
// are different facts. An installer reading `—` on IMPEDANCE would
// conclude the first while the second is true, on the one surface built
// specifically for looking at many rows at once. DR-063 therefore keeps
// `—` for unknown and gives disagreement its own reading, which names how
// many distinct values are in the selection.
//
// CR-114's rule stated the other way round: a rollup reports its unknown
// count rather than fabricating a total. This is the same discipline
// applied to a column of N rows instead of to a document.
//
// ═══════════════════════════════════════════════════════════════════════
// NOTHING HERE WRITES. `summarise` reads and `buildBatchWrite` returns
// commands, exactly as `port_fill.dart` does, so both halves of F2 are
// testable without pumping a frame.
import 'package:rackpal_core/src/builder/port_fill.dart';
import 'package:rackpal_core/src/builder/port_table.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What one column holds across a selection.
sealed class BatchValue {
  const BatchValue();
}

/// Every selected row carries the same non-null value.
final class BatchAgreed extends BatchValue {
  const BatchAgreed(this.value);

  final Object value;
}

/// Every selected row is UNKNOWN. `—`, and it means what it always means.
final class BatchUnknown extends BatchValue {
  const BatchUnknown();
}

/// The selected rows DISAGREE, over [distinct] different values.
///
/// NOT `—`, and DR-063 is why. [distinct] counts an unknown as one of the
/// values it disagrees over, because "three are 75 Ω and five are
/// unmeasured" is a disagreement and reporting it as agreement in either
/// direction would be a fabrication.
final class BatchMixed extends BatchValue {
  const BatchMixed(this.distinct);

  final int distinct;
}

/// What [column] holds across [portKeys] in [body].
///
/// TOTAL, and never throws: a key the body no longer holds is skipped, so
/// a stale selection summarises to a smaller answer rather than to a
/// crash. An empty or single-key selection is not this function's problem
/// and answers honestly from what it is given.
BatchValue summariseBatch({
  required TemplateBody body,
  required PortColumnId column,
  required List<String> portKeys,
}) {
  final target = portColumnFill(column);
  if (target == null) return const BatchUnknown();

  final byKey = {for (final port in body.ports) port.key.v: port};

  // A LIST AND NOT A `Set`, because the values are `Object?` and some are
  // extension types over `String`. `Set` would be fine for equality here,
  // and a list of at most N entries with a linear scan is both fine and
  // obviously correct; the count is what matters and N is a selection.
  final seen = <Object?>[];
  for (final key in portKeys) {
    final port = byKey[key];
    if (port == null) continue;
    final value = target.read(port);
    if (!seen.any((s) => _sameBatchValue(column, s, value))) seen.add(value);
  }

  if (seen.isEmpty) return const BatchUnknown();
  if (seen.length > 1) return BatchMixed(seen.length);
  final only = seen.first;
  return only == null ? const BatchUnknown() : BatchAgreed(only);
}

/// Whether two readings of [column] are the same value.
///
/// **`==` FOR EVERY COLUMN BUT ONE, AND THE EXCEPTION IS NOT COSMETIC.**
/// `acceptedFamilies` holds a `List`, where `==` is IDENTITY: two ports
/// that both accept nothing hold two different empty lists, so a plain
/// `contains` would find every row distinct and report `Mixed (8 values)`
/// on a selection that agrees completely. The dock would then offer no
/// ticks on eight identical ports (DR-134 §11.133).
///
/// `acceptedFamiliesEqual` is core's one rule for this, shared with the
/// fill path and the grid cell.
bool _sameBatchValue(PortColumnId column, Object? a, Object? b) {
  if (column == PortColumnId.acceptedFamilies && a is List && b is List) {
    return acceptedFamiliesEqual(
      a.cast<SignalFamilyId>(),
      b.cast<SignalFamilyId>(),
    );
  }
  return a == b;
}

/// Whether [column] may be written across a whole selection at once.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE IDENTITY COLUMNS ARE EXCLUDED, AND IT IS NOT SQUEAMISHNESS
/// ═══════════════════════════════════════════════════════════════════════
/// `LABEL` and `DESIG` name ONE port each. Writing one label into eight
/// selected rows gives eight ports called `HDMI IN`, and on a port this
/// session created the KEY follows the label, so the same gesture also
/// mints eight colliding keys that `autoPortKey` suffixes to `.2`, `.3`,
/// `.4` and onward. That is a mess a person unpicks by hand, and they
/// will not notice until several edits later.
///
/// THE CAPABILITY IS NOT LOST, IT IS ROUTED. `Ctrl+Shift+D` writes a
/// COLUMN of labels and is the gesture designed for exactly this
/// (DR-062), so the answer to "I want all sixteen named" is a key that
/// already exists rather than one that collides.
///
/// `KEY`, `PAIRED WITH` and `WAS CALLED` are absent for [portColumnFill]'s
/// reasons, which have not changed.
bool portColumnBatchEditable(PortColumnId column) => switch (column) {
  PortColumnId.label || PortColumnId.designator => false,
  _ => portColumnFill(column) != null,
};

/// Every column a batch edit may write, in reading order.
List<PortColumnId> get portBatchColumns => [
  for (final id in PortColumnId.values)
    if (portColumnBatchEditable(id)) id,
];

/// Writes [value] into [column] on every one of [portKeys].
///
/// LEFT UNTOUCHED UNLESS EXPLICITLY SET is §4.6's rule and the whole
/// safety property of this feature, and it is honoured by there being no
/// way to express "write the mixed state back": this function takes a
/// value a caller chose. A row already holding it produces no command, so
/// the transaction contains only real changes and an undo of it does not
/// step through writes that changed nothing.
///
/// [value] MUST be the column's own type. It comes from the control the
/// inspector drew for that column, which is built from the same
/// [PortColumnId], so there is one place for the two to disagree and it
/// is covered by test.
List<Command<TemplateBody>> buildBatchWrite({
  required TemplateBody body,
  required PortColumnId column,
  required List<String> portKeys,
  required Object? value,
}) {
  final target = portColumnFill(column);
  if (target == null || !portColumnBatchEditable(column)) {
    return const [];
  }
  final byKey = {for (final port in body.ports) port.key.v: port};
  return [
    for (final key in portKeys)
      if (byKey[key] case final PortDef port)
        if (target.write(port, value) case final Command<TemplateBody> w) w,
  ];
}

/// What the batch inspector prints for [value] in [column].
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE VOCABULARY, AND IT IS ALREADY WRITTEN
/// ═══════════════════════════════════════════════════════════════════════
/// Every spelling below comes from `port_table.dart`'s label functions,
/// the same ones the grid's cells use. The moment this file writes
/// `value.name` the product owns a second speller, and the first time one
/// of them changes the dock and the grid disagree about what a port is
/// while both are on screen at once.
///
/// [registries] resolves the two id columns, and a value it does not hold
/// prints the raw id for `portConnectorText`'s reason: the fact stays
/// visible and the pane stays on screen.
String portValueLabel(
  PortColumnId column,
  Object? value,
  Registries registries,
) {
  if (value == null) return kUnknownCell;
  return switch (column) {
    PortColumnId.connector =>
      portConnectorText(registries, value as ConnectorTypeId) ?? kUnknownCell,
    PortColumnId.family =>
      portFamilyText(registries, value as SignalFamilyId) ?? kUnknownCell,
    PortColumnId.direction => portDirectionLabel(value as PortDirection),
    PortColumnId.face => portFaceLabel(value as Face),
    PortColumnId.audioLevel => portAudioLevelLabel(value as AudioLevel),
    PortColumnId.polarity => portPolarityLabel(value as Polarity),
    PortColumnId.poeRole => portPoeRoleLabel(value as PoeRole),
    PortColumnId.poeStandard => portPoeStandardLabel(value as PoeStandard),
    PortColumnId.sfpFormFactor => portSfpLabel(value as SfpFormFactor),
    PortColumnId.fiberMode => portFiberModeLabel(value as FiberMode),
    PortColumnId.serialRole => portSerialRoleLabel(value as SerialRole),
    PortColumnId.powerRole => portPowerRoleLabel(value as PortPowerRole),
    PortColumnId.topology => portTopologyLabel(value as PortTopology),
    PortColumnId.gender => portGenderLabel(value as Gender),
    PortColumnId.returnChannel => portReturnChannelLabel(
      value as ReturnChannel,
    ),
    // THE ONLY LIST-VALUED COLUMN (DR-134 §11.133). It must be named
    // here rather than falling to the `toString` arm below, which would
    // print `[SignalFamilyId(ctl.ir_emitter)]` on a batch dock.
    PortColumnId.acceptedFamilies => acceptedFamiliesCellText(
      registries,
      (value as List).cast<SignalFamilyId>(),
    ),
    PortColumnId.balanced ||
    PortColumnId.phantomPower ||
    PortColumnId.busAddressable ||
    PortColumnId.busTermination => portTriStateLabel(value: value as bool),
    // Numbers and free text print themselves. `toString` is right here
    // and nowhere above: an int IS its own spelling, an enum is not.
    _ => '$value',
  };
}

/// What the batch inspector prints for a whole selection.
///
/// THE `Mixed` READING IS THE WHOLE OF DR-063. It is deliberately a
/// sentence rather than a glyph: `—` is taken, and any second glyph would
/// have to be learned from nowhere.
String portBatchLabel(
  PortColumnId column,
  BatchValue value,
  Registries registries,
) => switch (value) {
  BatchUnknown() => kUnknownCell,
  BatchAgreed(:final value) => portValueLabel(column, value, registries),
  BatchMixed(:final distinct) => 'Mixed ($distinct values)',
};

/// [column]'s closed answer set, or null when its values are open.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE OTHER HALF OF `portValueLabel`, AND THEY MUST STAY A PAIR
/// ═══════════════════════════════════════════════════════════════════════
/// One writes a value as text, this one lists the values that could have
/// produced it, and `port_tsv.dart` inverts the first over the second to
/// read a pasted cell. A second table of spellings would drift from the
/// first the day an enum gains a member; walking `.values` cannot.
///
/// NULL IS NOT "NO OPTIONS". It means the column's values are OPEN: free
/// text, a number, or a registry id whose set lives in `Registries` and
/// is resolved by `resolveConnectorToken` / `resolveSignalFamilyToken`
/// rather than enumerated here.
///
/// THE TRI-STATES LIST ONLY `true` AND `false`. Null is UNKNOWN and is
/// every column's third answer, spelled by an empty cell on the clipboard
/// and by `—` on screen, so listing it here would offer it twice.
/// Whether [column] holds a whole number rather than free text.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE THIRD MEMBER OF `portValueLabel` AND `portColumnOptions`' FAMILY
/// ═══════════════════════════════════════════════════════════════════════
/// Those two answer "how does a value print" and "what values are there".
/// This answers "what shape of box does it want", and it is here rather
/// than in the widget for the reason its two siblings are: the batch dock
/// (M4-F11) and the grid both need it, and a second list in `rackpal_ui`
/// would drift from the grid's own `switch` the day a column is added.
///
/// **A NUMERIC COLUMN IS ALWAYS AN OPEN ONE**, so this is only ever asked
/// of a column [portColumnOptions] answered null for. `port_batch_test`
/// asserts that, because the two answering yes at once would be a column
/// offering a menu into a number field.
///
/// CENSUSED AGAINST `port_grid.dart`'s OWN CELL SWITCH, not recalled: it
/// draws exactly these eighteen through its number cell. The first draft
/// of the dock's copy of this list named four columns that do not exist
/// and one that is not a column at all.
bool portColumnIsNumeric(PortColumnId column) => switch (column) {
  PortColumnId.impedanceOhms ||
  PortColumnId.nominalVoltage ||
  PortColumnId.maxCurrentMa ||
  PortColumnId.poeType ||
  PortColumnId.poeClass ||
  PortColumnId.poeWatts ||
  PortColumnId.linkSpeedMbps ||
  PortColumnId.wavelengthNm ||
  PortColumnId.baud ||
  PortColumnId.dataBits ||
  PortColumnId.stopBits ||
  PortColumnId.busUnitLoads ||
  PortColumnId.busMaxTapWatts ||
  PortColumnId.powerVolts ||
  PortColumnId.powerDrawWatts ||
  PortColumnId.powerMaxAmps ||
  PortColumnId.maxConnections ||
  PortColumnId.conductorCount => true,
  _ => false,
};

List<Object>? portColumnOptions(PortColumnId column) => switch (column) {
  PortColumnId.direction => PortDirection.values,
  PortColumnId.face => Face.values,
  PortColumnId.audioLevel => AudioLevel.values,
  PortColumnId.polarity => Polarity.values,
  PortColumnId.poeRole => PoeRole.values,
  PortColumnId.poeStandard => PoeStandard.values,
  PortColumnId.sfpFormFactor => SfpFormFactor.values,
  PortColumnId.fiberMode => FiberMode.values,
  PortColumnId.serialRole => SerialRole.values,
  PortColumnId.powerRole => PortPowerRole.values,
  PortColumnId.topology => PortTopology.values,
  PortColumnId.gender => Gender.values,
  PortColumnId.returnChannel => ReturnChannel.values,

  PortColumnId.balanced ||
  PortColumnId.phantomPower ||
  PortColumnId.busAddressable ||
  PortColumnId.busTermination => const [true, false],

  _ => null,
};
