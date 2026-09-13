// A signed exception to a shipped rule (`#259`, M5-B2, CR-019, RJ-006).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE MECHANISM, TWO SCOPES, AND THE SCOPE DECIDES WHETHER A REASON IS
// OWED
// ═══════════════════════════════════════════════════════════════════════
// CR-019 collapsed three proposed dismissal mechanisms into one:
// *"`AckedFinding`, at two scopes. `targetFingerprint == "*"` means
// project-wide mute of that rule."* RJ-006 then answers the
// first-session objection by splitting the reason requirement along that
// same seam: *"the reason field is required only for a project-wide
// mute; a single-instance acknowledgement takes one click and offers a
// reason field that may be left empty. The essay is only demanded where
// the consequence is permanent."*
//
// So this file holds the seam. `AckedFinding` itself cannot: it is a
// persisted entity and the codec has to be able to read whatever a
// hand-edited or future-version file contains (CR-117). The WRITER is
// strict and the READER is tolerant, which is the split that lets a
// stricter rule ship without making somebody's existing document
// unopenable.
//
// ═══════════════════════════════════════════════════════════════════════
// TIER 1 CANNOT BE ACKNOWLEDGED, AND THE CATALOGUE ALREADY SAYS SO
// ═══════════════════════════════════════════════════════════════════════
// `RuleMeta.defaultSeverity` is null for all eight tier-1 rules, because
// a tier-1 rule refuses the command and files no `Finding` (docs/02 §5's
// table: *"the command is rejected... None. There is nothing to escape
// to"*). An acknowledgement of `TOP-001` would therefore sit in the
// document forever, matching nothing, until rule 42 collected it. That
// is not a harmless no-op: it is a person believing they have silenced
// something.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/validation/finding.dart';
import 'package:rackpal_core/src/validation/rule_catalogue.dart';

/// Whether [reason] is a written justification rather than an empty box.
///
/// Trimmed-non-empty and nothing cleverer. This cannot tell a reason from
/// a keyboard mash, and a checker that tried would only teach people to
/// type a full stop. What it does catch is the case RJ-006 actually
/// names: a required field left blank, or holding a space.
bool isWrittenReason(String reason) => reason.trim().isNotEmpty;

/// What [evaluateAcknowledgement] and `evaluateRuleOverride` decided.
///
/// Sealed on `ConnectVerdict`'s precedent and for its stated reason: a
/// caller must handle both arms, so there is no `isAllowed` boolean to
/// check and forget and no way to read "allowed" out of a refusal by
/// ignoring it.
@immutable
sealed class RuleExceptionVerdict {
  const RuleExceptionVerdict();
}

/// The exception may stand.
@immutable
final class RuleExceptionAllowed extends RuleExceptionVerdict {
  const RuleExceptionAllowed();
}

/// The exception may not stand, and [message] says why in a sentence.
@immutable
final class RuleExceptionRefused extends RuleExceptionVerdict {
  const RuleExceptionRefused(this.message);

  /// A COMPLETE SENTENCE a person can read, on `ConnectRefused`'s
  /// contract: it names the rule and the actual problem, never a code.
  /// This one is shown beside a disabled button, so it has to be the
  /// whole explanation.
  final String message;

  @override
  String toString() => message;
}

/// Whether an acknowledgement of [ruleId] at [targetFingerprint] carrying
/// [reason] may be written.
///
/// The three ways it may not, in the order a person meets them:
/// the rule is not in the catalogue (CR-021), the rule is tier 1 and
/// files no finding to acknowledge, or the mute is project-wide and the
/// reason box is empty (RJ-006).
RuleExceptionVerdict evaluateAcknowledgement({
  required String ruleId,
  required String targetFingerprint,
  required String reason,
}) {
  final refusal = ruleAcceptsAnException(ruleId, 'acknowledged');
  if (refusal != null) return refusal;
  if (targetFingerprint == kProjectWideFingerprint &&
      !isWrittenReason(reason)) {
    return RuleExceptionRefused(
      'Muting $ruleId across the whole project needs a written reason, '
      'because it prints on sheet T0.02 for whoever reads the drawings.',
    );
  }
  return const RuleExceptionAllowed();
}

/// Whether a `RuleOverride` on [ruleId] carrying [reason] may be
/// written.
///
/// THE REASON IS ALWAYS REQUIRED HERE, WITH NO SCOPE TO SPLIT ON. RJ-006
/// lets a single-instance acknowledgement go unexplained because it is
/// one click about one cable and it can be taken back. An override is a
/// standing decision about a rule for the whole project, which is the
/// side of RJ-006's line where *"the essay is only demanded where the
/// consequence is permanent"* puts it. CR-019 says the same from the
/// other direction: the bare `Map<String, Severity>` was replaced
/// BECAUSE it *"has no field for the justification that two documents
/// promise will print"*, and an override with an empty reason is that
/// map again wearing a richer type.
RuleExceptionVerdict evaluateRuleOverride({
  required String ruleId,
  required String reason,
}) {
  final refusal = ruleAcceptsAnException(ruleId, 'overridden');
  if (refusal != null) return refusal;
  if (!isWrittenReason(reason)) {
    return RuleExceptionRefused(
      'Changing what $ruleId counts as needs a written reason, because it '
      'prints on sheet T0.02 for whoever reads the drawings.',
    );
  }
  return const RuleExceptionAllowed();
}

/// Every rule a person may write a standing decision about, in catalogue
/// order (`#879`).
///
/// **THE LIST IS A FACT ABOUT THE CATALOGUE, NOT ABOUT A WIDGET**, which
/// is why it lives here. It was a filter inside the project-settings
/// picker first, and a mutation that removed the filter SURVIVED: that
/// picker is a virtualised list, so a tier-1 row below the fold is never
/// built and `findsNothing` passes whether the rule was excluded or
/// merely out of sight. A test of this function cannot be fooled that
/// way, because it reads every rule in the catalogue.
List<RuleMeta> overridableRules() =>
    <RuleMeta>[
        for (final rule in kRulesById.values)
          if (ruleAcceptsAnException(rule.ruleId, 'overridden') == null) rule,
      ]
      // TOTAL ORDER, on `_FamilyColours`' reasoning: `List.sort` is not
      // stable, and a map's order is not a display order.
      ..sort((a, b) => a.ruleId.compareTo(b.ruleId));

/// The refusal shared by both kinds of exception, or null when [ruleId]
/// can carry one. [verb] completes the sentence: "acknowledged",
/// "overridden".
///
/// Not private, because `rule_severity.dart` asks the identical question
/// about a `RuleOverride` and two copies of a sentence are two sentences
/// that drift.
RuleExceptionRefused? ruleAcceptsAnException(String ruleId, String verb) {
  final meta = kRulesById[ruleId];
  if (meta == null) {
    return RuleExceptionRefused(
      '$ruleId is not a rule this version of RackPal knows, so there is '
      'nothing to be $verb.',
    );
  }
  if (meta.tier == RuleTier.modelIllegal) {
    return RuleExceptionRefused(
      '$ruleId refuses the edit outright and files no finding, so there '
      'is nothing to be $verb.',
    );
  }
  return null;
}

/// Whether [ack] speaks to [finding] at all.
///
/// THE RULE ID IS PART OF THE MATCH EVEN AT PROJECT SCOPE. `"*"` is a
/// project-wide mute *of that rule* (CR-019), not a mute of everything,
/// and an implementation that read the wildcard as "matches any finding"
/// would let one acknowledgement silence the entire catalogue.
bool acknowledges(AckedFinding ack, Finding finding) =>
    ack.ruleId == finding.ruleId &&
    (ack.targetFingerprint == kProjectWideFingerprint ||
        ack.targetFingerprint == finding.targetFingerprint);

/// The one acknowledgement that governs [finding], or null when none
/// does.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MORE SPECIFIC ACT WINS, AND THE TIE-BREAK IS TOTAL
/// ═══════════════════════════════════════════════════════════════════════
/// A person who muted `LEN-001` project-wide in March and then wrote a
/// paragraph about THIS run in September meant the paragraph. So an
/// instance acknowledgement outranks a project-wide one; among two of
/// equal scope the later `at` wins, because that is the opinion they
/// arrived at second.
///
/// The final tie-break is the id, and it is there for the reason every
/// comparator in this repository ends in one: `at` is a timestamp two
/// acknowledgements can share, and a comparison that stops at a value
/// two entries can hold makes the answer depend on map iteration order.
/// Which reason prints on `T0.02` is not a coin toss.
AckedFinding? acknowledgementFor(
  Finding finding,
  Iterable<AckedFinding> acknowledgements,
) {
  AckedFinding? best;
  for (final ack in acknowledgements) {
    if (!acknowledges(ack, finding)) continue;
    if (best == null || _outranks(ack, best)) best = ack;
  }
  return best;
}

bool _outranks(AckedFinding a, AckedFinding b) {
  final aIsInstance = a.targetFingerprint != kProjectWideFingerprint;
  final bIsInstance = b.targetFingerprint != kProjectWideFingerprint;
  if (aIsInstance != bIsInstance) return aIsInstance;
  final byTime = a.at.compareTo(b.at);
  if (byTime != 0) return byTime > 0;
  return a.id.v.compareTo(b.id.v) > 0;
}
