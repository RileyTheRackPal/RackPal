// THE ARCHETYPE GENERATORS (M4-I, docs/06 §4.3, DR-092 §11.91).
//
// ═════════════════════════════════════════════════════════════════════
// A GENERATOR IS A LIST OF QUICK ADD PLANS AND NOTHING ELSE
// ═════════════════════════════════════════════════════════════════════
// §4.3's buttons "emit whole topologies", which sounds like a second
// authoring engine and is not one. A matrix is six Quick Add commands
// somebody would otherwise type, so this file produces the six PLANS and
// `QuickAddBatch` turns them into commands, against one shared key and
// order allocator (DR-092 §11.91.7).
//
// The alternative, constructing `PortDef`s here, would be a second copy
// of the bank-reuse rule, the label expander and the ordinal allocator.
// `uniqueSlugKey`'s own comment already refuses a third derivation of a
// key; this is the same objection one level up.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT A PLAN CANNOT CARRY, THE DECORATOR WRITES
// ═════════════════════════════════════════════════════════════════════
// docs/12 §5.3.6 records `poe:`, `z:`, `dte` and `tap:` as deliberately
// absent from the DSL: §9.1's thirteen steps exercise none of them and
// the grid's column packs already author all four. So a generator that
// needs PoE, an SFP form factor, a power role or an IR pinout writes it
// through [QuickAddBatch.add]'s `decorate` hook, onto the `PortDef`
// before it enters its `AddPortCommand`. One command per port, and undo
// stays symmetrical.
//
// **THAT IS NOT A GAP BEING PAPERED OVER.** DR-092 §11.91.8 declines to
// widen the grammar for it. A person typing `24 rj45 poe:at` is asking
// the parser to learn a vocabulary; a dialog with a PoE dropdown already
// knows the answer as a value.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIXED COMPANIONS RESOLVE THROUGH THE REGISTRY, NOT THROUGH A
// HARD-CODED ID
// ═════════════════════════════════════════════════════════════════════
// `Control` is LAN, RS-232 and an IR receiver; the inlet is a C14. Those
// are TOKENS here, resolved by the same two resolvers Quick Add uses, so
// a project whose registries lack one gets the empty id the grid's
// validation dot already marks (G4) rather than a dangling reference to
// a family that is not there. It also means this file reads like the
// eight commands it replaces, which is what a reviewer needs to check it.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/label_pattern.dart';
import 'package:rackpal_core/src/builder/port_table.dart' show portSfpLabel;
import 'package:rackpal_core/src/builder/quick_add.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show resolveConnectorToken, resolveSignalFamilyToken;
import 'package:rackpal_core/src/units/ids.dart';

/// The pair a Quick Add type token resolves to (DR-060 §11.59.4).
///
/// **BOTH HALVES, BECAUSE NEITHER ALONE NAMES A MATRIX'S SIDES.** `rj45`
/// defaults to `net.ethernet` and a matrix's HDBaseT output is
/// `video.hdbaset` on that same connector, which is the orthogonality
/// §4.3's "connector per side" quietly loses (DR-092 §11.91.5).
///
/// Either half may be null and that is G4's unknown, not a placeholder:
/// `xlr` names a connector and no family.
@immutable
final class PortType {
  const PortType({this.connector, this.family});

  /// [PortType] for a Quick Add token, or one with both halves null when
  /// neither registry answers.
  ///
  /// Merged widest-first exactly as `parseQuickAdd` merges: the family's
  /// `defaultConnector` fills the connector only when no connector was
  /// named, so `hdbt` yields RJ45 and `rj45 hdbt` still yields RJ45.
  factory PortType.token(Registries registries, String token) {
    final family = resolveSignalFamilyToken(registries, token);
    final connector = resolveConnectorToken(registries, token);
    return PortType(
      connector: connector?.id ?? family?.defaultConnector,
      family: family?.id,
    );
  }

  final ConnectorTypeId? connector;
  final SignalFamilyId? family;

  /// This type with [connector] overriding whatever it carried.
  ///
  /// A NAMED CONNECTOR WINS, which is DR-060 §11.59.4's rule and is what
  /// a dialog's connector dropdown means when it sits beside a family
  /// dropdown that has its own default.
  PortType withConnector(ConnectorTypeId? connector) =>
      PortType(connector: connector ?? this.connector, family: family);

  @override
  bool operator ==(Object other) =>
      other is PortType &&
      other.connector == connector &&
      other.family == family;

  @override
  int get hashCode => Object.hash(connector, family);

  @override
  String toString() => 'PortType(${connector?.v}, ${family?.v})';
}

/// One bank's worth of ports an archetype emits.
///
/// `decorate` is what the plan cannot say: PoE, an SFP form factor, a
/// power role, an IR pinout. Null where there is nothing extra to write,
/// which is most rows.
@immutable
final class ArchetypeGroup {
  const ArchetypeGroup(this.plan, {this.decorate});

  final QuickAddPlan plan;
  final void Function(PortDef port)? decorate;
}

/// The ports and banks a list of groups would add to a template body.
///
/// **A COUNT, COMPUTED BEFORE ANY COMMAND EXISTS**, for the same reason
/// `csv_import_plan.dart` gives: a number derived from a command list is
/// a number nobody can check against the dialog it came from. The dialog
/// prints these two under its checkboxes so a mis-set quantity costs a
/// glance rather than 68 ports and an undo.
@immutable
final class ArchetypePreview {
  const ArchetypePreview({required this.ports, required this.banks});

  final int ports;

  /// **NEW BANKS ONLY.** A group landing in a bank the body already holds
  /// adds ports and no bank, and saying otherwise would over-count every
  /// second run of the same generator.
  final int banks;
}

/// What [groups] will add to [body], counted rather than applied.
ArchetypePreview previewArchetype(
  Registries registries,
  TemplateBody body,
  List<ArchetypeGroup> groups,
) {
  final labels = {for (final b in body.banks) b.label};
  var ports = 0;
  var banks = 0;
  for (final group in groups) {
    ports += group.plan.portCount;
    final label = uniqueBankNameAmong(registries, labels, group.plan);
    if (labels.add(label)) banks++;
  }
  return ArchetypePreview(ports: ports, banks: banks);
}

/// The commands realising [groups] against [body], in one allocation.
///
/// The caller runs them inside ONE `transact`, so 68 ports across 6 banks
/// are one `Ctrl+Z`. Banks lead their own ports for `buildQuickAdd`'s
/// reason: `revert` runs the list backwards, and a port naming a bank
/// that does not exist yet is a dangling reference until it does.
List<Command<TemplateBody>> buildArchetype(
  Registries registries,
  TemplateBody body,
  List<ArchetypeGroup> groups,
) {
  final batch = QuickAddBatch(registries, body);
  return [
    for (final group in groups)
      ...batch.add(group.plan, decorate: group.decorate),
  ];
}

// ─── Matrix I/O ──────────────────────────────────────────────────────

/// docs/06 §4.3's Matrix I/O generator, as data.
///
/// **EVERY COMPANION DEFAULTS OFF** (DR-092 §11.91.6). §9.2's step 5 asks
/// the user to tick four of them, which is what says they start unticked;
/// a generator that emitted a control bank nobody asked for would be
/// making a device up.
@immutable
final class MatrixArchetype {
  const MatrixArchetype({
    required this.inputs,
    required this.inputType,
    required this.outputs,
    required this.outputType,
    this.mirroredOutputs = false,
    this.mirroredType,
    this.audioDeEmbed = false,
    this.audioType,
    this.perOutputIr = false,
    this.control = false,
    this.acInlet = false,
  });

  final int inputs;
  final PortType inputType;
  final int outputs;
  final PortType outputType;

  /// A second, local output per output. §9's 16 HDBaseT outputs each have
  /// an HDMI twin.
  final bool mirroredOutputs;

  /// Null means [inputType], which is what a mirrored output IS: the
  /// local copy of the signal that came in. On an HDBaseT matrix that is
  /// HDMI, and on an HDMI matrix it is the same thing twice.
  final PortType? mirroredType;

  /// One analogue audio output per output.
  final bool audioDeEmbed;

  /// Null means [kMatrixDefaultAudioType], balanced on a 3-pin Euroblock
  /// (DR-092 §11.91.4). `audio.line_bal`'s registry default is XLR3,
  /// which is right for the family and wrong for every rack matrix.
  final PortType? audioType;

  /// One IR emitter output per output. **It also puts an IR receiver
  /// input in Control**, when Control is on: a matrix that flashes
  /// emitters is routing IR, and IR has to arrive from somewhere
  /// (DR-092 §11.91.2).
  final bool perOutputIr;

  /// LAN and RS-232, plus IR IN when [perOutputIr].
  final bool control;

  /// A C14 inlet, carrying `PortPowerSpec.role: inlet`, which docs/06
  /// §4.1's own table promises for `1 c14 in` and which the DSL path does
  /// not write because a plan has no field for it.
  final bool acInlet;
}

/// Balanced line audio on a 3-pin Euroblock (DR-092 §11.91.4).
const PortType kMatrixDefaultAudioType = PortType(
  connector: ConnectorTypeId('conn.euroblock_3'),
  family: SignalFamilyId('audio.line_bal'),
);

/// The bank a matrix's local outputs land in.
///
/// NAMED RATHER THAN DERIVED, because deriving it from the family gives
/// "HDMI Outputs" a second time and `uniqueBankName` would answer
/// "HDMI Outputs 2", which is a suffix where §9 prints a name.
const String kMirrorOutputsBank = 'Mirror Outputs';

/// The bank a matrix's de-embedded audio lands in.
const String kAudioOutputsBank = 'Audio Outputs';

/// The bank LAN, RS-232 and IR IN share. §9.1 types `@Control` three
/// times to build it, and an explicit name is never suffixed.
const String kControlBank = 'Control';

/// [spec] as the groups that build it.
///
/// **THE ORDER IS §9's ORDER**, because it is the order the ports appear
/// on the rear of the device and therefore the order an installer reads
/// the grid in: inputs, outputs, mirrors, audio, IR, control, power.
List<ArchetypeGroup> planMatrixArchetype(
  Registries registries,
  MatrixArchetype spec,
) {
  final groups = <ArchetypeGroup>[];

  final inHead = deriveTypeHead(
    registries,
    spec.inputType.family,
    spec.inputType.connector,
  );
  final outHead = deriveTypeHead(
    registries,
    spec.outputType.family,
    spec.outputType.connector,
  );

  groups
    ..add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.inputs,
          type: spec.inputType,
          direction: PortDirection.sink,
          label: _sideLabel(inHead, 'IN', spec.inputs),
        ),
      ),
    )
    ..add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.outputs,
          type: spec.outputType,
          direction: PortDirection.source,
          label: _sideLabel(outHead, 'OUT', spec.outputs),
        ),
      ),
    );

  if (spec.mirroredOutputs) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.outputs,
          type: spec.mirroredType ?? spec.inputType,
          direction: PortDirection.source,
          label: 'MIRROR ${_seq(spec.outputs)}',
          bank: kMirrorOutputsBank,
        ),
      ),
    );
  }

  if (spec.audioDeEmbed) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.outputs,
          type: spec.audioType ?? kMatrixDefaultAudioType,
          direction: PortDirection.source,
          label: 'AUDIO OUT ${_seq(spec.outputs)}',
          bank: kAudioOutputsBank,
        ),
      ),
    );
  }

  if (spec.perOutputIr) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.outputs,
          type: PortType.token(registries, 'ir35'),
          direction: PortDirection.source,
          label: 'IR OUT ${_seq(spec.outputs)}',
        ),
        decorate: _irEmitterPinout,
      ),
    );
  }

  if (spec.control) {
    groups
      ..add(
        ArchetypeGroup(
          archetypePlan(
            registries,
            quantity: 1,
            type: PortType.token(registries, 'rj45'),
            direction: PortDirection.sink,
            label: 'LAN',
            bank: kControlBank,
          ),
        ),
      )
      ..add(
        ArchetypeGroup(
          archetypePlan(
            registries,
            quantity: 1,
            type: PortType.token(registries, 'rs232'),
            direction: PortDirection.bidirectional,
            label: 'RS-232',
            bank: kControlBank,
          ),
        ),
      );
    // THE 68th PORT (DR-092 §11.91.2). `ctl.ir_receiver` and NOT the
    // emitter family: an IR port that listens is a receiver, which is
    // the same rule `_kDirectionalFamilies` applies to `ir35 in` in the
    // parser, applied here by a generator that already knows.
    if (spec.perOutputIr) {
      groups.add(
        ArchetypeGroup(
          archetypePlan(
            registries,
            quantity: 1,
            type: PortType.token(registries, 'irrx'),
            direction: PortDirection.sink,
            label: 'IR IN',
            bank: kControlBank,
          ),
          decorate: _irReceiverPinout,
        ),
      );
    }
  }

  if (spec.acInlet) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: 1,
          type: PortType.token(registries, 'c14'),
          direction: PortDirection.sink,
          label: 'AC IN',
        ),
        decorate: _acInlet,
      ),
    );
  }

  return groups;
}

// ─── The shared plumbing ─────────────────────────────────────────────

/// A [QuickAddPlan] for a generator, indistinguishable from a typed one.
///
/// **`source` IS THE RENDERED COMMAND AND NOT THE EMPTY STRING.**
/// `renderQuickAdd` is the fields-to-command direction that field mode
/// already round-trips through, so what lands here is what a person would
/// have typed to get the same ports. A plan carrying `''` would make any
/// surface that ever shows its provenance lie about it.
QuickAddPlan archetypePlan(
  Registries registries, {
  required int quantity,
  required PortType type,
  required PortDirection direction,
  required String label,
  String? bank,
  Face face = Face.rear,
}) {
  final pattern = parseLabelPattern(label);
  QuickAddPlan make(String source) => QuickAddPlan(
    source: source,
    quantity: quantity,
    connector: type.connector,
    family: type.family,
    direction: direction,
    // EXPLICIT, NEVER NULL. `buildQuickAdd` treats null as rear anyway,
    // and saying so is what makes `renderQuickAdd`'s output a command a
    // person could paste back. Rear is the default because that is where
    // rack device I/O lives; a switch's CONSOLE port is the exception the
    // parameter exists for, and the seeded N01 puts it on the front.
    face: face,
    bothFaces: false,
    passthrough: false,
    // A pattern that will not parse is dropped rather than thrown: the
    // labels here are assembled from registry aliases, and an alias
    // containing a brace would otherwise take a dialog down.
    labelPattern: pattern is LabelPattern ? pattern : null,
    bankName: bank,
  );
  return make(renderQuickAdd(registries, make('')));
}

/// `{n:2}`, widened only when the count needs it.
///
/// TWO IS THE FLOOR because §9's labels are `HDMI IN 01`, and a rack
/// silkscreen pads: `IN 1` beside `IN 10` sorts and reads wrong in every
/// schedule this template will appear in.
String _seq(int quantity) {
  final width = quantity.toString().length;
  return '{n:${width < 2 ? 2 : width}}';
}

/// `HDMI IN 01`, or `IN 01` for a type with no word for itself.
///
/// **THE HEAD IS DROPPED, NOT SUBSTITUTED.** The first draft fell back to
/// the direction word and then appended it again, which reads `IN IN 01`
/// on any port whose type resolved to neither registry. A `""` head is a
/// missing prefix, not a missing label.
String _sideLabel(String head, String direction, int quantity) => head.isEmpty
    ? '$direction ${_seq(quantity)}'
    : '$head $direction ${_seq(quantity)}';

/// The two IR pinouts, spelled as the seeded catalog spells them.
///
/// AC-052 and `seed_registries.dart`: an emitter plugged into a receiver
/// jack meets +12 V on the ring and dies. `port_validation.dart` raises
/// the file's only hardware warning when this is blank, and a generator
/// that picked the family knows the answer (DR-092 §11.91.3).
void _irEmitterPinout(PortDef port) => port.pinoutVariant = 'mono-tip-sleeve';

void _irReceiverPinout(PortDef port) => port.pinoutVariant = 'xantech-stereo';

/// docs/06 §4.1's own table: `1 c14 in` is an AC inlet, and an inlet is a
/// `power.*` family plus a ROLE. "Inlet and outlet are not directions."
///
/// **AND IT IS MALE, WHICH IS NOT A GUESS AND NOT AN UNKNOWN.**
/// `conn.iec_c14` declares `genderApplies: true`, and all thirteen C14
/// inlets in the seeded catalog write `Gender.male` because a C14 IS the
/// pinned appliance inlet: the C13 on the cord carries the sockets. The
/// field is non-nullable and defaults to `genderless`, so leaving it
/// alone is not silence, it is a positive claim that the connector has no
/// gender when its own registry entry says it does.
void _acInlet(PortDef port) => port
  ..power = PortPowerSpec(role: PortPowerRole.inlet)
  ..gender = Gender.male;

// ─── Switch ports ────────────────────────────────────────────────────

/// docs/06 §4.3's Switch ports generator, as data (`#221`).
///
/// **THE SPECIFICATION IS `catalog_network.dart`'s N01, NOT §4.3's
/// SENTENCE.** The seeded catalog already holds this device: a 48-port
/// PoE switch with SFP28 uplinks, an out-of-band management port, a
/// front-panel console and two PSU inlets. Every field below is the field
/// N01 writes, in the bank N01 puts it in, and the two places this
/// generator could have invented something it instead reads off the seed.
///
/// The one place it deliberately writes LESS than it could: `PoeSpec.type`
/// is a second spelling of [poeStandard] and `PoeSpec.watts` is a
/// per-device power budget rather than a standard's number. N01 leaves
/// both absent and so does this.
@immutable
final class SwitchArchetype {
  const SwitchArchetype({
    required this.accessPorts,
    this.accessType,
    this.accessLinkSpeedMbps = 1000,
    this.poe = false,
    this.poeStandard = PoeStandard.at,
    this.poeClass,
    this.uplinks = 0,
    this.sfp = SfpFormFactor.sfpPlus,
    this.managementPort = false,
    this.console = false,
    this.acInlet = false,
    this.redundantPsu = false,
  });

  final int accessPorts;

  /// Null means [kSwitchDefaultAccessType], RJ45 Ethernet.
  final PortType? accessType;

  /// N01 writes 1000 here. Null is a legal unknown and the grid marks it.
  final int? accessLinkSpeedMbps;

  /// The access ports supply power: `PoeSpec.role: pse`.
  final bool poe;
  final PoeStandard poeStandard;

  /// IEEE class 0 to 8, or null. **THE ONE PoE FIELD THE DIALOG ASKS FOR
  /// RATHER THAN DERIVING**, because a switch may support a lower class
  /// than its standard permits and the person authoring knows which.
  final int? poeClass;

  /// SFP-caged uplinks. Zero is a real answer: an unmanaged eight-port
  /// switch has none.
  final int uplinks;

  /// Sets the uplink label and its link speed, both definitionally: an
  /// SFP cage IS 1G, an SFP+ 10G and an SFP28 25G.
  final SfpFormFactor sfp;

  /// `OOB MGMT`, RJ45 Ethernet, rear.
  final bool managementPort;

  /// `CONSOLE`, DE9 / RS-232, **front**, which is where N01 puts it and
  /// where a technician commissioning a switch reaches for it.
  final bool console;

  /// One C14 inlet, or two when [redundantPsu].
  final bool acInlet;

  /// A second inlet, so the pair is labelled `PSU A` and `PSU B` rather
  /// than `AC IN`. Does nothing while [acInlet] is off, and the dialog
  /// disables it there rather than letting it read as ticked and inert.
  final bool redundantPsu;
}

/// RJ45 Ethernet, which is what an access port is.
const PortType kSwitchDefaultAccessType = PortType(
  connector: ConnectorTypeId('conn.rj45'),
  family: SignalFamilyId('net.ethernet'),
);

/// The four bank labels, spelled as `catalog_network.dart` spells them.
///
/// **NAMED AND NOT DERIVED, and the uplinks are why.** `deriveBankName`
/// would answer "LAN Ports" for the access bank and "DAC Ports" for the
/// uplinks, which are two spellings of "Ethernet" that tell a person
/// nothing about which bank is which. Access and uplink is the
/// distinction that matters on a switch and it is not a signal-family
/// distinction at all.
const String kAccessPortsBank = 'Access Ports';
const String kUplinksBank = 'Uplinks';
const String kManagementBank = 'Management';
const String kPowerBank = 'Power';

/// [spec] as the groups that build it, in N01's order.
List<ArchetypeGroup> planSwitchArchetype(
  Registries registries,
  SwitchArchetype spec,
) {
  final groups = <ArchetypeGroup>[
    ArchetypeGroup(
      archetypePlan(
        registries,
        quantity: spec.accessPorts,
        type: spec.accessType ?? kSwitchDefaultAccessType,
        direction: PortDirection.bidirectional,
        // BARE NUMBERS, which is what is silkscreened between the jacks
        // on every switch ever made and what N01 writes: `01` … `48`.
        label: _seq(spec.accessPorts),
        bank: kAccessPortsBank,
      ),
      decorate: (port) {
        port.linkSpeedMbps = spec.accessLinkSpeedMbps;
        if (!spec.poe) return;
        // A NEW `PoeSpec` PER PORT. It is a mutable class, so one
        // instance captured by this closure would be SHARED by all
        // forty-eight ports, and editing one port's class in the grid
        // would silently edit the whole bank.
        port.poe = PoeSpec(
          role: PoeRole.pse,
          standard: spec.poeStandard,
          poeClass: spec.poeClass,
        );
      },
    ),
  ];

  if (spec.uplinks > 0) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.uplinks,
          type: PortType.token(registries, 'dac'),
          direction: PortDirection.bidirectional,
          // `{n}` AND NOT `{n:2}`, unlike the access bank. N01 spells
          // `SFP28 1`, and a bank of four is a list of names rather than
          // a numbered column a schedule sorts on.
          // `portSfpLabel` AND NOT A SECOND SWITCH. The grid's SFP
          // column already prints `SFP`, `SFP+`, `SFP28`, and a label
          // function beside it would be one more place for the three to
          // be spelled differently.
          label: '${portSfpLabel(spec.sfp)} {n}',
          bank: kUplinksBank,
        ),
        decorate: (port) => port
          ..sfp = spec.sfp
          ..linkSpeedMbps = switchSfpLinkSpeedMbps(spec.sfp),
      ),
    );
  }

  if (spec.managementPort) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: 1,
          type: PortType.token(registries, 'lan'),
          direction: PortDirection.bidirectional,
          label: 'OOB MGMT',
          bank: kManagementBank,
        ),
      ),
    );
  }

  if (spec.console) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: 1,
          type: PortType.token(registries, 'rs232'),
          direction: PortDirection.bidirectional,
          label: 'CONSOLE',
          bank: kManagementBank,
          // THE ONE FRONT-FACE PORT IN EITHER GENERATOR, and N01 is why:
          // a console port is reached while standing in front of the
          // rack with a laptop, so it is on the front of the switch.
          face: Face.front,
        ),
      ),
    );
  }

  if (spec.acInlet) {
    groups.add(
      ArchetypeGroup(
        archetypePlan(
          registries,
          quantity: spec.redundantPsu ? 2 : 1,
          type: PortType.token(registries, 'c14'),
          direction: PortDirection.sink,
          // `{A}` IS M4-H's ALPHA TOKEN, expanding to `PSU A` and
          // `PSU B`, which is exactly what N01 calls them. A single
          // inlet is `AC IN` because there is no B to be the A of.
          label: spec.redundantPsu ? 'PSU {A}' : 'AC IN',
          bank: kPowerBank,
        ),
        decorate: _acInlet,
      ),
    );
  }

  return groups;
}

/// The cage's own rate, which is not an estimate: SFP is 1G, SFP+ is 10G
/// and SFP28 is 25G by definition of the form factor. N01 writes 25000
/// beside its SFP28 cages for this reason.
int switchSfpLinkSpeedMbps(SfpFormFactor sfp) => switch (sfp) {
  SfpFormFactor.sfp => 1000,
  SfpFormFactor.sfpPlus => 10000,
  SfpFormFactor.sfp28 => 25000,
};
