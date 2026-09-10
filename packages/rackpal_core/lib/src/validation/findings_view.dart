// The issues list's shape: grouped, filtered, ordered (`#294`, M5-F1).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS IN CORE AND NOT IN THE PANEL
// ═══════════════════════════════════════════════════════════════════════
// Grouping looks like presentation, and one of these three consumers is
// a widget. The other two are not: sheet `T0.02 — Exceptions &
// Acknowledgements` prints open findings and acknowledgements (docs/05
// §8, CR-022), and a rollup chip on a device header counts them
// (docs/05 §8's "⚠/⛔ roll-up chip"). Three surfaces that disagreed
// about which findings belong together, or in what order, would be three
// answers to a question the document has exactly one of.
//
// It is also the half worth testing. A grouping function is checked by
// calling it; the same logic inside a `build` needs a pumped widget and
// a finder, and this repository has already learned what a finder that
// cannot say WHICH row it found is worth.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ACKNOWLEDGEMENT JOIN IS BORROWED, NEVER REWRITTEN
// ═══════════════════════════════════════════════════════════════════════
// `evaluateDocument` returns findings with an acknowledgement's demotion
// ALREADY APPLIED, and drops nothing else, so by the time a finding
// reaches this file the fact that it was acknowledged is no longer
// visible in it. The list needs that fact anyway: docs/05 §8 renders an
// acknowledged badge hollow and puts the reason in the tooltip.
//
// So the join is re-run here, through `acknowledgementFor` and through
// nothing else. That function's own comment says why: *"two
// implementations of the join is how the issues list and the sheet come
// to disagree about the same row"*, and the project-wide `"*"` mute is
// exactly the case a second, hand-written matcher would get wrong.
//
// ═══════════════════════════════════════════════════════════════════════
// FIVE LOCUS TYPES, AND THE FIFTH ARRIVED EXACTLY AS PREDICTED
// ═══════════════════════════════════════════════════════════════════════
// `Finding.primaryEntityId` is nullable and could in principle name any
// entity. For the DRC catalogue it is set from exactly four: `Link`,
// `Rack`, `DeviceInstance` and `Circuit`. All four carry a `designator`,
// which is why [locusLabel] can be short and total rather than a
// twelve-arm switch over types no rule produces.
//
// **THE PARAGRAPH BELOW USED TO SAY A FIFTH TYPE WOULD BE A TEST
// FAILURE, AND WHEN ONE ARRIVED NOTHING FAILED** (DR-154 §11.153.8).
// `PLAN-I/1` shipped four `PLN-*` rules whose primary is a
// `PlanUnderlay`, and every one of them grouped under [kNoLocusGroup]:
// the panel told a person that the most locatable object in the document
// had no location. The guard that was supposed to catch it asserted
// `locusLabel` returns null for a hand-written stranger id, which is a
// statement about an id no rule produces and cannot see a fifth type that
// rules DO produce.
//
// So the census is now taken over the corpus, where every rule's
// known-bad already runs: `drc_fixture.dart` reports the locus of every
// finding a fixture produces and `violationOf` fails on a null. A sixth
// type is a test failure for real this time, because the thing that fails
// is a run of the actual rules rather than a sentence about them.
//
// AN UNDERLAY CARRIES A `name` AND NOT A `designator`, and that is not an
// inconsistency to paper over: a plan is a drawing of the building, not a
// piece of equipment in it, so `RK-1` has a designator and `Level 1` has
// the name that prints on its own sheet (docs/15 §8).
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/validation/finding.dart';
import 'package:rackpal_core/src/validation/rule_exception.dart';

/// How the issues list is grouped. All three are ruled by `#294`: "by
/// severity, by rule, by locus".
enum FindingGrouping { severity, rule, locus }

/// The group header a finding with no [Finding.primaryEntityId] lands
/// under.
///
/// NOT `kUnknownCell`'s dash. A finding about a circuit's total draw is
/// about a SET, and its null locus is inapplicability rather than an
/// unmeasured value (G4/CR-114 governs measurements). The words say
/// which, so a reader does not read a dash here as "nobody has looked".
const String kNoLocusGroup = 'No single location';

/// One row of the issues list: a finding, and the acknowledgement that
/// applies to it if there is one.
final class FindingRow {
  const FindingRow({required this.finding, this.acknowledgement});

  final Finding finding;

  /// The acknowledgement covering [finding], instance-scoped or the
  /// project-wide `"*"` mute. Null means the finding is unacknowledged.
  final AckedFinding? acknowledgement;

  /// Whether docs/05 §8's hollow badge and reason tooltip apply.
  bool get isAcknowledged => acknowledgement != null;

  /// The reason to show, or null when there is nothing to show.
  ///
  /// An instance acknowledgement's reason is OPTIONAL (RJ-006), so an
  /// acknowledged row with an empty reason is a legal state and reads as
  /// "acknowledged, no reason given" rather than as a missing value.
  String? get reason {
    final r = acknowledgement?.reason;
    return (r == null || r.isEmpty) ? null : r;
  }
}

/// A run of rows under one header.
final class FindingGroup {
  const FindingGroup({
    required this.key,
    required this.label,
    required this.rows,
  });

  /// The stable sort key. Never shown; [label] is what a person reads.
  final String key;

  /// The header text.
  final String label;

  final List<FindingRow> rows;

  int get length => rows.length;

  /// How many rows in this group carry an acknowledgement, for a header
  /// that can say "3 of 7 acknowledged" without the panel recounting.
  int get acknowledgedCount => rows.where((r) => r.isAcknowledged).length;
}

/// What the locus column prints for [id], or null when [id] names
/// something no rule is known to point at.
///
/// Returning NULL rather than a placeholder is deliberate: see this
/// file's header. The caller decides whether that is a test failure or a
/// fallback, and `findings_view_test.dart` decides it is a failure.
String? locusLabel(RackDocument doc, Uuid id) {
  final link = doc.links[id];
  if (link != null) return link.designator;
  final rack = doc.racks[id];
  if (rack != null) return rack.designator;
  final device = doc.devices[id];
  if (device != null) return device.designator;
  final circuit = doc.circuits[id];
  if (circuit != null) return circuit.designator;
  // THE FIFTH AND SIXTH, BOTH FOUND BY ONE CENSUS (DR-154 §11.153.8).
  //
  // `ELE-005` has pointed at a `Net` since `#838` and `PLN-001..004` at a
  // `PlanUnderlay` since `PLAN-I/1`, and neither had an arm here: two
  // rules' findings and four more went to "no location" while the header
  // above promised a fifth type would fail loudly.
  //
  // A NET PREFERS ITS DESIGNATOR AND FALLS BACK TO ITS NAME, which is
  // what `ELE-005`'s own message does. A group header that said `Net 12`
  // over a row reading `SPK-A carries 260 W` would be two names for one
  // thing on one screen.
  final net = doc.nets[id];
  if (net != null) return net.designator ?? net.name;
  // An underlay has no designator at all: it is a drawing of the
  // building rather than equipment in it, and its name is what `T1.01`'s
  // title block prints (docs/15 §8).
  final underlay = doc.underlays[id];
  if (underlay != null) return underlay.name;
  return null;
}

/// The issues list, grouped by [by] and filtered.
///
/// [findings] is what `evaluateDocument` returned: already
/// project-resolved, already demoted, already free of `off`, and already
/// in a total order. NOTHING HERE RE-SORTS THE ROWS WITHIN A GROUP. That
/// order is the document's answer and a second sort would be a second
/// opinion about it.
///
/// [severities] and [ruleIds], when non-null, keep only rows matching
/// them. An EMPTY set keeps nothing, which is what an unticked filter
/// means; null means the filter is not applied at all. Those are
/// different states and a panel that conflated them would show
/// everything when a person had deselected everything.
///
/// [includeAcknowledged] false drops rows an acknowledgement covers.
/// They are still findings and still print on `T0.02` (CR-022); this is
/// a view filter and never a suppression.
List<FindingGroup> groupFindings(
  RackDocument doc,
  List<Finding> findings, {
  required FindingGrouping by,
  Set<Severity>? severities,
  Set<String>? ruleIds,
  bool includeAcknowledged = true,
}) {
  final acks = doc.ackedFindings.values;
  final rows = <FindingRow>[];
  for (final f in findings) {
    if (severities != null && !severities.contains(f.severity)) continue;
    if (ruleIds != null && !ruleIds.contains(f.ruleId)) continue;
    final ack = acknowledgementFor(f, acks);
    if (ack != null && !includeAcknowledged) continue;
    rows.add(FindingRow(finding: f, acknowledgement: ack));
  }

  // Keys are built so that a plain string sort gives the order each
  // grouping is meant to have. Severity is the one that would sort
  // WRONG alphabetically (advisory before error before warning, which
  // is neither the enum's order nor a useful one), so its key carries
  // the enum index and the name is only there to keep the key readable
  // in a failing test's diff.
  final groups = <String, List<FindingRow>>{};
  final labels = <String, String>{};
  for (final row in rows) {
    final String key;
    final String label;
    switch (by) {
      case FindingGrouping.severity:
        final s = row.finding.severity;
        key = '${s.index}:${s.name}';
        label = s.name;
      case FindingGrouping.rule:
        key = row.finding.ruleId;
        label = row.finding.ruleId;
      case FindingGrouping.locus:
        final id = row.finding.primaryEntityId;
        // A null locus sorts LAST, under `~`, which is above every
        // character a designator can contain. The alternative, sorting
        // it first, would put the least specific group at the top of a
        // list whose whole purpose is to be navigated.
        final resolved = id == null ? null : locusLabel(doc, id);
        key = resolved == null ? '~' : '$resolved:${id!.v}';
        label = resolved ?? kNoLocusGroup;
    }
    (groups[key] ??= <FindingRow>[]).add(row);
    labels[key] = label;
  }

  final keys = groups.keys.toList()..sort();
  return [
    for (final k in keys)
      FindingGroup(key: k, label: labels[k]!, rows: groups[k]!),
  ];
}
