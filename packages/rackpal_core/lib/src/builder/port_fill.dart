// FILL DOWN AND FILL SERIES (M4-F1 `#208`, docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// THE TWO SPREADSHEET KEYS, AND WHY ONE OF THEM NEEDED A RULING
// ═══════════════════════════════════════════════════════════════════════
// `Ctrl+D` copies the top selected cell down the column. `Ctrl+Shift+D`
// writes a SERIES down it. Together they are what turn 68 edits into two,
// which is docs/06 §4's binding premise: any interaction costing one click
// per port is a design failure.
//
// §4.6 says fill series *"re-applies THE label pattern"*, and the census
// at M4-F pick-up found that there is no label pattern: not on `PortDef`,
// not on `BankDef` (key, label, abbr, symbolSide, collapseInSymbol,
// order), not on `TemplateBody`. `LabelPattern` is referenced by two files
// in the whole tree, its own and `quick_add.dart`, where it lives in a
// text field and dies when the bar is cleared.
//
// DR-062: THE SERIES IS INFERRED FROM THE TOP SELECTED CELL, on Excel's
// own rule. That keeps `Ctrl+Shift+D` meaning what a person's hands
// already think it means, keeps it distinct from `Renumber…` (`#697`,
// which docs/06 marks with an ellipsis and an INDEFINITE article, so it is
// the one that opens a dialog), and works on ports created by any route
// rather than only the ones Quick Add made.
//
// ═══════════════════════════════════════════════════════════════════════
// BOTH ARE COMMAND LISTS AND NEITHER TOUCHES A BODY
// ═══════════════════════════════════════════════════════════════════════
// The grid runs them through one `transact`, so filling sixteen rows is
// one `Ctrl+Z`. Building the list here rather than in the widget is what
// lets the whole of both features be tested without pumping a frame.
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/builder/port_table.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/model/template.dart';

/// What a fill may do to one grid column.
///
/// ═══════════════════════════════════════════════════════════════════════
/// CLOSURES, BECAUSE A `PortField<Object?>` CAN READ AND CANNOT WRITE
/// ═══════════════════════════════════════════════════════════════════════
/// `PortDefField.all` is a `List<PortField<Object?>>` and that is sound
/// only because nothing calls `.set` through it. A `PortField<T>` holds
/// `void Function(PortDef, T)`, and **function types are contravariant in
/// their parameters**, so `(PortDef, String) => void` is NOT a
/// `(PortDef, Object?) => void`: reading `.set` off an upcast field throws
/// before the call is even made. Written that way first, and every test in
/// this file failed at once, which is the cheapest possible way to be
/// told.
///
/// EXTENSION TYPES REMOVE THE FALLBACK. `ConnectorTypeId` and friends are
/// `extension type ... (String v)`, **erased at run time**, so a field
/// over one IS a `PortField<String>` while running and no runtime test can
/// tell a connector column from a label column. A series would have
/// written `IN 02` into a connector id and nothing would have objected.
///
/// So the static type is kept where it is known, at the switch arm, and
/// what escapes is a closure that has already been checked.
final class PortColumnFill {
  const PortColumnFill({
    required this.copy,
    required this.read,
    required this.write,
    required this.set,
    this.text,
  });

  /// One command copying this column from one port to another, or null
  /// when the two already agree.
  final Command<TemplateBody>? Function(PortDef from, PortDef to) copy;

  /// This column's value on one port, type-erased.
  ///
  /// Reading is the safe direction: `T Function(PortDef)` IS an `Object?
  /// Function(PortDef)`, because return types are covariant. It is the
  /// WRITE below that could not be done this way with a bare field.
  final Object? Function(PortDef port) read;

  /// One command writing a value into this column, or null when the port
  /// already holds it.
  ///
  /// THE CAST IS INSIDE THE CLOSURE, where `T` is still known, so a
  /// caller passing the wrong type throws at the write rather than
  /// corrupting a field. Callers build their control from the same
  /// `PortColumnId` this came from, so the two can only disagree through
  /// a code defect, and the batch tests walk every column to
  /// prove they do not.
  final Command<TemplateBody>? Function(PortDef port, Object? value) write;

  /// Writes one value straight onto a port, with no command and no
  /// no-op check.
  ///
  /// **FOR A PORT THAT DOES NOT EXIST YET** (M4-I3, `#222`). Every other
  /// member here builds a `Command`, which is right for a port already in
  /// the body: a write to one has to be undoable on its own. A port being
  /// CONSTRUCTED has no key in the body for `SetPortFieldCommand` to
  /// address, and `AddPortCommand` holds the object it added, so the whole
  /// port is one undo entry and its fields need no second one.
  ///
  /// The cast is inside the closure for [write]'s reason, and the type it
  /// casts to is the same `PortField`'s, so the two cannot disagree.
  final void Function(PortDef port, Object? value) set;

  /// Reading and writing this column as text, for the columns that hold
  /// it and null for the rest.
  ///
  /// FILL SERIES IS TEXT ONLY, and narrowly. `poeWatts` 15, 16, 17 would
  /// silently rewrite a bank's electrical facts as a counting sequence.
  /// `SET` and `ROLE` are worse: they are keys into `PortSetDef`, so a
  /// series down them invents memberships no set declares, which is the
  /// dangling-reference state the grid draws a red band for. Those columns
  /// still fill DOWN, where copying one valid key into four rows is
  /// exactly what a person means.
  final PortTextColumn? text;

  bool get isText => text != null;
}

/// One column's text accessors, when it has them.
final class PortTextColumn {
  const PortTextColumn({required this.read, required this.write});

  final String? Function(PortDef port) read;
  final Command<TemplateBody>? Function(PortDef port, String value) write;
}

/// One write, or null when the value is already there.
///
/// SKIPPING A NO-OP IS NOT AN OPTIMISATION. A transaction full of writes
/// that changed nothing is an undo entry that appears to do nothing when
/// reverted, which is the defect M4-D shipped and had to be told about.
Command<TemplateBody>? _set<T>(PortField<T> field, PortDef port, T value) {
  final now = field.get(port);
  if (now == value) return null;
  return SetPortFieldCommand<T>(
    port: port.key,
    field: field,
    from: now,
    to: value,
  );
}

/// A column that fills down and carries no series.
PortColumnFill _plain<T>(PortField<T> field) => PortColumnFill(
  copy: (from, to) => _set<T>(field, to, field.get(from)),
  read: field.get,
  write: (port, value) => _set<T>(field, port, value as T),
  set: (port, value) => field.set(port, value as T),
);

/// A text column, whose value is always present.
PortColumnFill _text(PortField<String> field) => PortColumnFill(
  copy: (from, to) => _set<String>(field, to, field.get(from)),
  read: field.get,
  write: (port, value) => _set<String>(field, port, value! as String),
  set: (port, value) => field.set(port, value! as String),
  text: PortTextColumn(
    read: field.get,
    write: (port, value) => _set<String>(field, port, value),
  ),
);

/// A text column that may be UNKNOWN.
PortColumnFill _textOrNull(PortField<String?> field) => PortColumnFill(
  copy: (from, to) => _set<String?>(field, to, field.get(from)),
  read: field.get,
  write: (port, value) => _set<String?>(field, port, value as String?),
  set: (port, value) => field.set(port, value as String?),
  text: PortTextColumn(
    read: field.get,
    write: (port, value) => _set<String?>(field, port, value),
  ),
);

/// Which field [id]'s cells write to, or null when the column is not one
/// a fill may touch.
///
/// EXHAUSTIVE, LIKE ITS FOUR SIBLINGS IN `port_table.dart`, so a column
/// added later cannot reach the grid without somebody answering this
/// question for it. That is the whole reason it is a switch and not a map.
///
/// THREE COLUMNS ANSWER NULL, each for its own reason:
///
///   * `portKey` is `final` on the model, so a rename is a replacement
///     rather than a write (`RenamePortKeyCommand`). Filling it down would
///     also give N ports one key, which is not a state the template can
///     hold.
///   * `pairedPort` is read-only until M4-J3 (`#225`) builds pairing; a
///     pair is a `TemplateBody.passthroughPairs` entry and not a field on
///     either port.
///   * `renamedFrom` is CR-051's alias trail. It is written by the rename
///     path as a record of what happened, and a fill would be forging one.
PortColumnFill? portColumnFill(PortColumnId id) => switch (id) {
  PortColumnId.portKey => null,
  PortColumnId.pairedPort => null,
  PortColumnId.renamedFrom => null,
  PortColumnId.label => _text(PortDefField.label),
  PortColumnId.designator => _textOrNull(PortDefField.designatorHint),
  PortColumnId.notes => _textOrNull(PortDefField.notes),
  PortColumnId.portSet => _plain(PortDefField.setKey),
  PortColumnId.setRole => _plain(PortDefField.setRole),
  PortColumnId.connector => _plain(PortDefField.connector),
  PortColumnId.family => _plain(PortDefField.signalFamily),
  PortColumnId.direction => _plain(PortDefField.direction),
  PortColumnId.face => _plain(PortDefField.face),
  PortColumnId.impedanceOhms => _plain(PortDefField.impedanceOhms),
  PortColumnId.audioLevel => _plain(PortDefField.audioLevel),
  PortColumnId.balanced => _plain(PortDefField.balanced),
  PortColumnId.phantomPower => _plain(PortDefField.phantomPower),
  PortColumnId.polarity => _plain(PortDefField.polarity),
  PortColumnId.nominalVoltage => _plain(PortDefField.nominalVoltage),
  PortColumnId.maxCurrentMa => _plain(PortDefField.maxCurrentMa),
  PortColumnId.poeRole => _plain(PortDefField.poeRole),
  PortColumnId.poeStandard => _plain(PortDefField.poeStandard),
  PortColumnId.poeType => _plain(PortDefField.poeType),
  PortColumnId.poeClass => _plain(PortDefField.poeClass),
  PortColumnId.poeWatts => _plain(PortDefField.poeWatts),
  PortColumnId.linkSpeedMbps => _plain(PortDefField.linkSpeedMbps),
  PortColumnId.sfpFormFactor => _plain(PortDefField.sfpFormFactor),
  PortColumnId.fiberMode => _plain(PortDefField.fiberMode),
  PortColumnId.wavelengthNm => _plain(PortDefField.wavelengthNm),
  PortColumnId.serialRole => _plain(PortDefField.serialRole),
  PortColumnId.baud => _plain(PortDefField.baud),
  PortColumnId.dataBits => _plain(PortDefField.dataBits),
  PortColumnId.stopBits => _plain(PortDefField.stopBits),
  PortColumnId.parity => _plain(PortDefField.parity),
  PortColumnId.flowControl => _plain(PortDefField.flowControl),
  PortColumnId.busProtocol => _plain(PortDefField.busProtocol),
  PortColumnId.busTermination => _plain(PortDefField.busTermination),
  PortColumnId.busUnitLoads => _plain(PortDefField.busUnitLoads),
  PortColumnId.busAddressable => _plain(PortDefField.busAddressable),
  PortColumnId.busMaxTapWatts => _plain(PortDefField.busMaxTapWatts),
  PortColumnId.powerRole => _plain(PortDefField.powerRole),
  PortColumnId.powerVolts => _plain(PortDefField.powerVolts),
  PortColumnId.powerDrawWatts => _plain(PortDefField.powerDrawWatts),
  PortColumnId.powerMaxAmps => _plain(PortDefField.powerMaxAmps),
  PortColumnId.maxConnections => _plain(PortDefField.maxConnections),
  PortColumnId.topology => _plain(PortDefField.topology),
  PortColumnId.gender => _plain(PortDefField.gender),
  PortColumnId.pinoutVariant => _plain(PortDefField.pinoutVariant),
  PortColumnId.conductorCount => _plain(PortDefField.conductorCount),
  PortColumnId.returnChannel => _plain(PortDefField.returnChannel),
};

/// A counting sequence read out of one cell's text.
///
/// `IN 01` is `('IN ', 1, width 2, '')`, and renders `IN 01`, `IN 02`,
/// `IN 03`.
final class LabelSeries {
  const LabelSeries({
    required this.prefix,
    required this.start,
    required this.width,
    required this.suffix,
  });

  final String prefix;
  final int start;

  /// How many digits the original had, so `IN 01` counts to `IN 10` and
  /// not to `IN 010`. `padLeft` is a no-op once the number outgrows it,
  /// which is the behaviour a person expects and not an overflow.
  final int width;

  final String suffix;

  /// This series' [step]th term, zero-based.
  String at(int step) =>
      '$prefix${(start + step).toString().padLeft(width, '0')}$suffix';
}

/// The counting sequence [text] implies, or null when it holds no digits.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE LAST RUN OF DIGITS, WHICH IS EXCEL'S RULE AND IS ALSO THE RIGHT ONE
/// ═══════════════════════════════════════════════════════════════════════
/// This catalog is full of labels whose FIRST number is part of a
/// standard's name: `HDMI 2.0 IN 1`, `802.3bt PORT 4`, `RS-232 CTL 2`. A
/// rule reading the first run would count the standard and leave the port
/// number alone, which is wrong in exactly the cases that matter most.
///
/// NULL IS A REAL ANSWER AND THE CALLER MUST SAY SO. `SPEAKER` implies no
/// series. Falling back to a copy would make `Ctrl+Shift+D` silently
/// become `Ctrl+D`, and the person would find out sixteen rows later.
LabelSeries? inferLabelSeries(String text) {
  var end = -1;
  for (var i = text.length - 1; i >= 0; i--) {
    if (_isDigit(text.codeUnitAt(i))) {
      end = i;
      break;
    }
  }
  if (end < 0) return null;

  var begin = end;
  while (begin > 0 && _isDigit(text.codeUnitAt(begin - 1))) {
    begin--;
  }
  final digits = text.substring(begin, end + 1);
  return LabelSeries(
    prefix: text.substring(0, begin),
    start: int.parse(digits),
    width: digits.length,
    suffix: text.substring(end + 1),
  );
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

/// Why a fill did nothing, so the surface can say which one it was.
///
/// A FILL THAT DECLINES MUST SAY SO OUT LOUD. Fourteen keys in docs/06
/// §4.6 act on a selection, and a key that quietly does nothing is
/// indistinguishable from one that is not bound, which is how a person
/// concludes the feature does not exist.
enum PortFillRefusal {
  /// Fewer than two rows selected: nothing to fill INTO.
  needsTwoRows,

  /// Focus is not in a column, so there is no column to fill.
  needsAColumn,

  /// The column is one no fill may write: `KEY`, `PAIRED WITH`, `WAS
  /// CALLED`.
  columnIsNotFillable,

  /// Fill series on a column that holds no text.
  seriesNeedsText,

  /// Fill series where the top cell holds no digits at all.
  seriesNeedsANumber,
}

/// What a fill produced: commands to run, or the reason there are none.
final class PortFillResult {
  const PortFillResult.commands(this.commands) : refusal = null;
  const PortFillResult.refused(PortFillRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortFillRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// `Ctrl+D`: copy [column]'s value from the first of [selectedInOrder]
/// into every row below it.
///
/// [selectedInOrder] is the selected keys in DISPLAY order, which is what
/// makes "the top" mean the top of what the person can see rather than the
/// top of the declared order (DR-061).
///
/// AN UNKNOWN COPIES DOWN LIKE ANY OTHER VALUE. If the top cell is null,
/// every row below it becomes null. That is not a bug to guard against: G4
/// makes null a fact ("nobody has measured this"), so copying it says
/// "none of these have been measured", which is a thing a person means and
/// a thing one `Ctrl+Z` undoes.
PortFillResult buildFillDown({
  required TemplateBody body,
  required PortColumnId? column,
  required List<String> selectedInOrder,
}) {
  if (column == null) return const PortFillResult.refused(_needsAColumn);
  if (selectedInOrder.length < 2) {
    return const PortFillResult.refused(_needsTwoRows);
  }
  final target = portColumnFill(column);
  if (target == null) {
    return const PortFillResult.refused(_notFillable);
  }

  final byKey = {for (final port in body.ports) port.key.v: port};
  final source = byKey[selectedInOrder.first];
  if (source == null) return const PortFillResult.refused(_needsTwoRows);

  return PortFillResult.commands([
    for (final key in selectedInOrder.skip(1))
      if (byKey[key] case final PortDef port)
        if (target.copy(source, port) case final Command<TemplateBody> write)
          write,
  ]);
}

/// `Ctrl+Shift+D`: write the series the top selected cell implies down
/// [column], one step per row.
///
/// THE TOP CELL IS THE START, which is what "a fresh `start`" means once
/// DR-062 has made the pattern inferred rather than stored. Selecting rows
/// 9 through 16 of a bank and pressing this keeps them 09 through 16; a
/// counter that restarted at 1 would renumber them 01 through 08 and
/// collide with the eight above.
///
/// THE TOP ROW IS NEVER WRITTEN, by either fill. It is the specimen.
PortFillResult buildFillSeries({
  required TemplateBody body,
  required PortColumnId? column,
  required List<String> selectedInOrder,
}) {
  if (column == null) return const PortFillResult.refused(_needsAColumn);
  if (selectedInOrder.length < 2) {
    return const PortFillResult.refused(_needsTwoRows);
  }
  final target = portColumnFill(column);
  if (target == null) {
    return const PortFillResult.refused(_notFillable);
  }
  final text = target.text;
  if (text == null) {
    return const PortFillResult.refused(_seriesNeedsText);
  }

  final byKey = {for (final port in body.ports) port.key.v: port};
  final source = byKey[selectedInOrder.first];
  if (source == null) return const PortFillResult.refused(_needsTwoRows);

  final series = inferLabelSeries(text.read(source) ?? '');
  if (series == null) {
    return const PortFillResult.refused(_seriesNeedsANumber);
  }

  final commands = <Command<TemplateBody>>[];
  var step = 0;
  for (final key in selectedInOrder.skip(1)) {
    step++;
    final port = byKey[key];
    if (port == null) continue;
    final write = text.write(port, series.at(step));
    if (write != null) commands.add(write);
  }
  return PortFillResult.commands(commands);
}

// Named so the refusals above can be `const`.
const PortFillRefusal _needsAColumn = PortFillRefusal.needsAColumn;
const PortFillRefusal _needsTwoRows = PortFillRefusal.needsTwoRows;
const PortFillRefusal _notFillable = PortFillRefusal.columnIsNotFillable;
const PortFillRefusal _seriesNeedsText = PortFillRefusal.seriesNeedsText;
const PortFillRefusal _seriesNeedsANumber = PortFillRefusal.seriesNeedsANumber;

/// What the grid says when a fill declines.
///
/// IN CORE, BESIDE THE REFUSAL, for `port_summary.dart`'s reason: a
/// sentence built in the widget is a second vocabulary, and the first time
/// one of them changes they disagree.
String portFillRefusalMessage(PortFillRefusal refusal) => switch (refusal) {
  PortFillRefusal.needsTwoRows =>
    'Select two or more rows to fill: the first one is what gets copied.',
  PortFillRefusal.needsAColumn =>
    'Click a cell first, so the fill knows which column it is about.',
  PortFillRefusal.columnIsNotFillable =>
    'This column cannot be filled. Keys, pairings and former names are '
        'each written by their own action.',
  PortFillRefusal.seriesNeedsText =>
    'A series needs a text column. Use Fill down to copy this one.',
  PortFillRefusal.seriesNeedsANumber =>
    'The first cell has no number in it, so there is no series to '
        'continue. Use Fill down to copy it instead.',
};
