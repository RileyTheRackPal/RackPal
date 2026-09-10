// The plan advisories: `PLN-001` to `PLN-004` (docs/15 §9, DR-154
// §11.153, `PLAN-I/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// A SECOND BAND, NOT FOUR MORE ROWS
// ═══════════════════════════════════════════════════════════════════════
// docs/02 §5 is the v1 DRC catalogue: the one AC-040 sized, AC-051 gates
// and `rule_catalogue.dart` carries. These four are not in it and must
// not be counted as if they were, so they live in [kPlanRules] and are
// bound to **docs/15 §9** by a test that parses that table exactly as
// `rule_catalogue_test.dart` parses docs/02 §5.
//
// CR-021's *"a rule not listed there does not exist"* is about a specific
// there, and each band has one.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BAND IS SEPARATE. THE MACHINERY IS NOT
// ═══════════════════════════════════════════════════════════════════════
// `evaluateDocument` runs these through the same three steps in the same
// order: the project's override, then `off`, then the acknowledgement.
// `drc.dart`'s header says why there is no second path, and CR-019 says
// the same about the mute: **one** `AckedFinding` mechanism, not a
// per-rule opt-out and not a second one for a new band.
//
// ═══════════════════════════════════════════════════════════════════════
// EACH RULE STATES ITS COUNT (G4)
// ═══════════════════════════════════════════════════════════════════════
// *"N pins carry no measurable position"*, *"N devices in Level 1 are not
// on the plan"*. A rule that fires without saying how much has told
// somebody there is a problem and left them to count it themselves.
//
// `PLN-001`'s sentence is NOT WRITTEN HERE. `unmeasurablePinsSentence`
// was built at `PLAN-F/3` and DR-146 §11.145.6 put it in core *"precisely
// so surfaces cannot drift"*; the underlay row and this rule say the same
// words because they call the same function.
//
// ═══════════════════════════════════════════════════════════════════════
// AND `PLN-004` CANNOT BE A `DrcRule`, WHICH IS A FACT ABOUT WHERE BYTES
// LIVE
// ═══════════════════════════════════════════════════════════════════════
// A `DrcRule` is `List<Finding> Function(RackDocument)`. A content-hash
// mismatch is a statement about the CONTAINER MEMBER, and `RackDocument`
// holds no bytes: `PlanUnderlay.imageMember` is a path, because core is
// decoder-free and the members ride on the session (`DR-019`, PLAN-B).
//
// So the comparison happens where the bytes are, ONCE, and the result is
// handed in. `persistence/plan_hash.dart` is the comparator, in core so
// there is one description of the algorithm, and the app runs it over its
// members at load. **A hash recomputed inside `evaluateDocument` would be
// a sha256 over every underlay on every widget build**, since
// `rack_canvas_screen.dart` recomputes findings in `build`.
import 'package:rackpal_core/src/derived/plan_measurability.dart';
import 'package:rackpal_core/src/derived/unpinned_carriers.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// `PLN-001`: an underlay is uncalibrated.
///
/// One finding per uncalibrated underlay, and **only when something is
/// stranded by it**. A plan with no pins on it is not carrying anything
/// that a calibration would rescue, and a finding about it would be an
/// advisory to do work nothing is waiting for.
List<Finding> rulePln001(RackDocument doc) {
  final out = <Finding>[];
  for (final underlay in doc.underlays.values) {
    final m = planMeasurabilityOf(doc, underlay);
    if (m.isCalibrated) continue;
    final sentence = unmeasurablePinsSentence(m);
    if (sentence == null) continue;
    out.add(
      Finding(
        ruleId: 'PLN-001',
        severity: Severity.advisory,
        // THE WORDS ARE `PLAN-F/3`'s, WRAPPED RATHER THAN REWRITTEN.
        // DR-146 §11.145.6 put that sentence in core so the underlay row
        // and this advisory cannot drift into two spellings of one fact.
        message: '${underlay.name} is not calibrated: $sentence.',
        targets: [underlay.id],
        primaryEntityId: underlay.id,
      ),
    );
  }
  return out;
}

/// `PLN-002`: carriers on this plan's floor that are not on it.
///
/// **THE SAME POPULATION THE UNPINNED STRIP LISTS** (DR-154 §11.153.7a),
/// which is the point rather than an implementation convenience: the
/// strip is where a person goes to fix this, and a count that disagreed
/// with the list it sends them to is two answers to one question.
List<Finding> rulePln002(RackDocument doc) {
  final out = <Finding>[];
  for (final underlay in doc.underlays.values) {
    final unpinned = unpinnedCarriersFor(doc, underlay);
    if (unpinned.count == 0) continue;
    final n = unpinned.count;
    out.add(
      Finding(
        ruleId: 'PLN-002',
        severity: Severity.advisory,
        message: n == 1
            ? '1 device on ${underlay.name} is not on the plan.'
            : '$n devices on ${underlay.name} are not on the plan.',
        // THE CARRIERS, NOT THE UNDERLAY, so revealing the finding can
        // take somebody to the things rather than to the picture.
        targets: [underlay.id, for (final row in unpinned.rows) row.entityId],
        primaryEntityId: underlay.id,
      ),
    );
  }
  return out;
}

/// `PLN-003`: pinned drops and no pinned rack.
///
/// Fires whether or not the plan is calibrated, because the missing datum
/// is the fact: a calibration on a plan with no rack still derives
/// nothing, and telling somebody to calibrate first would be advice that
/// leads nowhere.
List<Finding> rulePln003(RackDocument doc) {
  final out = <Finding>[];
  for (final underlay in doc.underlays.values) {
    final m = planMeasurabilityOf(doc, underlay);
    if (m.rackPinned) continue;
    if (m.subjectPinCount == 0) continue;
    final n = m.subjectPinCount;
    out.add(
      Finding(
        ruleId: 'PLN-003',
        severity: Severity.advisory,
        message: n == 1
            ? '${underlay.name} has 1 pinned drop and no pinned rack, so no '
                  'run length derives from it.'
            : '${underlay.name} has $n pinned drops and no pinned rack, so no '
                  'run length derives from it.',
        targets: [underlay.id],
        primaryEntityId: underlay.id,
      ),
    );
  }
  return out;
}

/// `PLN-004`: the stored bytes are not the ones the hash was taken over.
///
/// [changed] is what the caller found, because the bytes are not in the
/// document: see this file's header. An EMPTY set means nobody has
/// checked as often as it means nothing changed, and the two are not
/// distinguished here on purpose. `evaluateDocument`'s parameter carries
/// that caveat, and `app_shell.dart` is the caller that always supplies
/// it.
List<Finding> rulePln004(RackDocument doc, Set<Uuid> changed) {
  final out = <Finding>[];
  for (final underlay in doc.underlays.values) {
    if (!changed.contains(underlay.id)) continue;
    out.add(
      Finding(
        ruleId: 'PLN-004',
        severity: Severity.warning,
        message:
            '${underlay.name} has changed since it was imported, so its '
            'pins and its calibration may no longer line up with it.',
        targets: [underlay.id],
        primaryEntityId: underlay.id,
      ),
    );
  }
  return out;
}
