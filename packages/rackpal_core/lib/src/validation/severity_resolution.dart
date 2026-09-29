// What severity a finding actually carries (`#260`, M5-B3, CR-018,
// CR-019).
//
// ═══════════════════════════════════════════════════════════════════════
// THREE LAYERS, IN ONE ORDER, IN ONE PLACE
// ═══════════════════════════════════════════════════════════════════════
// A rule's severity in front of a person is the answer to three
// questions asked in sequence:
//
//   1. What does the catalogue say (`RuleMeta.defaultSeverity`)?
//   2. What has this project decided (`ProjectSettings.ruleOverrides`)?
//   3. What did somebody acknowledge (`AckedFinding.demotedTo`)?
//
// THE ORDER IS RULED HERE AND IT IS NOT ARBITRARY. An override is a DIAL:
// it says what this rule counts as in this project, and it can be moved
// back. An acknowledgement is a SIGNED ACT about a specific finding,
// carrying a sentence, an author and a date that print on `T0.02`. So the
// acknowledgement is applied last and wins: turning the dial back up to
// `error` must not quietly discard a written justification, because the
// person who wrote it would have no way of knowing it had stopped
// applying.
//
// ═══════════════════════════════════════════════════════════════════════
// THE WRITER IS STRICT AND THE READER IS TOLERANT, AGAIN
// ═══════════════════════════════════════════════════════════════════════
// docs/02 section 5.4 keeps *"forward-compat on unknown `ruleId`s"* as
// data on purpose. A file from a later build may carry an override for a
// rule this build has never heard of, and the codec preserves it (G4).
// [projectSeverity] then ignores it, because a rule this build does not
// implement cannot produce a finding for the override to apply to. That
// is the honest answer and not a silent drop: the entry survives the
// round trip and comes back to life in the build that knows the rule.
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/validation/finding.dart';
import 'package:rackpal_core/src/validation/rule_catalogue.dart';
import 'package:rackpal_core/src/validation/rule_exception.dart';

/// The severity [ruleId] carries in this project, before any
/// acknowledgement. This is the value a `Finding` is built with.
///
/// NULL IS INAPPLICABLE, NOT UNKNOWN (G4). It means this rule files no
/// finding at all: either it is tier 1, which refuses the command and has
/// nothing to be severe about, or it is not in the catalogue and so does
/// not exist here (CR-021). Both are answers, and neither is a missing
/// measurement.
Severity? projectSeverity(String ruleId, ProjectSettings settings) {
  final meta = kRulesById[ruleId];
  if (meta == null) return null;
  final base = meta.defaultSeverity;
  if (base == null) return null;
  return settings.ruleOverrides[ruleId]?.severity ?? base;
}

/// What [finding] actually carries once any acknowledgement of it has
/// been applied.
///
/// `Finding.severity` is already project-resolved by construction (see
/// its own doc comment), so this layer applies only step 3. Findings and
/// acknowledgements are joined by `acknowledgementFor`, never by a second
/// matching rule written out here: two implementations of the join is how
/// the issues list and the sheet come to disagree about the same row.
Severity effectiveSeverity(
  Finding finding,
  Iterable<AckedFinding> acknowledgements,
) =>
    acknowledgementFor(finding, acknowledgements)?.demotedTo ??
    finding.severity;
