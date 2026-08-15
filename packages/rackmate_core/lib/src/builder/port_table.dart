// What the Device Builder's port grid shows (docs/06 §4.5, M4-E #176).
//
// ═══════════════════════════════════════════════════════════════════════
// CORE OWNS THE COLUMNS, THE WIDGET PAINTS THEM
// ═══════════════════════════════════════════════════════════════════════
// This is the fourth table in the application and the third with banded
// rows, so it is built the way `derived/structure_table.dart` already is:
// the column set, the header strings, the widths in points and the row
// grouping are pure Dart in this package, and `rackmate_ui` renders what
// it is handed. That split is what let the Structure editor's columns be
// tested without a widget test, and it is worth more here, where a 68-row
// grid is the surface the exit criterion is measured on.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE ORDER, NOT TWO
// ═══════════════════════════════════════════════════════════════════════
// Rows are `portsInDeclaredOrder` and bands are the banks in the order
// their first port appears in it. A bank is therefore a RUN of the
// declared order rather than a re-sort of it, which is what keeps the
// grid's reading and `PORT_SEQ`'s reading the same reading. The catalog
// authors bank by bank, so every seeded template already looks like this;
// a hand-edited file that interleaves two banks gets one band per bank
// and its rows still in declared order, which is visible and honest
// rather than silently renumbered.
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/idformat/id_format.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/project_settings.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Every column the port grid's CORE band can carry (docs/06 §4.5).
///
/// The seven column PACKS are M4-E3 and join this enum when their cells
/// exist. Ordered as §4.5 lists them, which is left to right on screen.
enum PortColumnId {
  /// `PortDef.key`: the migration join (CR-051), not a display name.
  portKey,
  label,

  /// `J01`. Auto per the project's format until pinned; see
  /// [PortTableRow.designator].
  designator,
  connector,
  family,

  /// FIVE values (CR-060), spelled out rather than lettered.
  direction,
  face,

  /// `PortSetDef` membership: the electrical grouping (CR-055).
  portSet,

  /// The port's part in that set: `L`, `R`, `Y`, `Pb`, `+`.
  setRole,
  notes,
}

/// The column header, in the register the rest of the app's tables use:
/// short, upper case, and readable without the corpus.
String portColumnHeader(PortColumnId id) => switch (id) {
  PortColumnId.portKey => 'KEY',
  PortColumnId.label => 'LABEL',
  PortColumnId.designator => 'DESIG',
  PortColumnId.connector => 'CONNECTOR',
  PortColumnId.family => 'SIGNAL',
  PortColumnId.direction => 'DIRECTION',
  PortColumnId.face => 'FACE',
  PortColumnId.portSet => 'SET',
  PortColumnId.setRole => 'ROLE',
  PortColumnId.notes => 'NOTES',
};

/// Points, at the scale `structureColumnWidth` uses, so the two editable
/// tables in this application keep recognisably the same proportions.
///
/// `DIRECTION` IS THE WIDE ONE ON PURPOSE. Its five values are written
/// out (`Bidirectional`, `Bus node`, `Passive`) rather than lettered,
/// because CR-060 exists precisely because a compressed notation
/// collapsed `busNode` and `passive` into one letter and broke `DIR-002`,
/// `BUS-001` and `BUS-002` across the whole catalog. A column too narrow
/// to tell those two apart would re-introduce the defect in the editor
/// rather than in the file, which is `measure the control before choosing
/// it` all over again.
double portColumnWidth(PortColumnId id) => switch (id) {
  PortColumnId.portKey => 96,
  PortColumnId.label => 128,
  PortColumnId.designator => 60,
  PortColumnId.connector => 112,
  PortColumnId.family => 124,
  PortColumnId.direction => 116,
  PortColumnId.face => 64,
  PortColumnId.portSet => 92,
  PortColumnId.setRole => 56,
  PortColumnId.notes => 148,
};

/// What a [PortDirection] is called on screen.
///
/// ONE FUNCTION, AND IT IS A VOCABULARY RATHER THAN COPY. `source` and
/// `sink` are the model's words; an installer says an input is an input.
/// The five readings must stay distinguishable at a glance: that is the
/// whole of CR-060.
String portDirectionLabel(PortDirection value) => switch (value) {
  PortDirection.source => 'Output',
  PortDirection.sink => 'Input',
  PortDirection.bidirectional => 'Bidirectional',
  PortDirection.busNode => 'Bus node',
  PortDirection.passive => 'Passive',
};

/// What a [Face] is called on screen.
String portFaceLabel(Face value) => switch (value) {
  Face.front => 'Front',
  Face.rear => 'Rear',
};

/// What the CONNECTOR cell prints, or null when the port names none.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THREE STATES, AND THE THIRD IS THE ONE THAT COSTS A CRASH
/// ═══════════════════════════════════════════════════════════════════════
/// A brand-new row names no connector, and that is UNKNOWN: null, so the
/// cell draws the dash rather than an empty box that reads as a rendering
/// fault. A named connector the registry holds prints its display name,
/// because `conn.hdmi_a` is our spelling and `HDMI Type A` is the trade's.
///
/// A named connector the registry does NOT hold prints the raw id, and
/// that case is neither theoretical nor cosmetic. M3-L found the same
/// shape on the Structure editor's SERVICE column: a `DropdownButton`
/// asserts that exactly one item matches its value, so a document naming
/// something no menu offers throws for the WHOLE table rather than
/// misbehaving in one cell. Printing the id keeps the fact visible and
/// keeps the row on screen, which is the only way the user can find and
/// fix it.
String? portConnectorText(Registries registries, ConnectorTypeId id) {
  if (id.v.trim().isEmpty) return null;
  return registries.connectorTypes[id]?.displayName ?? id.v;
}

/// What the SIGNAL cell prints, or null when the port names no family.
/// [portConnectorText]'s three states, for the same three reasons.
String? portFamilyText(Registries registries, SignalFamilyId id) {
  if (id.v.trim().isEmpty) return null;
  return registries.signalFamilies[id]?.displayName ?? id.v;
}

/// One port, and everything the grid needs that is not on the port.
final class PortTableRow {
  const PortTableRow({
    required this.port,
    required this.portSeq,
    required this.autoDesignator,
  });

  final PortDef port;

  /// The port's 1-based position in the template's DECLARED order, which
  /// is what `allocatePortDesignator` renders and what the silkscreen is
  /// printed against. Not the row's position on screen: those agree
  /// today and a filter would part them.
  final int portSeq;

  /// What a project would allocate for this port, or null when the
  /// project's format cannot render one.
  ///
  /// NULL IS UNKNOWN AND IS NOT AN EMPTY STRING (G4). The commercial
  /// `{DEV_BLOCK}{PORT_SEQ:2}` preset needs a token no template can
  /// supply, and reserve-block allocation is not implemented anywhere in
  /// this repository. Rendering `01` by pretending the block is zero
  /// would put a fabricated identifier in front of somebody about to
  /// print a termination schedule.
  final String? autoDesignator;

  /// True once the author has typed a designator, which pins it.
  ///
  /// An empty string is NOT pinned: a user who selects the cell and
  /// deletes what is in it means "go back to automatic", and storing `''`
  /// would instead mean "this port's designator is deliberately blank".
  bool get isDesignatorPinned => (port.designatorHint ?? '').trim().isNotEmpty;

  /// What the DESIG cell shows: the pinned value, else the automatic one,
  /// else nothing at all.
  String? get designator =>
      isDesignatorPinned ? port.designatorHint!.trim() : autoDesignator;
}

/// One bank's worth of rows, under one sticky header.
final class PortTableBand {
  const PortTableBand({
    required this.bankKey,
    required this.bank,
    required this.rows,
  });

  /// Null for the ports that belong to no bank.
  final String? bankKey;

  /// The declared bank, or null when [bankKey] names one the template
  /// does not define. That is a real state and the grid shows it rather
  /// than hiding the rows: a bank key with no `BankDef` is what a
  /// hand-edited file or a half-finished paste leaves behind.
  final BankDef? bank;

  final List<PortTableRow> rows;

  int get portCount => rows.length;

  /// A dangling [bankKey]: named by ports, defined by nothing.
  bool get isUndeclaredBank => bankKey != null && bank == null;

  /// What the band header prints.
  ///
  /// The undeclared case shows the KEY rather than inventing a label,
  /// because the key is the only fact there is and it is what the user
  /// has to go and fix.
  String get title => switch ((bankKey, bank)) {
    (null, _) => 'Not in a bank',
    (final String key, null) => key,
    (_, final BankDef declared) => declared.label,
  };
}

/// The grid's rows, banded (docs/06 §4.5).
final class PortTable {
  const PortTable({required this.bands});

  final List<PortTableBand> bands;

  int get portCount {
    var total = 0;
    for (final band in bands) {
      total += band.portCount;
    }
    return total;
  }

  /// Every row, in declared order, ignoring the bands. The grid uses this
  /// for keyboard movement, which crosses a band header without stopping.
  List<PortTableRow> get rows => [
    for (final band in bands) ...band.rows,
  ];
}

/// Bands [body]'s ports for the grid.
///
/// [portDesignatorFormat] defaults to `ProjectSettings`' own default so
/// that a caller with no project in hand (a test, or the builder opened
/// before a document exists) sees exactly what a default project would
/// allocate rather than a blank column. The builder passes the real one.
PortTable buildPortTable(
  TemplateBody body, {
  IdFormat portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
}) {
  final declared = portsInDeclaredOrder(body.ports);
  final banksByKey = {for (final bank in body.banks) bank.key: bank};
  final settings = ProjectSettings(portDesignatorFormat: portDesignatorFormat);

  // ACCUMULATED ACROSS THE WHOLE TEMPLATE, exactly as one device's ports
  // are allocated against one another. It is inert for the shipped
  // `J{PORT_SEQ:2}`, where the sequence is already injective, and it is
  // the only thing that catches a degenerate pattern: `"J"` renders the
  // same string for every port, so the second port has nothing left to be
  // allocated and reads UNKNOWN instead of duplicating the first.
  final used = <String>{};

  // Insertion-ordered, so the bands come out in the order their first
  // port appears in the declared order. `Map` in Dart preserves that.
  final grouped = <String?, List<PortTableRow>>{};
  for (var i = 0; i < declared.length; i++) {
    final port = declared[i];
    final auto = _autoDesignator(settings, i + 1, used);
    if (auto != null) used.add(auto);
    grouped
        .putIfAbsent(port.bankKey, () => <PortTableRow>[])
        .add(PortTableRow(port: port, portSeq: i + 1, autoDesignator: auto));
  }

  return PortTable(
    bands: [
      for (final entry in grouped.entries)
        PortTableBand(
          bankKey: entry.key,
          bank: entry.key == null ? null : banksByKey[entry.key],
          rows: entry.value,
        ),
    ],
  );
}

/// [allocatePortDesignator] with its two failure modes turned into an
/// UNKNOWN, because a grid cell may not throw.
///
/// The allocator is right to throw: it is called when a port is being
/// materialised and a designator that cannot be rendered is a bug the
/// caller must hear about. Here the same condition is a fact to display,
/// and there is exactly one honest way to display it (G4).
String? _autoDesignator(
  ProjectSettings settings,
  int portSeq,
  Set<String> used,
) {
  try {
    return allocatePortDesignator(
      settings: settings,
      portSeq: portSeq,
      usedDesignators: used,
    );
  } on MissingTokenValueException {
    // The commercial preset's `{DEV_BLOCK}`, and every other token a
    // template cannot supply.
    return null;
  } on DesignatorExhaustedException {
    // A pattern with no `PORT_SEQ` in it at all, which renders the same
    // string for every port.
    return null;
  }
}
