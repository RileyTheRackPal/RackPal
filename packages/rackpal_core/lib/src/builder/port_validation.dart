// The port grid's live validation (docs/06 §4.5, M4-E4 #206).
//
// ═══════════════════════════════════════════════════════════════════════
// NONE OF IT BLOCKS SAVING, AND THAT IS THE WHOLE DESIGN
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §4.5 states it twice and the board task states it again. AC-049
// is the reason: three fields make a template, and a template saved with
// three fields is not incomplete, it is a template. A checker that can
// stop a save is a fourth required field wearing a warning triangle, and
// `_canSave` reading anything from this file is how this editor becomes
// the thing AC-049 deleted.
//
// So these produce a dot in the row gutter and a sentence on hover, and
// nothing else. G3's validation philosophy one layer up says the same:
// the app reports, the user decides.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO RULES NAME CATALOG IDS, AND THERE IS A TEST HOLDING THEM
// ═══════════════════════════════════════════════════════════════════════
// The S/PDIF and IR rules key on a `SignalFamilyId` spelled out below.
// The durable form of that is a field on `SignalFamilyDef` — something
// like "this family requires an impedance" — and it is not built, so a
// rename in the seeded registries would silently disable a safety check
// rather than break a build. `port_validation_test.dart` therefore
// resolves every id here against the shipped registries, so a rename
// fails a test on the day it happens.
import 'package:rackpal_core/src/builder/port_table.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Coaxial S/PDIF, which is a 75 ohm connection wherever it appears.
const kSpdifCoaxFamily = SignalFamilyId('audio.spdif_coax');

/// The two IR families, which are separate BECAUSE the pinout differs and
/// getting it wrong is destructive: a receiver is tip signal, ring ground,
/// sleeve +12 V; an emitter is tip IR, sleeve ground. Plugging an emitter
/// into a receiver jack destroys the emitter and can damage the supply.
const kIrFamilies = <SignalFamilyId>{
  SignalFamilyId('ctl.ir_emitter'),
  SignalFamilyId('ctl.ir_receiver'),
};

/// The impedance coaxial S/PDIF is specified at.
const kSpdifImpedanceOhms = 75;

/// How loudly a finding is drawn.
///
/// TWO, NOT FIVE. The distinction that earns its keep is "this will be
/// wrong on a drawing or will damage hardware" against "this is unusual
/// and may be deliberate". A third level would be a taste rather than a
/// difference a person acts on differently.
enum PortIssueSeverity {
  /// Unusual, possibly deliberate. A hollow dot.
  notice,

  /// Will print wrong, or will hurt something. A filled dot.
  warning,
}

/// One thing worth saying about one port.
final class PortIssue {
  const PortIssue({
    required this.severity,
    required this.column,
    required this.message,
  });

  final PortIssueSeverity severity;

  /// Which column the reader should look at, so the dot can say where to
  /// go rather than only that something is wrong. Null when the finding
  /// is about the port as a whole.
  final PortColumnId? column;

  /// PLAIN TRADE ENGLISH, and no ruling id. This lands on a tooltip in
  /// front of an installer; the citation belongs in the comment beside
  /// the rule, which is where the next implementer stands.
  final String message;
}

/// Every finding on [body]'s ports, keyed by port key.
///
/// A MAP RATHER THAN A LIST, because the grid asks the question one row
/// at a time and a 68-row template would otherwise scan the whole list
/// per row. Ports with nothing to say are absent rather than present with
/// an empty list.
Map<String, List<PortIssue>> validatePorts(TemplateBody body) {
  final issues = <String, List<PortIssue>>{};
  void add(PortKey key, PortIssue issue) =>
      issues.putIfAbsent(key.v, () => <PortIssue>[]).add(issue);

  // ── Duplicate designators ──────────────────────────────────────────
  // ONLY THE TYPED ONES CAN COLLIDE. An automatic designator is rendered
  // from the port's position in the declared order, which is injective by
  // construction, so a duplicate is always something a person typed
  // (CR-042: unique WITHIN the device).
  final byDesignator = <String, List<PortKey>>{};
  for (final port in body.ports) {
    final pinned = (port.designatorHint ?? '').trim();
    if (pinned.isEmpty) continue;
    byDesignator.putIfAbsent(pinned, () => <PortKey>[]).add(port.key);
  }
  for (final entry in byDesignator.entries) {
    if (entry.value.length < 2) continue;
    for (final key in entry.value) {
      add(
        key,
        PortIssue(
          severity: PortIssueSeverity.warning,
          column: PortColumnId.designator,
          message:
              'Another port on this device is also called ${entry.key}. '
              'Two ports with one name send an installer to the wrong '
              'jack.',
        ),
      );
    }
  }

  // ── Passthrough ports with no pair ─────────────────────────────────
  // A NOTICE AND NOT A WARNING, and docs/06 §4.6 says why: a passthrough
  // template whose pairs are missing is a load warning rather than an
  // error, so a half-paired panel mid-authoring must not shout.
  if (body.isPassthrough) {
    final paired = <String>{
      for (final pair in body.passthroughPairs) ...{
        pair.frontKey.v,
        pair.rearKey.v,
      },
    };
    for (final port in body.ports) {
      if (paired.contains(port.key.v)) continue;
      add(
        port.key,
        const PortIssue(
          severity: PortIssueSeverity.notice,
          column: PortColumnId.pairedPort,
          message:
              'Not paired with a port on the other face. A patch panel '
              'pairs each front jack with the rear one behind it, so a '
              'trace can follow a cable through.',
        ),
      );
    }
  }

  // ── A port set with fewer than two members ─────────────────────────
  // A NOTICE, on the passthrough notice's precedent above and for its
  // reason: a half-finished template mid-authoring must not shout.
  //
  // `Group as set…` cannot mint one (DR-086 §11.85.2 refuses under two
  // rows), and that is not the same as the state being unreachable:
  // `Delete` on a member leaves one, the `SET` column can move the other
  // member out, and a hand-edited `.rmdx` can arrive holding one.
  // `port_set_integrity_test.dart` gates the SEED on exactly this and
  // nothing gates an authored template.
  //
  // WHY IT MATTERS RATHER THAN BEING UNTIDY: `planAtomicConnect` resolves
  // the set, finds one member, and degrades to a ONE-CONDUCTOR LINK WITH
  // NO ERROR. The half-declared pair is the failure docs/catalog's own
  // C-table names, and it looks complete on the schedule.
  //
  // AN EMPTY SET GETS NO NOTICE, because there is no row to hang one on.
  // `Ungroup` sweeps the set it empties for that reason.
  final setMembers = <String, List<PortKey>>{};
  for (final port in body.ports) {
    final key = port.setKey;
    if (key == null || key.isEmpty) continue;
    setMembers.putIfAbsent(key, () => <PortKey>[]).add(port.key);
  }
  for (final set in body.portSets) {
    final members = setMembers[set.key] ?? const <PortKey>[];
    if (members.length != 1) continue;
    add(
      members.single,
      PortIssue(
        severity: PortIssueSeverity.notice,
        column: PortColumnId.portSet,
        message:
            'The only port in "${set.label}". A set of one has nothing to '
            'connect atomically, so a cable drawn to it carries one '
            'conductor and says nothing about the missing half.',
      ),
    );
  }

  for (final port in body.ports) {
    // ── Coaxial S/PDIF at the wrong impedance ────────────────────────
    // KEYED ON THE FAMILY AND NOT ON THE CONNECTOR, though docs/06 §4.5
    // words it as "an RCA carrying spdif". S/PDIF coax is 75 ohm on a
    // BNC too, and the seeded catalog's own default connector for this
    // family is `conn.rca75` rather than `conn.rca`. Checking the family
    // catches the case the wording describes and the ones it does not.
    if (port.signalFamily.v == kSpdifCoaxFamily.v &&
        port.impedanceOhms != kSpdifImpedanceOhms) {
      add(
        port.key,
        PortIssue(
          severity: PortIssueSeverity.notice,
          column: PortColumnId.impedanceOhms,
          message: port.impedanceOhms == null
              ? 'Coaxial S/PDIF is a 75 ohm connection. Set the impedance '
                    'to 75 so the cable schedule specifies the right cable.'
              : 'Coaxial S/PDIF is 75 ohm, and this says '
                    '${port.impedanceOhms}.',
        ),
      );
    }

    // ── An IR jack that does not say which way it is wired ───────────
    // THE ONLY WARNING HERE THAT IS ABOUT HARDWARE RATHER THAN PAPER.
    // The seeded registries carry the two IR families separately for
    // exactly this reason, and AC-052 makes the value citable before a
    // template ships in the catalog.
    if (kIrFamilies.any((f) => f.v == port.signalFamily.v) &&
        (port.pinoutVariant ?? '').trim().isEmpty) {
      add(
        port.key,
        const PortIssue(
          severity: PortIssueSeverity.warning,
          column: PortColumnId.pinoutVariant,
          message:
              'Say how this IR jack is wired. Emitters and receivers use '
              'the same plug and opposite pinouts, so plugging one into '
              'the other destroys the emitter.',
        ),
      );
    }
  }

  return issues;
}

/// The loudest severity in [issues], or null when there is nothing to say.
PortIssueSeverity? worstIssue(List<PortIssue>? issues) {
  if (issues == null || issues.isEmpty) return null;
  return issues.any((i) => i.severity == PortIssueSeverity.warning)
      ? PortIssueSeverity.warning
      : PortIssueSeverity.notice;
}
