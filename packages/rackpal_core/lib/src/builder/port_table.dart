// What the Device Builder's port grid shows (docs/06 §4.5, M4-E #176).
//
// ═══════════════════════════════════════════════════════════════════════
// CORE OWNS THE COLUMNS, THE WIDGET PAINTS THEM
// ═══════════════════════════════════════════════════════════════════════
// This is the fourth table in the application and the third with banded
// rows, so it is built the way `derived/structure_table.dart` already is:
// the column set, the header strings, the widths in points and the row
// grouping are pure Dart in this package, and `rackpal_ui` renders what
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
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/idformat/id_format.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Every column the port grid can carry (docs/06 §4.5).
///
/// The ten CORE columns come first and are always visible; the rest
/// belong to one of the seven packs and are ordered pack by pack. Reading
/// order within each group is §4.5's, which is left to right on screen.
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

  // ══════════════════════════════════════════════════════════════════════
  // THE SEVEN PACKS (M4-E3, #205)
  // ══════════════════════════════════════════════════════════════════════
  // Grouped as docs/06 §4.5 groups them, but SOURCED FROM THE MODEL, and
  // the difference between the two lists is the finding. Censused field
  // by field against `PortDef`:
  //
  //   * NINE columns §4.5 names have NO field to write to. `VLANs`,
  //     `Segment`, `Address`, `Universe`, `Receptacle`, `Outlet mode`,
  //     `Seq step`, `Seq delay`, `Circuit`. Building a cell for any of
  //     them means either inventing a model field in a grid task or
  //     shipping a control that writes nowhere, and this app already has
  //     a rule about the second one.
  //   * EIGHT fields the model carries are named by no column at all:
  //     `balanced`, `conductorCount`, `maxCurrentMa`, `channelIndex`,
  //     `bus.protocol`, `bus.addressable`, `power.drawWatts`, and the
  //     `carriedProtocols`/`acceptedFamilies` pair. They round-trip
  //     through the codec today with no way to author them, which is `a
  //     modelled field is not a reachable one` in its original form.
  //
  //     THAT PAIR IS NOW ONE FIELD AND THE COUNT IS SEVEN (DR-134).
  //     `carriedProtocols` was deleted rather than given the cell DR-081
  //     ordered, because it was a second copy of two facts the model
  //     already records with producers and consumers (§11.133.2).
  //     `acceptedFamilies` keeps the cell, and by then it had gained
  //     three connect-time readers, which is what settled it.
  //
  // So the packs below carry the intersection plus the six unnamed
  // scalars that clearly belong to a pack §4.5 already draws.
  // `channelIndex` and the two family lists stay out: the first belongs
  // with port sets (M4-J2) and the other two need a multi-select the
  // grid has no cell shape for. docs/06 §4.5's table is owed an edit.

  // Electrical.
  impedanceOhms,
  audioLevel,
  balanced,
  phantomPower,
  polarity,
  nominalVoltage,
  maxCurrentMa,

  // Network.
  poeRole,
  poeStandard,
  poeType,
  poeClass,
  poeWatts,
  linkSpeedMbps,
  sfpFormFactor,
  fiberMode,
  wavelengthNm,

  // Serial.
  serialRole,
  baud,
  dataBits,
  stopBits,
  parity,
  flowControl,

  // Bus.
  busProtocol,
  busTermination,
  busUnitLoads,
  busAddressable,
  busMaxTapWatts,

  // Power.
  powerRole,
  powerVolts,
  powerDrawWatts,
  powerMaxAmps,

  // Passthrough.
  pairedPort,

  // Advanced.
  maxConnections,
  topology,
  gender,
  pinoutVariant,
  conductorCount,
  returnChannel,
  renamedFrom,
}

/// The column groups `⚙ Columns` toggles (docs/06 §4.5).
///
/// SEVEN, AND THE CORE COLUMNS ARE NOT ONE OF THEM: those are always
/// visible and have no switch, which is what "core" means here.
enum PortColumnPack {
  electrical('Electrical'),
  network('Network'),
  serial('Serial'),
  bus('Bus'),
  power('Power'),
  passthrough('Passthrough'),
  advanced('Advanced');

  const PortColumnPack(this.label);

  /// What the gear menu calls this group.
  final String label;
}

/// The pack stored under [name], or null when nothing matches.
///
/// STORED AS `.name` AND RESOLVED HERE, which is safe for exactly one
/// reason: this crosses a PREFERENCES file and not the document format.
/// `prefs.json` is a convenience the user may delete, so a pack renamed
/// in a later build costs somebody one re-tick; a `.name` in a `.rmpj`
/// would be a rename that silently changes what a saved project means,
/// which is why the codec spells every enum out by hand instead.
PortColumnPack? portColumnPackNamed(String name) {
  for (final pack in PortColumnPack.values) {
    if (pack.name == name) return pack;
  }
  return null;
}

/// Which pack [id] belongs to, or null when it is a core column.
PortColumnPack? portColumnPack(PortColumnId id) => switch (id) {
  PortColumnId.portKey ||
  PortColumnId.label ||
  PortColumnId.designator ||
  PortColumnId.connector ||
  PortColumnId.family ||
  PortColumnId.direction ||
  PortColumnId.face ||
  PortColumnId.portSet ||
  PortColumnId.setRole ||
  PortColumnId.notes => null,

  PortColumnId.impedanceOhms ||
  PortColumnId.audioLevel ||
  PortColumnId.balanced ||
  PortColumnId.phantomPower ||
  PortColumnId.polarity ||
  PortColumnId.nominalVoltage ||
  PortColumnId.maxCurrentMa => PortColumnPack.electrical,

  PortColumnId.poeRole ||
  PortColumnId.poeStandard ||
  PortColumnId.poeType ||
  PortColumnId.poeClass ||
  PortColumnId.poeWatts ||
  PortColumnId.linkSpeedMbps ||
  PortColumnId.sfpFormFactor ||
  PortColumnId.fiberMode ||
  PortColumnId.wavelengthNm => PortColumnPack.network,

  PortColumnId.serialRole ||
  PortColumnId.baud ||
  PortColumnId.dataBits ||
  PortColumnId.stopBits ||
  PortColumnId.parity ||
  PortColumnId.flowControl => PortColumnPack.serial,

  PortColumnId.busProtocol ||
  PortColumnId.busTermination ||
  PortColumnId.busUnitLoads ||
  PortColumnId.busAddressable ||
  PortColumnId.busMaxTapWatts => PortColumnPack.bus,

  PortColumnId.powerRole ||
  PortColumnId.powerVolts ||
  PortColumnId.powerDrawWatts ||
  PortColumnId.powerMaxAmps => PortColumnPack.power,

  PortColumnId.pairedPort => PortColumnPack.passthrough,

  PortColumnId.maxConnections ||
  PortColumnId.topology ||
  PortColumnId.gender ||
  PortColumnId.pinoutVariant ||
  PortColumnId.conductorCount ||
  PortColumnId.returnChannel ||
  PortColumnId.renamedFrom => PortColumnPack.advanced,
};

/// The core columns, always visible, in reading order.
List<PortColumnId> get portCoreColumns => [
  for (final id in PortColumnId.values)
    if (portColumnPack(id) == null) id,
];

/// [pack]'s columns, in reading order.
List<PortColumnId> portColumnsIn(PortColumnPack pack) => [
  for (final id in PortColumnId.values)
    if (portColumnPack(id) == pack) id,
];

/// The columns to draw: the core ones, then each open pack in its own
/// order, so a pack's columns always arrive together.
List<PortColumnId> portVisibleColumns(Set<PortColumnPack> open) => [
  ...portCoreColumns,
  for (final pack in PortColumnPack.values)
    if (open.contains(pack)) ...portColumnsIn(pack),
];

/// The packs a bank's own traffic calls for (docs/06 §4.5's auto-reveal).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE DOMINANT FAMILY, AND WHY IT IS THE DOMAIN THAT DECIDES
/// ═══════════════════════════════════════════════════════════════════════
/// §4.5 says a pack is revealed "when the current bank's dominant family
/// calls for them", and the example given is that opening any switch
/// template shows the Network pack. A family alone is too fine to key a
/// rule table on (the catalog ships 34 of them and the community library
/// will ship more), so this keys on the family's DOMAIN, of which there
/// are eight and they are a closed set canon fixes.
///
/// ADVANCED AND PASSTHROUGH ARE NEVER AUTO-REVEALED. Advanced is the
/// group a person opens on purpose; Passthrough follows
/// `TemplateBody.isPassthrough` instead, which docs/06 §4.6 states
/// directly, because a patch panel's pairing is a fact about the DEVICE
/// rather than about one bank's traffic.
Set<PortColumnPack> autoRevealedPacks(
  Iterable<PortDef> ports,
  Registries registries, {
  bool isPassthrough = false,
}) {
  final counts = <String, int>{};
  for (final port in ports) {
    final domain = registries.signalFamilies[port.signalFamily]?.domain;
    if (domain == null) continue;
    counts[domain.v] = (counts[domain.v] ?? 0) + 1;
  }

  final packs = <PortColumnPack>{
    if (isPassthrough) PortColumnPack.passthrough,
  };
  if (counts.isEmpty) return packs;

  // TOTAL, because `List.sort` is not stable and a tie between two
  // domains must not resolve differently on two runs of the same
  // template. Count descending, then domain id.
  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });

  return packs..addAll(_packsForDomain(ranked.first));
}

/// What one signal domain's ports need columns for.
///
/// `ctl` REVEALS TWO. Control is RS-232 and RS-485/DMX in the same
/// breath, and a bank of control ports commonly holds both; showing one
/// pack would hide half of what the author came to fill in.
Set<PortColumnPack> _packsForDomain(String domain) => switch (domain) {
  'net' => {PortColumnPack.network},
  'audio.analog' || 'audio.digital' || 'video.analog' => {
    PortColumnPack.electrical,
  },
  'ctl' => {PortColumnPack.serial, PortColumnPack.bus},
  'pwr' => {PortColumnPack.power},
  // `video.digital` and `str` have no pack: HDMI and a streaming service
  // carry no field in any of the seven that a person authors by hand.
  _ => const <PortColumnPack>{},
};

/// Whether the GENDER cell may be edited for a port on [connector].
///
/// GATED ON THE REGISTRY, NOT ON THE VALUE (CR-059, M4-B). Gender is
/// meaningless on an RJ45 and load-bearing on an XLR, and
/// `ConnectorTypeDef.genderApplies` is the field M4-B authored to say
/// which. A connector the registry does not hold answers FALSE: an
/// unknown connector is not licence to record a gender against it.
bool portGenderApplies(Registries registries, ConnectorTypeId connector) =>
    registries.connectorTypes[connector]?.genderApplies ?? false;

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
  PortColumnId.impedanceOhms => 'IMPEDANCE',
  PortColumnId.audioLevel => 'LEVEL',
  PortColumnId.balanced => 'BALANCED',
  PortColumnId.phantomPower => 'PHANTOM',
  PortColumnId.polarity => 'POLARITY',
  PortColumnId.nominalVoltage => 'NOMINAL V',
  PortColumnId.maxCurrentMa => 'MAX mA',
  PortColumnId.poeRole => 'PoE ROLE',
  PortColumnId.poeStandard => 'PoE STD',
  PortColumnId.poeType => 'PoE TYPE',
  PortColumnId.poeClass => 'PoE CLASS',
  PortColumnId.poeWatts => 'PoE W',
  PortColumnId.linkSpeedMbps => 'LINK Mb/s',
  PortColumnId.sfpFormFactor => 'SFP',
  PortColumnId.fiberMode => 'FIBRE',
  PortColumnId.wavelengthNm => 'WAVELENGTH',
  PortColumnId.serialRole => 'DTE / DCE',
  PortColumnId.baud => 'BAUD',
  PortColumnId.dataBits => 'DATA BITS',
  PortColumnId.stopBits => 'STOP BITS',
  PortColumnId.parity => 'PARITY',
  PortColumnId.flowControl => 'FLOW',
  PortColumnId.busProtocol => 'BUS',
  PortColumnId.busTermination => 'TERMINATOR',
  PortColumnId.busUnitLoads => 'UNIT LOADS',
  PortColumnId.busAddressable => 'ADDRESSABLE',
  PortColumnId.busMaxTapWatts => 'TAP W',
  PortColumnId.powerRole => 'INLET / OUTLET',
  PortColumnId.powerVolts => 'VOLTS',
  PortColumnId.powerDrawWatts => 'DRAW W',
  PortColumnId.powerMaxAmps => 'MAX A',
  PortColumnId.pairedPort => 'PAIRED WITH',
  PortColumnId.maxConnections => 'MAX CONN',
  PortColumnId.topology => 'TOPOLOGY',
  PortColumnId.gender => 'GENDER',
  PortColumnId.pinoutVariant => 'PINOUT',
  PortColumnId.conductorCount => 'CONDUCTORS',
  PortColumnId.returnChannel => 'RETURN',
  PortColumnId.renamedFrom => 'WAS CALLED',
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
  PortColumnId.impedanceOhms => 84,
  PortColumnId.audioLevel => 104,
  PortColumnId.balanced => 88,
  PortColumnId.phantomPower => 88,
  PortColumnId.polarity => 92,
  PortColumnId.nominalVoltage => 84,
  PortColumnId.maxCurrentMa => 76,
  PortColumnId.poeRole => 92,
  PortColumnId.poeStandard => 96,
  PortColumnId.poeType => 76,
  PortColumnId.poeClass => 80,
  PortColumnId.poeWatts => 68,
  PortColumnId.linkSpeedMbps => 84,
  PortColumnId.sfpFormFactor => 84,
  PortColumnId.fiberMode => 100,
  PortColumnId.wavelengthNm => 88,
  PortColumnId.serialRole => 92,
  PortColumnId.baud => 72,
  PortColumnId.dataBits => 76,
  PortColumnId.stopBits => 76,
  PortColumnId.parity => 76,
  PortColumnId.flowControl => 80,
  PortColumnId.busProtocol => 88,
  PortColumnId.busTermination => 96,
  PortColumnId.busUnitLoads => 84,
  PortColumnId.busAddressable => 100,
  PortColumnId.busMaxTapWatts => 68,
  PortColumnId.powerRole => 108,
  PortColumnId.powerVolts => 68,
  PortColumnId.powerDrawWatts => 72,
  PortColumnId.powerMaxAmps => 68,
  PortColumnId.pairedPort => 108,
  PortColumnId.maxConnections => 84,
  PortColumnId.topology => 100,
  PortColumnId.gender => 100,
  PortColumnId.pinoutVariant => 108,
  PortColumnId.conductorCount => 92,
  PortColumnId.returnChannel => 88,
  PortColumnId.renamedFrom => 108,
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

/// What each pack enum is called on screen.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ELEVEN FUNCTIONS AND NOT ONE `.name`, FOR ONE REASON
/// ═══════════════════════════════════════════════════════════════════════
/// `.name` gives `btType3`, `lineUnbal`, `sfpPlus` and `eArc`. Those are
/// Dart identifiers; the trade says 802.3bt Type 3, line level
/// unbalanced, SFP+ and eARC. A camelCase splitter gets exactly the ones
/// that matter wrong, which is the finding M4-D's dropdowns already paid
/// for: `0U` is not `zero u` and `NEMA 5-15P` is not `nema 5 15 p`.
String portAudioLevelLabel(AudioLevel v) => switch (v) {
  AudioLevel.mic => 'Mic level',
  AudioLevel.lineUnbal => 'Line, unbalanced',
  AudioLevel.lineBal => 'Line, balanced',
  AudioLevel.phono => 'Phono',
  AudioLevel.speaker => 'Speaker level',
};

/// AC-030's terminal polarity: which physical terminal this port IS.
String portPolarityLabel(Polarity v) => switch (v) {
  Polarity.positive => 'Positive (+)',
  Polarity.negative => 'Negative (-)',
  Polarity.none => 'Not polarised',
};

String portPoeRoleLabel(PoeRole v) => switch (v) {
  PoeRole.pse => 'Supplies power (PSE)',
  PoeRole.pd => 'Draws power (PD)',
  PoeRole.none => 'No PoE',
};

String portPoeStandardLabel(PoeStandard v) => switch (v) {
  PoeStandard.af => '802.3af (PoE)',
  PoeStandard.at => '802.3at (PoE+)',
  PoeStandard.btType3 => '802.3bt Type 3',
  PoeStandard.btType4 => '802.3bt Type 4',
};

String portSfpLabel(SfpFormFactor v) => switch (v) {
  SfpFormFactor.sfp => 'SFP',
  SfpFormFactor.sfpPlus => 'SFP+',
  SfpFormFactor.sfp28 => 'SFP28',
};

String portFiberModeLabel(FiberMode v) => switch (v) {
  FiberMode.singleMode => 'Single-mode',
  FiberMode.multiMode => 'Multimode',
};

String portSerialRoleLabel(SerialRole v) => switch (v) {
  SerialRole.dte => 'DTE',
  SerialRole.dce => 'DCE',
};

/// NOT A DIRECTION (CR-058, CR-060). A power port's direction is `sink`
/// or `source` like any other; the role is what makes a C14 an inlet.
String portPowerRoleLabel(PortPowerRole v) => switch (v) {
  PortPowerRole.inlet => 'Inlet (takes power in)',
  PortPowerRole.outlet => 'Outlet (feeds something)',
};

String portTopologyLabel(PortTopology v) => switch (v) {
  PortTopology.p2p => 'Point to point',
  PortTopology.multidrop => 'Multi-drop',
  PortTopology.star => 'Star',
};

/// THREE values (CR-059). The rejected five-value enum held two synonym
/// pairs, and `jack` + `jack` never fired the both-ends-the-same rule.
String portGenderLabel(Gender v) => switch (v) {
  Gender.male => 'Male',
  Gender.female => 'Female',
  Gender.genderless => 'Genderless',
};

String portReturnChannelLabel(ReturnChannel v) => switch (v) {
  ReturnChannel.arc => 'ARC',
  ReturnChannel.eArc => 'eARC',
};

/// What a `bool?` cell reads.
///
/// THREE READINGS, because the field has three states. A checkbox has
/// two, so it would have to call "nobody has measured this port" a no,
/// which is the fabrication G4 exists to stop.
String portTriStateLabel({required bool? value}) => switch (value) {
  null => kUnknownCell,
  true => 'Yes',
  false => 'No',
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
