// The tier-3 evaluator: every post-hoc rule, run over one document.
//
// ═════════════════════════════════════════════════════════════════════
// THE SIGNATURE THE CATALOGUE ALREADY RULED
// ═════════════════════════════════════════════════════════════════════
// `rule_catalogue.dart`'s header: *"a tier-3 rule reads the whole
// document and returns many findings. A single `List<Finding>
// Function(RackDocument)` would be clean for the fourteen post-hoc rules
// and would make the six spring-back rules unimplementable."* So that is
// the shape here, and it is the reason this file exists separately from
// the tier-1 and tier-2 evaluators rather than trying to unify with them.
//
// ═════════════════════════════════════════════════════════════════════
// A PREDICATE RETURNS FACTS. THIS FILE DECIDES WHAT THEY ARE WORTH
// ═════════════════════════════════════════════════════════════════════
// A rule says "these two devices overlap"; whether that is an `error`, a
// `warning` or nothing at all is a PROJECT decision, and M5-B built the
// machinery for it. So a predicate here returns a finding carrying its
// CATALOGUE severity and [evaluateDocument] resolves it:
//
//  1. `projectSeverity` applies `ProjectSettings.ruleOverrides`, so a
//     project that demoted `RCK-003` to advisory gets advisories.
//  2. `Severity.off` drops the finding entirely, which is what "off"
//     means and the only place it can be honoured without every
//     predicate re-implementing it.
//  3. `acknowledgementFor` demotes what a person has acknowledged
//     (CR-019), by the fingerprint `Finding.targetFingerprint` computes.
//
// A predicate that resolved its own severity would be a second copy of
// that order, and the three steps have to happen in exactly this one:
// acknowledging a finding you already turned off is not a thing, and
// demoting before overriding would let an override resurrect it.
//
// ═════════════════════════════════════════════════════════════════════
// THE ORDER OF THE OUTPUT IS PART OF THE CONTRACT
// ═════════════════════════════════════════════════════════════════════
// `Determinism` (CLAUDE.md): same document, same list. The issues list is
// a surface people scroll and compare between runs, and `List.sort` in
// Dart is NOT stable, so the comparator ends on a unique key. Findings
// sort by rule id and then by fingerprint, which is derived from the
// target ids and is therefore total.
//
// NOT BY SEVERITY, deliberately. Severity is a per-project setting, so
// sorting by it would reorder the whole list when somebody demotes one
// rule, and a reader comparing two runs would see churn that means
// nothing. The surface can group by severity; the EVALUATOR emits a
// stable order.

import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/validation/finding.dart';
import 'package:rackpal_core/src/validation/rule_catalogue.dart';
import 'package:rackpal_core/src/validation/rules_audio.dart';
import 'package:rackpal_core/src/validation/rules_cable.dart';
import 'package:rackpal_core/src/validation/rules_code.dart';
import 'package:rackpal_core/src/validation/rules_power.dart';
import 'package:rackpal_core/src/validation/rules_rack.dart';
import 'package:rackpal_core/src/validation/severity_resolution.dart';

/// One tier-3 rule: the whole document in, its findings out.
///
/// A predicate returns findings carrying the rule's CATALOGUE severity.
/// It never reads `ProjectSettings.ruleOverrides` and never consults an
/// acknowledgement: see the file header for why that order lives in one
/// place.
typedef DrcRule = List<Finding> Function(RackDocument doc);

/// Every tier-3 rule, by id.
///
/// KEYED BY ID AND CHECKED AGAINST THE CATALOGUE, because `rules.md` does
/// not exist and CR-021 says *"a rule not listed there does not exist"*.
/// `drc_test.dart` asserts this map's keys are exactly the catalogue's
/// `RuleTier.postHoc` ids, so a rule built without a row fails and a row
/// with no rule fails too. **The second direction is the one that
/// matters**: fourteen rows and thirteen predicates ships a catalogue
/// that lies about what the product checks.
const Map<String, DrcRule> kDrcRules = <String, DrcRule>{
  'CODE-001': ruleCode001,
  'CODE-002': ruleCode002,
  'ELE-003': ruleEle003,
  'ELE-005': ruleEle005,
  'LEN-001': ruleLen001,
  'LEN-002': ruleLen002,
  'LNK-020': ruleLnk020,
  'NET-001': ruleNet001,
  'PWR-001': rulePwr001,
  'PWR-003': rulePwr003,
  'RCK-001': ruleRck001,
  'RCK-002': ruleRck002,
  'RCK-003': ruleRck003,
  'RCK-012': ruleRck012,
  'RCK-013': ruleRck013,
};

/// Every finding this document carries, severity resolved and
/// acknowledgements applied, in a deterministic order.
///
/// [only] restricts the run to one rule, for a test or for a surface
/// re-checking a single row. Null runs all of them, which is the case
/// the issues list uses.
List<Finding> evaluateDocument(RackDocument doc, {String? only}) {
  final out = <Finding>[];
  for (final entry in kDrcRules.entries) {
    if (only != null && entry.key != only) continue;
    for (final raw in entry.value(doc)) {
      // STEP 1 — the project's own severity for this rule.
      //
      // `projectSeverity` returns null when the rule has no catalogue
      // severity, which is true of every tier-1 rule and of nothing
      // here. A null would mean a predicate produced a finding for a
      // rule the catalogue says cannot produce one, so it is DROPPED
      // rather than defaulted: defaulting would invent a severity, and
      // G4 forbids inventing a value to avoid an absent one.
      final resolved = projectSeverity(raw.ruleId, doc.settings);
      if (resolved == null) continue;

      // STEP 2 — `off` means off, and this is the one place it is
      // honoured. A predicate that checked it would be a second copy,
      // and one that forgot would leak a suppressed rule onto a sheet.
      if (resolved == Severity.off) continue;

      // STEP 2b — A BANDED RULE REPORTS ITS OWN SEVERITY, AND ONLY A
      // BANDED ONE MAY (DR-125 §11.124.2).
      //
      // The default above is right for every other rule and was ruled so:
      // M5-E overwrote `LEN-001`'s self-chosen `advisory` because that
      // argument *"is not in the catalogue"*, and a predicate picking a
      // severity the catalogue did not authorise is inventing a rule
      // (CR-021).
      //
      // `RCK-003` is the case where the row itself authorises three, and
      // until this existed the `advisory` its predicate had been setting
      // since M5-E reached nobody at all.
      //
      // AN OVERRIDE COLLAPSES THE BAND. If the project has set one, it is
      // the project saying what this rule counts as here, and every band
      // becomes that value: `rules_rack.dart` already promised that a
      // project demoting `RCK-003` demotes all three.
      final band = kRulesById[raw.ruleId]?.severityBand;
      final overridden = doc.settings.ruleOverrides.containsKey(raw.ruleId);
      final severity =
          (band != null && !overridden && band.contains(raw.severity))
          ? raw.severity
          : resolved;

      // `withSeverity`, NOT A LONGHAND COPY. Both reconstructions here
      // used to spell out every field, and `Finding.remedy` was added
      // without either of them learning about it, so `PWR-003`'s button
      // never reached the panel. See that method's doc comment.
      final finding = raw.withSeverity(severity);

      // STEP 3 — an acknowledgement demotes, it does not delete (CR-019).
      // `effectiveSeverity` reads the ack's `demotedTo`, and a demotion
      // to `off` disappears here for step 2's reason rather than being
      // special-cased again.
      final after = effectiveSeverity(finding, doc.ackedFindings.values);
      if (after == Severity.off) continue;
      out.add(
        after == finding.severity ? finding : finding.withSeverity(after),
      );
    }
  }

  // TOTAL, ENDING ON A UNIQUE KEY. `List.sort` is not stable in Dart, so
  // a comparator that could return 0 for two different findings would
  // give a different order on a different run over the same document.
  // The fingerprint is derived from the rule id and the target ids, so
  // two findings that tie on it really are the same finding.
  out.sort((a, b) {
    final byRule = a.ruleId.compareTo(b.ruleId);
    if (byRule != 0) return byRule;
    return a.targetFingerprint.compareTo(b.targetFingerprint);
  });
  return List<Finding>.unmodifiable(out);
}
