// Tier-3 cable rules: `LEN-001`, `LEN-002`, `ELE-003`, `LNK-020`
// (`#284`, `#763`, `#280`, `#292`).
//
// ═════════════════════════════════════════════════════════════════════
// "LENGTH UNKNOWN, CANNOT VERIFY" IS A FINDING, NOT A SILENCE
// ═════════════════════════════════════════════════════════════════════
// docs/02 §5.3 says it twice, once for each length rule, and gives the
// reason in five words: *"silence reads as approval."* A run whose length
// nobody has measured is not a run that passes; it is a run nobody has
// checked, and a DRC that says nothing about it has told the reader it is
// fine.
//
// That makes these two the only rules in the tier-3 set that emit a
// finding for an ABSENCE.
//
// IT IS THE SAME RULE AT THE SAME SEVERITY, and the first draft got that
// wrong. It stamped `advisory` on the unknown case, reasoning that an
// unmeasured run is a checklist item — which is a nice argument and is
// not in the catalogue. docs/02 §5.3 gives `LEN-001` one severity and one
// row, and says only that the unknown case *"emits 'length unknown,
// cannot verify' rather than passing silently"*. A predicate inventing a
// second severity would be inventing a rule (CR-021), and the evaluator
// overwrites it anyway: `projectSeverity` is the single place severity is
// decided, which is exactly why the test caught this.
//
// So the MESSAGE distinguishes the two cases and the severity does not.
//
// ═════════════════════════════════════════════════════════════════════
// `LEN-002` IS GENERIC BY CONSTRUCTION (DR-020)
// ═════════════════════════════════════════════════════════════════════
// *"One rule reading the registry, not one rule per medium, so a new
// limit is a registry row rather than a new ruling."* Seven of the 38
// shipped media types declare a `maxRunLengthPassive`, so the rule is
// SILENT on the other thirty-one and counts them rather than treating a
// null limit as zero.
//
// AND IT READS `maxRunLengthPassive`, NEVER THE EMPTY
// `maxRunLengthActive` BESIDE IT (canon §11.19.7). The two are one
// character apart and only one of them is populated.

import 'package:rackpal_core/src/derived/structure_table.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// The length this run is known to be, or null when nobody has said.
///
/// `terminatedLength` FIRST. `link.dart`'s own note: the pull sheet's
/// number is what to ORDER and the terminated figure is what is in the
/// wall, and a channel-length rule is about the wall.
Len? knownLengthOf(Link link) => link.terminatedLength ?? link.cutLength;

/// 100 m, the Ethernet channel limit docs/02 §5.3 names.
///
/// PUBLISHED STANDARD, and stated as the channel rather than as the
/// horizontal run: §5.3 gives it as *"100 m (90 m horizontal + 10 m
/// patch)"*, and what this product stores is the whole run, so the
/// channel figure is the one that can be compared to it.
final Len kEthernetChannelLimit = Len.fromMillimetres(100000);

/// `LEN-001` — an Ethernet channel exceeds 100 m, or is unmeasured.
///
/// ═══════════════════════════════════════════════════════════════════
/// EXPECT THIS RULE TO BE QUIET, AND DO NOT READ THAT AS BROKEN
/// ═══════════════════════════════════════════════════════════════════
/// The M5-H2 domain review (DR-125) predicts that `LEN-001` and
/// `LEN-002` will rarely fire before the plan view's run estimation
/// exists: **a residential run near 100 m is uncommon**, and the case
/// that reaches it is usually a second building, where the trade
/// answer is fibre or a wireless bridge rather than a long copper run.
///
/// So the over-length limb will sit idle and the **unmeasured** limb
/// will do nearly all the work, which is by design: docs/02 §5.3 makes
/// *"length unknown, cannot verify"* a finding rather than silence.
/// This note exists because a rule that never fires looks identical to
/// a rule that is broken, and the AC-051 corpus is what shows the
/// difference: `LEN-001` and `LEN-002` both carry a known-bad that
/// fires and a near-miss that does not.
///
/// **Nothing here changes.** The review named a usage expectation, not
/// a defect, and a rule priced for the job it is rare on is still
/// correct on the job it is not.
List<Finding> ruleLen001(RackDocument doc) {
  final out = <Finding>[];
  for (final link in doc.links.values) {
    // WHICH RUNS THIS IS ABOUT, decided by the FAMILY its services carry
    // rather than by the media type: `net.ethernet` on Cat6 and on Cat6A
    // is the same channel limit, and a rule keyed to the medium would
    // need a row per cable.
    final isEthernet = link.services.any(
      (s) => s.signalFamily.v == 'net.ethernet',
    );
    if (!isEthernet) continue;

    final length = knownLengthOf(link);
    if (length == null) {
      out.add(
        Finding(
          ruleId: 'LEN-001',
          severity: Severity.error,
          message:
              '${link.designator} carries Ethernet and has no measured '
              'length, so the 100 m channel limit cannot be verified.',
          targets: [link.id],
          primaryEntityId: link.id,
        ),
      );
      continue;
    }
    if (length.nm <= kEthernetChannelLimit.nm) continue;
    out.add(
      Finding(
        ruleId: 'LEN-001',
        severity: Severity.error,
        message:
            '${link.designator} is ${_metres(length)} m, over the 100 m '
            'Ethernet channel limit.',
        targets: [link.id],
        primaryEntityId: link.id,
      ),
    );
  }
  return out;
}

/// `LEN-002` — a run exceeds its media type's declared maximum (DR-020).
List<Finding> ruleLen002(RackDocument doc) {
  final out = <Finding>[];
  for (final link in doc.links.values) {
    final media = doc.registries.mediaTypes[link.media];
    final limit = media?.maxRunLengthPassive;
    // A MEDIUM WITH NO DECLARED LIMIT IS SILENT, not a zero limit. Seven
    // of the 38 shipped types declare one; treating the other
    // thirty-one as zero would report every cable in the project.
    if (media == null || limit == null) continue;

    final length = knownLengthOf(link);
    if (length == null) {
      out.add(
        Finding(
          ruleId: 'LEN-002',
          severity: Severity.warning,
          message:
              '${link.designator} is ${media.displayName} and has no '
              'measured length, so its ${_metres(limit)} m maximum cannot '
              'be verified.',
          targets: [link.id],
          primaryEntityId: link.id,
        ),
      );
      continue;
    }
    if (length.nm <= limit.nm) continue;
    out.add(
      Finding(
        ruleId: 'LEN-002',
        severity: Severity.warning,
        message:
            '${link.designator} is ${_metres(length)} m and '
            '${media.displayName} is rated to ${_metres(limit)} m.',
        targets: [link.id],
        primaryEntityId: link.id,
      ),
    );
  }
  return out;
}

/// `ELE-003` — speaker polarity inverted between a pair's two ends.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE ROLE STRINGS ARE THE DATUM, BECAUSE THERE IS NO POLARITY FIELD
/// ═════════════════════════════════════════════════════════════════════
/// `Conductor.role` is what a speaker pair's two legs are told apart by,
/// and a pair wired `+` to `-` is the inversion AC-030 is about. There is
/// no `polarity` on a conductor to compare, so what this rule can see is
/// a conductor whose OWN two ends disagree about which leg they are.
///
/// It is a `warning` and demoted from error on purpose (docs/02 §5.3): a
/// reversed speaker plays, and the fault is audible rather than
/// destructive.
List<Finding> ruleEle003(RackDocument doc) {
  final out = <Finding>[];
  for (final link in doc.links.values) {
    final isSpeaker = link.services.any(
      (s) =>
          s.signalFamily.v == 'audio.speaker_lowz' ||
          s.signalFamily.v == 'audio.speaker_cv',
    );
    if (!isSpeaker) continue;
    for (final conductor in link.conductors) {
      final ends = [conductor.from, conductor.to].whereType<PortEndpoint>();
      if (ends.length != 2) continue;
      final legs = <String>{};
      for (final end in ends) {
        final port = doc.ports[end.portId];
        final leg = _legOf(port?.designator ?? '');
        if (leg != null) legs.add(leg);
      }
      // BOTH LEGS ON ONE CONDUCTOR IS THE INVERSION. One leg means the
      // two ends agree; none means neither jack is marked, which is
      // UNKNOWN and skipped rather than reported (G4) — an unmarked
      // terminal block is not a wiring fault.
      if (legs.length < 2) continue;
      out.add(
        Finding(
          ruleId: 'ELE-003',
          severity: Severity.warning,
          message:
              '${link.designator} runs its ${conductor.role} conductor from '
              'a + terminal to a - terminal, so that speaker is out of '
              'phase.',
          targets: [link.id],
          primaryEntityId: link.id,
        ),
      );
    }
  }
  return out;
}

/// `'+'` or `'-'` if [designator] marks a polarity, else null.
String? _legOf(String designator) {
  if (designator.contains('+')) return '+';
  if (designator.contains('-')) return '-';
  return null;
}

/// `LNK-020` — N links have unbound endpoints. A CHECKLIST, NOT A FAILURE.
///
/// ONE FINDING FOR THE WHOLE PROJECT, which is what "N links" means and
/// what makes it a checklist. Fifteen separate advisories for fifteen
/// unpulled drops would be fifteen rows a person has to dismiss to see
/// the two that are errors; one row saying "fifteen ends are still open"
/// is the thing AC-018 designed the state for.
List<Finding> ruleLnk020(RackDocument doc) {
  final unlanded = unlandedHomeRunIds(doc);
  if (unlanded.isEmpty) return const [];
  return [
    Finding(
      ruleId: 'LNK-020',
      severity: Severity.advisory,
      message: unlanded.length == 1
          ? 'One run still has an end to land.'
          : '${unlanded.length} runs still have an end to land.',
      // EVERY LINK, sorted, so the fingerprint moves when the SET does.
      // Landing one of fifteen changes the checklist and must not leave
      // an acknowledgement of "fifteen" standing over fourteen.
      targets: [...unlanded]..sort((a, b) => a.v.compareTo(b.v)),
    ),
  ];
}

/// [len] in metres, to one decimal place.
String _metres(Len len) => (len.nm / 1000000000).toStringAsFixed(1);
