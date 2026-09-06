// A DRC finding, and the fingerprint an acknowledgement joins on
// (`#258`, M5-B1, CR-019).
//
// ═══════════════════════════════════════════════════════════════════════
// COMPUTED, NEVER STORED
// ═══════════════════════════════════════════════════════════════════════
// docs/02 §4.8's decision table, in terms: *"`Finding` is computed, never
// stored | Persisted findings. Only acknowledgements persist."* §7's sync
// table says the same from the other side: *"purely derived; recomputed
// on both sides."* So this type lives in `validation/` beside the rules
// and NOT in `model/`, it has no codec entry, and `finding_test.dart`
// scans `json_codec.dart` to keep it that way. A stored finding is a
// second copy of an answer the rules can always recompute, and the copy
// is the one that goes stale.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FINGERPRINT IS BUILT FROM STABLE IDS AND NOTHING ELSE (DR-110's
// sibling decision, ruled at M5-B1)
// ═══════════════════════════════════════════════════════════════════════
// docs/02 §6.2's worked example shows
// `"targetFingerprint": "SIG-001:W002:6d2bef45/7e3cb056"`, which carries
// a link DESIGNATOR in the middle. That shape cannot be used, and the
// reason is rule 42 in the same document: *"a stale acknowledgement (one
// whose `targetFingerprint` is no longer produced by any current finding)
// is garbage-collected on load"*.
//
// Designators are allocated, not chosen. `Ctrl+Shift+D` renumbers a
// column of them, `ProjectSettings.linkDesignatorFormat` can be edited,
// and every one of those edits would change the fingerprint of every
// affected finding. Rule 42 would then delete the acknowledgements
// silently, on load, as garbage. A person who acknowledged forty findings
// with written reasons would lose all forty to a renumber, and the log
// line would say the acknowledgements were stale rather than that the
// tool had moved the goalposts underneath them.
//
// So: `ruleId` plus a digest over the participants' STABLE ids. It
// survives a renumber, a rename, a move, a re-layout and a sheet edit,
// because none of those changes what the finding is about.
//
// SORTED, so a joint fingerprints the same from either end. `DIR-001` is
// about a pair of ports and the pair is unordered; a fingerprint that
// depended on which end the evaluation happened to start at would give
// one finding two identities and let an acknowledgement miss its own
// finding on the next build.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/units/ids.dart';

/// `AckedFinding.targetFingerprint` for a project-wide mute of a rule,
/// where CR-019 makes the reason REQUIRED because it prints on `T0.02`.
///
/// A real fingerprint always contains a `:`, so it can never collide with
/// this, and [findingFingerprint] asserts that rather than trusting it.
const String kProjectWideFingerprint = '*';

/// How many hex characters of the digest the fingerprint carries.
///
/// SIXTEEN, which is 64 bits. The worked example in docs/02 §6.2 used
/// eight per endpoint; this is one digest over all participants instead,
/// and the extra width is free because the string is never typed by a
/// person and never printed on a sheet. `AckedFinding.reason` is what
/// prints.
const int kFingerprintHexLength = 16;

/// The identity an `AckedFinding` joins on, for [ruleId] about [targets].
///
/// STABLE IDS ONLY. Passing a designator, a label, a position or an index
/// here would make an acknowledgement fragile to edits that do not change
/// what the finding is about; see this file's header for what rule 42
/// then does to it.
String findingFingerprint({
  required String ruleId,
  required Iterable<Uuid> targets,
}) {
  assert(ruleId.isNotEmpty, 'a fingerprint needs a rule to be about');
  // SORTED AND DE-DUPLICATED. Sorted so the pair is unordered; unique so
  // a rule that names one entity twice (both ends of a loopback, say)
  // does not fingerprint differently from one that names it once.
  final ids = <String>{for (final t in targets) t.v}.toList()..sort();
  // NUL-SEPARATED, so `['ab', 'c']` and `['a', 'bc']` cannot collide.
  // Uuid is opaque here and a separator that could appear inside one
  // would be a collision waiting for the first id that contained it.
  final digest = sha256.convert(utf8.encode(ids.join('\u0000')));
  final out =
      '$ruleId:${digest.toString().substring(0, kFingerprintHexLength)}';
  assert(
    out != kProjectWideFingerprint,
    'a real fingerprint must never equal the project-wide mute',
  );
  return out;
}

/// A tier-3 action the issues panel offers beside a finding.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE VALUE, AND `SpringBackRemedy`'s DOC COMMENT IS WHY
/// ═══════════════════════════════════════════════════════════════════════
/// That enum says inventing labels for rules nobody has asked about "would
/// be putting words in a designer's mouth and shipping them as though the
/// corpus had said them". The same restraint holds here, and the same
/// thing lifts it: the M5-H2 review asked for `PWR-003`, so `PWR-003` gets
/// one and the other twelve tier-3 rules do not.
///
/// `CODE-002` (`#840`) is expected to want the second value. That is the
/// reason this is an enum on `Finding` rather than a boolean or a
/// hard-wired button in the panel (DR-128 §11.127.5): a second bespoke
/// path is how one mechanism becomes three, which §5.3.20 records
/// happening to three unreachable models in one issue.
enum FindingRemedy {
  /// `PWR-003`: more things to plug in than places to plug them. Places
  /// the 24-outlet 0U vertical PDU the catalogue already ships.
  addRackPdu('Add a rack PDU');

  const FindingRemedy(this.label);

  /// What the panel's button reads.
  final String label;
}

/// One tier-2 or tier-3 DRC finding about this document.
///
/// Tier 1 does not produce these: it refuses the command and returns a
/// `ConnectRefused`, which is why `RuleMeta.defaultSeverity` is null for
/// all eight tier-1 rules. See `rule_catalogue.dart`.
final class Finding {
  const Finding({
    required this.ruleId,
    required this.severity,
    required this.message,
    required this.targets,
    this.primaryEntityId,
    this.remedy,
  });

  /// `'SIG-001'`. Joins to `RuleMeta`, `RuleOverride` and `AckedFinding`.
  final String ruleId;

  /// The severity AFTER any `ProjectSettings.ruleOverrides` has been
  /// applied, not `RuleMeta.defaultSeverity`. A finding carries what it
  /// IS in this project, so the issues list and the sheet cannot
  /// disagree with each other about the same row.
  final Severity severity;

  /// A COMPLETE SENTENCE about THIS document, ending in a full stop.
  ///
  /// `ConnectRefused` already rules this for tier 1 and the reason
  /// carries over: *"AVR-1 J03 already carries 1 of 1 connections"* is an
  /// explanation and `"TOP-003"` is a log line. The rule id is a separate
  /// field precisely so the message never has to carry it.
  final String message;

  /// Every entity this finding is about, by stable id. The fingerprint is
  /// computed from these and from nothing else.
  final List<Uuid> targets;

  /// The one entity the issues list should select and reveal, when there
  /// is an obvious one. Null is not a defect: a finding about a circuit's
  /// total draw is about a set, and `AckedFinding.targetEntityId` is
  /// nullable for the same reason.
  final Uuid? primaryEntityId;

  /// The action the panel offers beside this row, or null when there is
  /// nothing to offer.
  ///
  /// NULL IS THE NORMAL CASE and carries no information about the
  /// finding's importance: twelve of the thirteen tier-3 rules have no
  /// remedy because nobody has designed one, not because they are minor.
  ///
  /// IT IS DELIBERATELY OUTSIDE THE FINGERPRINT. `targetFingerprint` is
  /// computed from the rule id and the targets and from nothing else, so
  /// giving a rule a remedy later must not orphan every `AckedFinding`
  /// somebody has already written a reason on. A remedy is a thing the
  /// PRODUCT offers, not a fact about the defect.
  final FindingRemedy? remedy;

  /// The same finding, reported at [severity].
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS EXISTS BECAUSE THE FIELD-BY-FIELD COPY DROPPED A FIELD, TWICE
  /// ═══════════════════════════════════════════════════════════════════
  /// `evaluateDocument` rebuilds a finding to change its severity, once
  /// for the project's resolved value and once for an acknowledgement's
  /// demotion. Both were written out longhand, so **every new field on
  /// this class had to be remembered in two places or it silently
  /// vanished between the predicate and the panel.**
  ///
  /// It vanished. `remedy` was added at DR-128 §11.127.5 and neither copy
  /// carried it, so `PWR-003`'s button never reached the issues list. The
  /// defect was found by a test that ran `evaluateDocument` rather than
  /// the predicate, which is the same shape DR-125 §11.124.2 records for
  /// `RCK-003`'s discarded severity: **the entry point is where findings
  /// lose things, and a test that calls the predicate cannot see it.**
  ///
  /// So the copy is here, once, where adding a field to the constructor
  /// and forgetting it is a compile error rather than a quiet loss.
  Finding withSeverity(Severity severity) => Finding(
    ruleId: ruleId,
    severity: severity,
    message: message,
    targets: targets,
    primaryEntityId: primaryEntityId,
    remedy: remedy,
  );

  /// What an `AckedFinding` must carry to suppress THIS finding.
  String get targetFingerprint =>
      findingFingerprint(ruleId: ruleId, targets: targets);

  @override
  String toString() => '$ruleId (${severity.name}): $message';
}
