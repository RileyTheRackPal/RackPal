// The v1 DRC rule catalogue, as data (`#253`, `#254`, M5-A).
//
// ═══════════════════════════════════════════════════════════════════════
// METADATA IS DATA. THE PREDICATE IS CODE. THAT SPLIT IS THE WHOLE FILE
// ═══════════════════════════════════════════════════════════════════════
// AC-011 withdraws the claim that a user can author validation rules, and
// critique C10/D8 give the reason: a `RulePredicate` evaluated as an AST
// would make this app an interpreter for untrusted input. So a rule's id,
// tier, default severity and governing ruling live here as rows, and its
// predicate lives in Dart beside the thing it reasons about.
//
// THE 28 RULES DO NOT SHARE A SIGNATURE, and no amount of wishing makes
// them. A tier-1 connect rule answers about a gesture that has not
// happened yet and needs `(doc, from, to, ontoLink, freeing)`; `PLC-001`
// answers about a placement; a tier-3 rule reads the whole document and
// returns many findings. A single `List<Finding> Function(RackDocument)`
// would be clean for the fourteen post-hoc rules and would make the six
// spring-back rules unimplementable, which is why this file carries rows
// and a tier rather than function pointers.
//
// ═══════════════════════════════════════════════════════════════════════
// docs/02 §5 IS THE CATALOGUE, AND A TEST HOLDS THIS FILE TO IT
// ═══════════════════════════════════════════════════════════════════════
// CR-021: *"a rule not listed there does not exist"*. The corpus refers to
// a `docs/rules.md` and that file is deliberately never created. So
// `rule_catalogue_test.dart` PARSES docs/02 §5.1, §5.2 and §5.3 and
// asserts the ids here are exactly the ids there, tier by tier. Adding a
// row without adding it to the catalogue fails, and so does the reverse.
// A second copy of a list is a liability unless something compares them.
//
// FIVE OF THE EIGHT TIER-1 RULES WERE ALREADY BUILT when this landed:
// `TOP-001`..`TOP-005` in `derived/connect_rules.dart`, with rule ids,
// sentences and an evaluation order its enum encodes. This file does not
// rewrite them. It carries their rows and a test binds the two, which is
// the arrangement that keeps working code working and still fails when
// the two drift.
import 'package:rackpal_core/src/model/enums.dart' show Severity;

/// docs/02 §5's three tiers, in the frame CR-017 sets: *"the gesture may
/// hesitate. The document may not lie."*
enum RuleTier {
  /// States in which the document *means nothing*. The command is
  /// rejected and there is no escape, because there is nothing to escape
  /// to. These are the only rules that may prevent an edit.
  modelIllegal('T1'),

  /// Physically or electrically wrong and known at drag time. The wire
  /// springs back with a reason chip, remedy actions and
  /// `[ Connect anyway ]`, which files the tier-3 finding instead.
  springBack('T2'),

  /// Everything else, including anything unevaluatable at drag time. A
  /// `Finding` in the issues list, acknowledgeable with a reason that
  /// prints on sheet `T0.02`.
  postHoc('T3');

  const RuleTier(this.label);

  /// `'T1'`. What docs/02 §5's tier table calls it.
  final String label;
}

/// One row of docs/02 §5: everything about a rule that is not its code.
final class RuleMeta {
  const RuleMeta({
    required this.ruleId,
    required this.tier,
    required this.summary,
    required this.governing,
    this.defaultSeverity,
  });

  /// `'TOP-003'`. The join to `Finding.ruleId`, to `RuleOverride` and to
  /// `AckedFinding`, and the reason canon §12.6(b) ratifies `PLC-001..003`
  /// as numbered rules: an unnumbered blocking rule can carry neither.
  final String ruleId;

  final RuleTier tier;

  /// One line, in the catalogue's own words. Not the message a person
  /// sees: `ConnectRefused` already rules that a refusal carries a
  /// COMPLETE SENTENCE naming the real designators, and a generic summary
  /// is exactly what that forbids.
  final String summary;

  /// The ruling ids this rule answers to, e.g. `['CR-017', 'AC-018']`.
  /// §8.2's citation, carried by the rule rather than by a comment.
  final List<String> governing;

  /// The severity a finding is filed at before any `RuleOverride`.
  ///
  /// NULL FOR EVERY TIER-1 RULE, and that null is structural rather than
  /// unknown (G4/CR-114 is about measurements, and this is a fact about
  /// the tier). A T1 rule refuses the command; it never files a finding,
  /// so there is nothing for a severity to describe. `severityIsTiered`
  /// in the test holds the correspondence in both directions.
  final Severity? defaultSeverity;

  @override
  String toString() => '$ruleId (${tier.label})';
}

/// docs/02 §5.1: eight tier-1 rules, model-level illegality.
///
/// `TOP-001`..`TOP-005` are implemented in `derived/connect_rules.dart`.
/// **`PLC-001`..`PLC-003` are not implemented anywhere**, which a census
/// at the start of M5 established rather than assumed: the string
/// `PLC-00` appears in no Dart file in this repository, and there is no
/// placement-validity helper for the geometry code to call. They are
/// rows here and unbuilt predicates, which is the honest state.
const List<RuleMeta> kTier1Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'TOP-001',
    tier: RuleTier.modelIllegal,
    summary: 'A conductor may not connect a port to itself.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-002',
    tier: RuleTier.modelIllegal,
    summary:
        'Two conductors may not duplicate the same ordered port pair on '
        'the same link.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-003',
    tier: RuleTier.modelIllegal,
    summary:
        "A port's live conductor count may not exceed its effective "
        'maxConnections.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'TOP-004',
    tier: RuleTier.modelIllegal,
    summary:
        'Every endpoint must resolve: a PortEndpoint to an existing, '
        'non-tombstoned port.',
    governing: ['CR-017', 'AC-018'],
  ),
  RuleMeta(
    ruleId: 'TOP-005',
    tier: RuleTier.modelIllegal,
    summary:
        "A shelf-hosted device's hostDeviceId must resolve to a container "
        'and must not create a containment cycle.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'PLC-001',
    tier: RuleTier.modelIllegal,
    summary:
        'RailPlacement.ruIndex lies in [1, rack.heightU] and the device '
        'fits within the rack extent on that face.',
    governing: ['CR-017'],
  ),
  RuleMeta(
    ruleId: 'PLC-002',
    tier: RuleTier.modelIllegal,
    summary:
        'startTwelfth in [0,11], spanTwelfths in [1,12], and '
        'startTwelfth + spanTwelfths at most 12.',
    governing: ['CR-030'],
  ),
  RuleMeta(
    ruleId: 'PLC-003',
    tier: RuleTier.modelIllegal,
    summary:
        'ZeroUPlacement.channelId resolves in rack.zeroUChannels and the '
        'offset lies within the channel.',
    governing: ['CR-031'],
  ),
];

/// docs/02 §5.2: six tier-2 rules, gesture-level spring-back.
///
/// Every one of these also exists as a tier-3 finding once the user takes
/// `[ Connect anyway ]`, which is why each carries a default severity
/// despite refusing nothing: the severity is what the FILED finding gets.
const List<RuleMeta> kTier2Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'SIG-001',
    tier: RuleTier.springBack,
    summary:
        'HDBaseT port connected to a net.ethernet switch port. The '
        'flagship rule: PoH into a switch port.',
    governing: ['CR-017'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'SIG-002',
    tier: RuleTier.springBack,
    summary:
        "The sink's acceptedFamilies excludes the service's signalFamily, "
        'and no InlineAdapter is declared.',
    governing: ['CR-017'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'DIR-001',
    tier: RuleTier.springBack,
    summary:
        'source to source, or sink to sink. Exceptions: both ports '
        'declare returnChannel (eARC), or the net is passiveSplit.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'DIR-003',
    tier: RuleTier.springBack,
    summary:
        'IR emitter output plugged into an IR receiver jack. Damages '
        'hardware; PortDef.pinoutVariant exists solely to detect it.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'CON-001',
    tier: RuleTier.springBack,
    summary:
        'Connector types do not mate and no InlineAdapter is declared. '
        'Satisfied by data: declaring the adapter clears it.',
    governing: ['CR-015'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'ELE-006',
    tier: RuleTier.springBack,
    summary:
        'Constant-voltage speaker on a low-Z amplifier output, or the '
        'reverse.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
];

/// docs/02 §5.3: fourteen tier-3 rules, the post-hoc findings.
///
/// **v1 ships this set and no more** (AC-040 as amended by DR-020). The
/// count is the scope gate: roadmap M5's own risk list names *"just one
/// more obvious rule"* without its fixture pair as the mechanism by which
/// this milestone overruns, so `rule_catalogue_test.dart` fails when the
/// size changes and makes any addition a deliberate, visible act.
const List<RuleMeta> kTier3Rules = <RuleMeta>[
  RuleMeta(
    ruleId: 'ELE-003',
    tier: RuleTier.postHoc,
    summary:
        'Speaker polarity inverted between the two ends of a conductor '
        'pair.',
    governing: ['AC-030'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'NET-001',
    tier: RuleTier.postHoc,
    summary:
        'Sum of PD class draw on a switch exceeds '
        'PowerProfile.poeBudgetWatts.',
    governing: ['CR-056'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'PWR-001',
    tier: RuleTier.postHoc,
    summary:
        'Continuous amps on a circuit exceed 80% of the breaker, on '
        'typical times diversity, in VA. A planning estimate and not a '
        'compliance check.',
    governing: ['CR-020', 'AC-020', 'DR-079'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'PWR-003',
    tier: RuleTier.postHoc,
    summary: 'Outlets consumed exceed outlets provided in the rack.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'LEN-001',
    tier: RuleTier.postHoc,
    summary:
        'Ethernet channel over 100 m. A null length emits "length '
        'unknown, cannot verify" rather than passing silently.',
    governing: ['AC-024'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'LEN-002',
    tier: RuleTier.postHoc,
    summary:
        "A run's known length exceeds MediaTypeDef.maxRunLengthPassive. "
        'Generic by construction: one rule reading the registry, not one '
        'rule per medium.',
    governing: ['DR-020'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'RCK-001',
    tier: RuleTier.postHoc,
    summary: 'RU overlap on the same face.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-002',
    tier: RuleTier.postHoc,
    summary: 'Device extends past heightU.',
    governing: ['AC-040'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-003',
    tier: RuleTier.postHoc,
    summary:
        'Sum of device weight exceeds Rack.weightCapacity. Advisory at '
        '85%.',
    governing: ['CR-020'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'RCK-012',
    tier: RuleTier.postHoc,
    summary:
        'Front depth plus rear depth plus a 50 mm cable allowance exceeds '
        'usable depth, for overlapping RU ranges.',
    governing: ['AC-022'],
    defaultSeverity: Severity.error,
  ),
  RuleMeta(
    ruleId: 'RCK-013',
    tier: RuleTier.postHoc,
    summary:
        'Device mass exceeds maxUnsupportedMass on front ears only; '
        'requires rear support or a shelf.',
    governing: ['AC-028'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'CODE-001',
    tier: RuleTier.postHoc,
    summary:
        'Class 2/3 conductor in a Pathway with containsLineVoltage. Cites '
        'NEC 725.136 and asks the user to verify rather than asserting a '
        'violation.',
    governing: ['AC-027', 'DR-079'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'CODE-002',
    tier: RuleTier.postHoc,
    summary:
        "Pathway.kind is plenumSpace and the jacket's LISTING is not "
        'plenum-rated for its own NEC article. A listing from another '
        'article, or none, is unknown and skips (G4).',
    governing: ['AC-027', 'DR-079'],
    defaultSeverity: Severity.warning,
  ),
  RuleMeta(
    ruleId: 'LNK-020',
    tier: RuleTier.postHoc,
    summary: 'N links have unbound endpoints. A checklist, not a failure.',
    governing: ['AC-018'],
    defaultSeverity: Severity.advisory,
  ),
];

/// All 28, in tier order.
///
/// EXPLICIT, NOT REFLECTIVE (`#253`). There is no scan of the source tree
/// and no annotation: a rule that is not in one of the three lists above
/// does not exist, and its absence is visible here rather than silent at
/// run time.
const List<RuleMeta> kRuleCatalogue = <RuleMeta>[
  ...kTier1Rules,
  ...kTier2Rules,
  ...kTier3Rules,
];

/// The catalogue keyed by `ruleId`, which is how `Finding`, `RuleOverride`
/// and `AckedFinding` all join to it.
final Map<String, RuleMeta> kRulesById = <String, RuleMeta>{
  for (final rule in kRuleCatalogue) rule.ruleId: rule,
};

/// The rules of one tier, in catalogue order.
List<RuleMeta> rulesInTier(RuleTier tier) => <RuleMeta>[
  for (final rule in kRuleCatalogue)
    if (rule.tier == tier) rule,
];
